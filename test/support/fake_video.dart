/// A pretend `video_player` platform for the video engine's tests (MR14):
/// the real controller runs on it, so the engine is tested against the
/// API it uses.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// One player the platform was asked to create.
class FakePlayer(final int id, final DataSource source) {
  // Its cancelling is a future of the test's own zone: the controller
  // awaits it while disposing, and one from the root zone would never
  // complete under the test's pretend clock.
  final StreamController<VideoEvent> events = StreamController(
    onCancel: () async {},
  );
  bool playing = false;
  bool disposed = false;
  Duration position = Duration.zero;
  double speed = 1;
  double volume = 1;

  /// Every seek asked of the player, in order.
  final List<Duration> seeks = [];

  /// The video is open.
  void initialize({
    Duration duration = const Duration(minutes: 1),
    Size size = const Size(640, 360),
  }) => events.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: duration,
      size: size,
    ),
  );

  /// The player gives up: it could not open the video, or lost it.
  void fail(String message) =>
      events.addError(PlatformException(code: 'VideoError', message: message));

  void buffering(bool on) => events.add(
    VideoEvent(
      eventType: on
          ? VideoEventType.bufferingStart
          : VideoEventType.bufferingEnd,
    ),
  );

  void buffered(Duration to) => events.add(
    VideoEvent(
      eventType: VideoEventType.bufferingUpdate,
      buffered: [DurationRange(Duration.zero, to)],
    ),
  );

  /// The video played to its end.
  void complete() =>
      events.add(VideoEvent(eventType: VideoEventType.completed));
}

class FakeVideoPlatform() extends VideoPlayerPlatform {
  /// Every player created, in order.
  final List<FakePlayer> players = [];

  /// Whether a created player opens its video by itself. When false the
  /// test does, with [FakePlayer.initialize].
  bool initializes = true;

  /// When set, a created player fails to open its video, with this.
  String? openError;

  FakePlayer get last => players.last;

  /// The players not disposed of.
  List<FakePlayer> get alive => [
    for (final player in players)
      if (!player.disposed) player,
  ];

  FakePlayer _player(int id) => players[id - 1];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final player = FakePlayer(players.length + 1, options.dataSource);
    players.add(player);
    if (openError case final message?) {
      player.fail(message);
    } else if (initializes) {
      player.initialize();
    }
    return player.id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _player(playerId).events.stream;

  @override
  Future<void> dispose(int playerId) async {
    _player(playerId)
      ..disposed = true
      ..playing = false;
  }

  @override
  Future<void> play(int playerId) async => _player(playerId).playing = true;

  @override
  Future<void> pause(int playerId) async => _player(playerId).playing = false;

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _player(playerId)
      ..position = position
      ..seeks.add(position);
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      _player(playerId).position;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      _player(playerId).speed = speed;

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      _player(playerId).volume = volume;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool preventsDisplaySleepDuringVideoPlayback,
  ) async {}

  @override
  Widget buildView(int playerId) =>
      SizedBox.expand(key: ValueKey('video-$playerId'));

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      buildView(options.playerId);
}

/// Something playing, for the transport's tests: it does what it is
/// told, and remembers it.
class FakePlayback([
  MediaReaderPlaybackState initial = const MediaReaderPlaybackState(),
]) implements MediaReaderPlayback {
  final ValueNotifier<MediaReaderPlaybackState> _state = ValueNotifier(initial);

  /// Every seek asked for, in order.
  final List<Duration> seeks = [];

  @override
  ValueNotifier<MediaReaderPlaybackState> get state => _state;

  void _set({Duration? position, bool? playing, double? speed, bool? muted}) =>
      _state.value = MediaReaderPlaybackState(
        position: position ?? _state.value.position,
        duration: _state.value.duration,
        buffered: _state.value.buffered,
        playing: playing ?? _state.value.playing,
        buffering: _state.value.buffering,
        ended: _state.value.ended,
        speed: speed ?? _state.value.speed,
        muted: muted ?? _state.value.muted,
      );

  @override
  Future<void> play() async => _set(playing: true);

  @override
  Future<void> pause() async => _set(playing: false);

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    _set(position: position);
  }

  @override
  Future<void> setSpeed(double speed) async => _set(speed: speed);

  @override
  Future<void> setMuted(bool muted) async => _set(muted: muted);
}
