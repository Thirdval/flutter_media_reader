/// The audio player behind one interface (MEDIA_READER_PLAN.md R4,
/// MR4): `just_audio` on iOS, Android and macOS, where it handles the
/// audio session's interruptions; `video_player` on Windows and Linux,
/// where `fvp` implements it and plays audio without video.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just;
import 'package:video_player/video_player.dart';

import '../../item/media_reader_source.dart';
import '../../shell/media_reader_playback.dart';

/// One audio player. The coordinator keeps a single one for the app.
abstract interface class MediaReaderAudioPlayer() {
  /// Where the file stands. The player keeps it current.
  ValueListenable<MediaReaderPlaybackState> get state;

  /// Called when the player gives up on the file under way.
  set onError(void Function(Object error)? handler);

  /// Opens the file at [location], or the file at [path], at [at].
  /// Throws when it cannot.
  Future<void> open({MediaReaderLocation? location, String? path, Duration at});

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> setMuted(bool muted);

  Future<void> dispose();
}

/// Makes a player. Tests pass a fake; a host may pass its own.
typedef MediaReaderAudioPlayerFactory = MediaReaderAudioPlayer Function();

/// The player for this platform (MR4).
MediaReaderAudioPlayer createMediaReaderAudioPlayer() =>
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux => MediaReaderVideoAudioPlayer(),
      _ => MediaReaderJustAudioPlayer(),
    };

/// `just_audio`'s player. It pauses for an interruption (a call, another
/// app's sound) and ducks where the platform says to. The audio session's
/// category is the host's to set: the package configures nothing.
final class MediaReaderJustAudioPlayer() implements MediaReaderAudioPlayer {
  // Headers are handed to the platform's player. Left to its default,
  // just_audio would pass them through a plain-HTTP proxy on localhost,
  // which the host would have to allow.
  final just.AudioPlayer _player = just.AudioPlayer(
    useProxyForRequestHeaders: false,
  );
  final ValueNotifier<MediaReaderPlaybackState> _state = ValueNotifier(
    const MediaReaderPlaybackState(),
  );
  final List<StreamSubscription<Object?>> _listening = [];
  bool _disposed = false;

  @override
  void Function(Object error)? onError;

  @override
  ValueListenable<MediaReaderPlaybackState> get state => _state;

  void _update() {
    if (_disposed) return;
    final processing = _player.processingState;
    final ended = processing == just.ProcessingState.completed;
    _state.value = MediaReaderPlaybackState(
      position: _player.position,
      duration: _player.duration,
      buffered: _player.bufferedPosition,
      playing: _player.playing && !ended,
      buffering:
          processing == just.ProcessingState.loading ||
          processing == just.ProcessingState.buffering,
      ended: ended,
      speed: _player.speed,
      muted: _player.volume == 0,
    );
    // just_audio goes on "playing" at the end of a file, and a seek would
    // set it off again. It is paused there, as the other players are.
    if (ended && _player.playing) unawaited(_player.pause());
  }

  @override
  Future<void> open({
    MediaReaderLocation? location,
    String? path,
    Duration at = Duration.zero,
  }) async {
    if (_listening.isEmpty) {
      _listening.addAll([
        _player.playerStateStream.listen((_) => _update()),
        _player.positionStream.listen((_) => _update()),
        _player.bufferedPositionStream.listen((_) => _update()),
        _player.durationStream.listen((_) => _update()),
        _player.errorStream.listen((error) => onError?.call(error)),
      ]);
    }
    await _player.setAudioSource(switch (location) {
      null => just.AudioSource.file(path!),
      MediaReaderLocation(:final uri, :final headers) => just.AudioSource.uri(
        uri,
        headers: headers.isEmpty ? null : headers,
      ),
    }, initialPosition: at);
    _update();
  }

  // just_audio's play completes when the playing stops, not when it
  // starts: it is not waited for.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 1);

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _listening) {
      unawaited(subscription.cancel());
    }
    await _player.dispose();
    _state.dispose();
  }
}

/// `video_player`'s controller, playing a file that has no picture: the
/// audio player of Windows and Linux, where `fvp` is its implementation.
final class MediaReaderVideoAudioPlayer() implements MediaReaderAudioPlayer {
  final ValueNotifier<MediaReaderPlaybackState> _state = ValueNotifier(
    const MediaReaderPlaybackState(),
  );
  VideoPlayerController? _controller;
  bool _disposed = false;

  @override
  void Function(Object error)? onError;

  @override
  ValueListenable<MediaReaderPlaybackState> get state => _state;

  void _update() {
    final value = _controller?.value;
    if (value == null || _disposed) return;
    if (value.hasError) return onError?.call(value.errorDescription ?? '');
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

  @override
  Future<void> open({
    MediaReaderLocation? location,
    String? path,
    Duration at = Duration.zero,
  }) async {
    final opened = switch (location) {
      null => VideoPlayerController.file(File(path!)),
      MediaReaderLocation(:final uri, :final headers) =>
        VideoPlayerController.networkUrl(uri, httpHeaders: headers),
    };
    try {
      await opened.initialize();
      if (at > Duration.zero) await opened.seekTo(at);
    } on Object {
      unawaited(opened.dispose());
      rethrow;
    }
    final last = _controller;
    last?.removeListener(_update);
    unawaited(last?.dispose());
    _controller = opened..addListener(_update);
    _update();
  }

  @override
  Future<void> play() async => await _controller?.play();

  @override
  Future<void> pause() async => await _controller?.pause();

  @override
  Future<void> seek(Duration position) async =>
      await _controller?.seekTo(position);

  @override
  Future<void> setSpeed(double speed) async =>
      await _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> setMuted(bool muted) async =>
      await _controller?.setVolume(muted ? 0 : 1);

  @override
  Future<void> dispose() async {
    _disposed = true;
    _controller?.removeListener(_update);
    await _controller?.dispose();
    _state.dispose();
  }
}
