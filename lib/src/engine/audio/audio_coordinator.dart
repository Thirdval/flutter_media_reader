/// One audio player at a time for the whole app (MEDIA_READER_PLAN.md
/// R4): a voice note in a chat and the same file in the reader are one
/// session, and starting another file stops the one that plays. A video
/// that starts in the reader stops it too.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../item/media_reader_resolver.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_playback.dart';
import '../media_reader_sound.dart';
import 'audio_player.dart';

/// Gives the app's one audio player to one file at a time.
final class MediaReaderAudioCoordinator({
  final MediaReaderAudioPlayerFactory _createPlayer =
      createMediaReaderAudioPlayer,
  final DateTime Function() _now = DateTime.now,
}) {
  /// The coordinator the reader and the inline bar use unless the host
  /// passes its own.
  static final MediaReaderAudioCoordinator shared =
      MediaReaderAudioCoordinator();

  final Map<String, MediaReaderAudioSession> _sessions = {};
  final ValueNotifier<MediaReaderAudioSession?> _active = ValueNotifier(null);

  /// The session that has the player: the file that plays, or is paused
  /// where it was. Null when none has.
  ValueListenable<MediaReaderAudioSession?> get active => _active;

  /// The session of the file [id], made when there is none, with one
  /// more holder. A bar and a reader page that attach the same id hold
  /// the same session.
  ///
  /// [source] is a remote file or a file on the device; audio in memory
  /// has no player. The session keeps the remote file's location itself,
  /// so the bar and the page ask the host once between them.
  MediaReaderAudioSession attach(
    String id, {
    required MediaReaderSource source,

    /// The length the host knows, shown until the player reports its own.
    Duration? duration,
  }) {
    if (source is MediaReaderBytesSource) {
      throw ArgumentError.value(source, 'source', 'Audio in memory');
    }
    final session = _sessions.putIfAbsent(
      id,
      () => MediaReaderAudioSession._(this, id, source, duration),
    );
    // The same file, described again: the host's resolve may be another
    // closure; the kept location stays.
    if (source case final MediaReaderRemoteSource remote) {
      session._resolver?.source = remote;
    }
    session._holders += 1;
    return session;
  }

  /// One holder less. When the last lets go, the file stops, unless
  /// [stop] is false and it is playing: then it plays on to its end, as
  /// a voice note does when its bubble scrolls out of sight.
  ///
  /// Whoever lets go is usually being disposed of, with the widget tree
  /// locked, and stopping the file changes what others show. So the file
  /// is stopped a moment later; a holder that attaches again at once (a
  /// rebuild) keeps it playing.
  void detach(MediaReaderAudioSession session, {bool stop = true}) {
    session._holders -= 1;
    scheduleMicrotask(() {
      if (session._holders > 0) return;
      if (!stop && session._wantsPlaying) return;
      _forget(session);
    });
  }

  /// Stops whatever plays: for a host leaving the place its audio
  /// belongs to.
  Future<void> stop() async {
    final playing = _active.value;
    _active.value = null;
    // A note that played on with nobody showing it is forgotten.
    if (playing != null && playing._holders <= 0) _sessions.remove(playing.id);
    await playing?._release();
  }

  /// One sound at a time: a video that was playing stops, and this
  /// coordinator's file stops when a video starts.
  void _takeSound() => MediaReaderSound.take(
    this,
    quiet: () => unawaited(_active.value?.pause()),
  );

  /// Makes [session] the one with the player, taking it from another.
  Future<void> _give(MediaReaderAudioSession session) async {
    final last = _active.value;
    if (identical(last, session)) return;
    _active.value = session;
    await last?._release();
    if (last != null && last._holders <= 0) _sessions.remove(last.id);
  }

  void _forget(MediaReaderAudioSession session) {
    if (identical(_sessions[session.id], session)) _sessions.remove(session.id);
    if (identical(_active.value, session)) _active.value = null;
    unawaited(session._release());
  }
}

/// One audio file's playing, shared by whoever shows it.
///
/// A signed URL runs out while a file is paused: before it is used again
/// (a play, a seek) the location is checked, and a fresh one takes its
/// place at the same position. When the player gives up under way, a
/// fresh location is asked for once.
final class MediaReaderAudioSession._(
  final MediaReaderAudioCoordinator _coordinator,

  /// The file's id.
  final String id,
  MediaReaderSource source,
  final Duration? _hostDuration,
) implements MediaReaderPlayback {
  /// A failure this close to the last one is the file's own, not a
  /// location that ran out: it is not recovered from again.
  static const _sameFailure = Duration(seconds: 2);

  /// The file on the device, for a file source.
  final String? _path = switch (source) {
    MediaReaderFileSource(:final path) => path,
    _ => null,
  };

  /// The keeper of a remote file's location.
  final MediaReaderResolver? _resolver = switch (source) {
    final MediaReaderRemoteSource remote => MediaReaderResolver(
      remote,
      now: _coordinator._now,
    ),
    _ => null,
  };
  late final ValueNotifier<MediaReaderPlaybackState> _state = ValueNotifier(
    MediaReaderPlaybackState(duration: _hostDuration),
  );

  /// Why the file does not play, when it does not: what the player or the
  /// host threw. Null while all is well; a new play clears it.
  final ValueNotifier<Object?> failure = ValueNotifier(null);

  MediaReaderAudioPlayer? _player;
  MediaReaderLocation? _location;
  Future<void>? _opening;
  int _holders = 0;
  bool _wantsPlaying = false;
  bool _recovering = false;
  Duration? _recoveredAt;

  @override
  ValueListenable<MediaReaderPlaybackState> get state => _state;

  @override
  Future<void> play() async {
    failure.value = null;
    _wantsPlaying = true;
    _coordinator._takeSound();
    try {
      await _coordinator._give(this);
      if (!_wantsPlaying) return;
      final now = _state.value;
      if (_player == null) {
        // A second play while the file opens waits for the same player.
        await (_opening ??= _open(at: now.ended ? Duration.zero : now.position)
            .whenComplete(() => _opening = null));
      } else {
        await _refresh();
        if (now.ended) await _player?.seek(Duration.zero);
      }
      if (_wantsPlaying) await _player?.play();
    } on Object catch (error) {
      _fail(error);
    }
  }

  @override
  Future<void> pause() async {
    _wantsPlaying = false;
    await _player?.pause();
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_player == null) return _set(position: position, ended: false);
    try {
      await _refresh(at: position);
      await _player?.seek(position);
    } on Object catch (error) {
      _fail(error);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    _set(speed: speed);
    await _player?.setSpeed(speed);
  }

  @override
  Future<void> setMuted(bool muted) async {
    _set(muted: muted);
    await _player?.setMuted(muted);
  }

  /// Opens a player at [location] (resolved when not given) in the last
  /// one's place, at [at] and as it was.
  Future<void> _open({
    required Duration at,
    MediaReaderLocation? location,
  }) async {
    _set(buffering: true);
    final player = _coordinator._createPlayer();
    try {
      if (_path case final path?) {
        await player.open(path: path, at: at);
      } else {
        location ??= await _resolver!.resolve();
        await player.open(location: location, at: at);
      }
      await player.setSpeed(_state.value.speed);
      await player.setMuted(_state.value.muted);
    } on Object {
      unawaited(player.dispose());
      _set(buffering: false);
      rethrow;
    }
    // Another file took the player while this one was opening.
    if (!identical(_coordinator._active.value, this)) {
      _set(buffering: false);
      return unawaited(player.dispose());
    }
    _drop();
    _player = player
      ..state.addListener(_onPlayer)
      ..onError = _onError;
    _location = location;
    _onPlayer();
  }

  /// A location that has run out is not used again: the player gives way
  /// to one at a fresh location, at the same place.
  Future<void> _refresh({Duration? at}) async {
    final resolver = _resolver;
    final location = _location;
    if (resolver == null || location == null) return;
    final fresh = await resolver.resolve();
    if (fresh.uri == location.uri) return;
    await _open(at: at ?? _state.value.position, location: fresh);
  }

  void _onPlayer() {
    final player = _player;
    if (player == null) return;
    final now = player.state.value;
    _state.value = MediaReaderPlaybackState(
      position: now.position,
      duration: now.duration ?? _hostDuration,
      buffered: now.buffered,
      playing: now.playing,
      buffering: now.buffering,
      ended: now.ended,
      speed: now.speed,
      muted: now.muted,
    );
    if (!now.ended) return;
    _wantsPlaying = false;
    // Nobody shows the file any more, and it has played to its end.
    if (_holders <= 0) _coordinator._forget(this);
  }

  void _onError(Object error) => unawaited(_recover(error));

  /// The player gave up under way. With a remote file the likeliest
  /// cause is a location that ran out: a fresh one is asked for and the
  /// file goes on from where it was. A failure again at the same place
  /// is the file's own.
  Future<void> _recover(Object error) async {
    if (_recovering) return;
    _recovering = true;
    final at = _state.value.position;
    try {
      final resolver = _resolver;
      final location = _location;
      final last = _recoveredAt;
      final again = last != null && (at - last).abs() < _sameFailure;
      if (resolver == null || location == null || again) return _fail(error);
      _recoveredAt = at;
      await _open(at: at, location: await resolver.renew(location));
      if (_wantsPlaying) await _player?.play();
    } on Object catch (error) {
      _fail(error);
    } finally {
      _recovering = false;
    }
  }

  void _fail(Object error) {
    _wantsPlaying = false;
    _drop();
    _set(playing: false, buffering: false);
    failure.value = error;
  }

  /// Another file takes the player, or nobody holds this one: it stops
  /// where it is, and keeps its place for a later play.
  Future<void> _release() async {
    _wantsPlaying = false;
    _drop();
    _set(playing: false, buffering: false);
  }

  void _drop() {
    final player = _player;
    if (player == null) return;
    _player = null;
    player
      ..state.removeListener(_onPlayer)
      ..onError = null;
    unawaited(player.dispose());
  }

  void _set({
    Duration? position,
    bool? playing,
    bool? buffering,
    bool? ended,
    double? speed,
    bool? muted,
  }) {
    final now = _state.value;
    _state.value = MediaReaderPlaybackState(
      position: position ?? now.position,
      duration: now.duration,
      buffered: now.buffered,
      playing: playing ?? now.playing,
      buffering: buffering ?? now.buffering,
      ended: ended ?? now.ended,
      speed: speed ?? now.speed,
      muted: muted ?? now.muted,
    );
  }
}
