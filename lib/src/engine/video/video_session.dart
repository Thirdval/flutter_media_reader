/// A video's playing on its page (MEDIA_READER_PLAN.md R3): the player,
/// kept at a location that is still valid, and the state the transport
/// shows.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/media_reader_playback.dart';
import '../media_reader_sound.dart';

/// Plays [item] for [page], through the `video_player` API.
///
/// A signed URL runs out while a video is paused, or under a long one.
/// Before the location is used again (a play, a seek) it is checked, and
/// a fresh one takes the player's place at the same position. When the
/// player gives up under way, a fresh location is asked for once.
final class MediaReaderVideoSession({
  /// The video shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
}) implements MediaReaderPlayback {
  /// A failure this close to the last one is the file's own, not a
  /// location that ran out: it is not recovered from again.
  static const _sameFailure = Duration(seconds: 2);

  final ValueNotifier<MediaReaderPlaybackState> _state = ValueNotifier(
    const MediaReaderPlaybackState(),
  );

  /// The player to show; null until the video is open.
  final ValueNotifier<VideoPlayerController?> player = ValueNotifier(null);

  /// True while the video is being opened.
  final ValueNotifier<bool> opening = ValueNotifier(false);

  MediaReaderLocation? _location;
  bool _wantsPlaying = false;
  bool _resumes = false;
  bool _recovering = false;
  Duration? _recoveredAt;
  double _speed = 1;
  bool _muted = false;
  bool _disposed = false;

  @override
  ValueListenable<MediaReaderPlaybackState> get state => _state;

  /// Opens the video and plays it. A failure puts the card on the page.
  Future<void> start() async {
    _wantsPlaying = true;
    _takeSound();
    opening.value = true;
    try {
      await _open(at: Duration.zero);
    } on Object catch (error) {
      fail(error);
    } finally {
      if (!_disposed) opening.value = false;
    }
  }

  /// The page left the screen: the video stops, and remembers whether it
  /// was playing.
  void leave() {
    _resumes = _wantsPlaying;
    unawaited(pause());
  }

  /// The page is on screen again.
  void comeBack() {
    if (_resumes) unawaited(play());
  }

  @override
  Future<void> play() async {
    _wantsPlaying = true;
    _takeSound();
    if (player.value == null) return;
    try {
      await _refresh();
      final current = player.value;
      if (current == null || !_wantsPlaying) return;
      if (_state.value.ended) await current.seekTo(Duration.zero);
      await current.play();
    } on Object catch (error) {
      fail(error);
    }
  }

  @override
  Future<void> pause() async {
    _wantsPlaying = false;
    await player.value?.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (player.value == null) return;
    try {
      await _refresh(at: position);
      await player.value?.seekTo(position);
    } on Object catch (error) {
      fail(error);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await player.value?.setPlaybackSpeed(speed);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    await player.value?.setVolume(muted ? 0 : 1);
  }

  /// Puts the card on the page, with why. A reason the host gave already
  /// stands.
  void fail(Object error) {
    if (_disposed || page.failure.value != null) return;
    final strings = page.chrome.strings;
    page.fail(switch (error) {
      MediaReaderUnavailable(:final reason) => reason,
      // The player could not open the file, or gave up on it.
      PlatformException() || _Unplayable() => strings.failed,
      // The host could not be asked where the file is.
      _ => strings.unreachable,
    });
  }

  void dispose() {
    _disposed = true;
    MediaReaderSound.release(this);
    player.value?.removeListener(_onPlayer);
    unawaited(player.value?.dispose());
    player.dispose();
    opening.dispose();
    _state.dispose();
  }

  /// One sound at a time: a voice note that was playing stops, and this
  /// video stops when one starts.
  void _takeSound() =>
      MediaReaderSound.take(this, quiet: () => unawaited(pause()));

  /// Opens a player at [location] (resolved when not given) and puts it
  /// in the last one's place, at [at] and as it was: speed, sound, and
  /// playing if it should be.
  Future<void> _open({
    required Duration at,
    MediaReaderLocation? location,
  }) async {
    final VideoPlayerController opened;
    switch (item.source) {
      case MediaReaderRemoteSource():
        location ??= await page.resolve();
        opened = VideoPlayerController.networkUrl(
          location.uri,
          httpHeaders: location.headers,
        );
      case MediaReaderFileSource(:final path):
        opened = VideoPlayerController.file(File(path));
      case MediaReaderBytesSource():
        throw const _Unplayable();
    }
    try {
      await opened.initialize();
      if (at > Duration.zero) await opened.seekTo(at);
      await opened.setPlaybackSpeed(_speed);
      await opened.setVolume(_muted ? 0 : 1);
    } on Object {
      unawaited(opened.dispose());
      rethrow;
    }
    if (_disposed) return unawaited(opened.dispose());
    final last = player.value;
    last?.removeListener(_onPlayer);
    opened.addListener(_onPlayer);
    _location = location;
    player.value = opened;
    unawaited(last?.dispose());
    if (_wantsPlaying) await opened.play();
    _onPlayer();
  }

  /// A location that has run out is not used again: the player gives way
  /// to one at a fresh location, at the same place.
  Future<void> _refresh({Duration? at}) async {
    final location = _location;
    if (location == null) return;
    final fresh = await page.resolve();
    if (fresh.uri == location.uri) return;
    await _open(at: at ?? _state.value.position, location: fresh);
  }

  void _onPlayer() {
    final value = player.value?.value;
    if (value == null || _disposed) return;
    if (value.hasError) return unawaited(_recover());
    _state.value = MediaReaderPlaybackState(
      position: value.position,
      duration: value.duration > Duration.zero ? value.duration : null,
      buffered: value.buffered.fold(
        Duration.zero,
        (end, range) => range.end > end ? range.end : end,
      ),
      playing: value.isPlaying,
      buffering: value.isBuffering,
      ended: value.isCompleted,
      speed: value.playbackSpeed,
      muted: value.volume == 0,
    );
  }

  /// The player gave up under way. With a remote file the likeliest
  /// cause is a location that ran out: a fresh one is asked for and the
  /// video goes on from where it was. A failure again at the same place
  /// is the file's own, and goes to the card.
  Future<void> _recover() async {
    if (_recovering || _disposed) return;
    _recovering = true;
    final at = _state.value.position;
    try {
      final location = _location;
      final last = _recoveredAt;
      final again = last != null && (at - last).abs() < _sameFailure;
      if (location == null || again) throw const _Unplayable();
      _recoveredAt = at;
      await _open(at: at, location: await page.renew(location));
    } on Object catch (error) {
      fail(error);
    } finally {
      _recovering = false;
    }
  }
}

/// The player cannot play the file.
class const _Unplayable() implements Exception;
