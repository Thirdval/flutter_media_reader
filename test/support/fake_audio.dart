/// Pretend audio players for the audio engine's tests (MR14): they do
/// what they are told and remember it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

class FakeAudioPlayer(final int id, final Object? _openError)
    implements MediaReaderAudioPlayer {
  final ValueNotifier<MediaReaderPlaybackState> _state = ValueNotifier(
    const MediaReaderPlaybackState(),
  );

  /// Where the file was opened from: one of the two is set.
  MediaReaderLocation? location;
  String? path;

  /// Where the file was opened at.
  Duration openedAt = Duration.zero;

  /// Every seek asked of the player, in order.
  final List<Duration> seeks = [];
  bool disposed = false;

  @override
  void Function(Object error)? onError;

  @override
  ValueListenable<MediaReaderPlaybackState> get state => _state;

  bool get playing => _state.value.playing;

  @override
  Future<void> open({
    MediaReaderLocation? location,
    String? path,
    Duration at = Duration.zero,
  }) async {
    if (_openError case final error?) throw error;
    this.location = location;
    this.path = path;
    openedAt = at;
    _set(position: at);
  }

  @override
  Future<void> play() async => _set(playing: true, ended: false);

  @override
  Future<void> pause() async => _set(playing: false);

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _set(position: position, ended: false);
  }

  @override
  Future<void> setSpeed(double speed) async => _set(speed: speed);

  @override
  Future<void> setMuted(bool muted) async => _set(muted: muted);

  @override
  Future<void> dispose() async => disposed = true;

  /// The file has played on to [position].
  void playedTo(Duration position) => _set(position: position);

  /// The file played to its end.
  void end() => _set(playing: false, ended: true);

  /// The player gives up on the file under way.
  void giveUp(Object error) => onError?.call(error);

  void _set({
    Duration? position,
    bool? playing,
    bool? ended,
    double? speed,
    bool? muted,
  }) {
    final now = _state.value;
    _state.value = MediaReaderPlaybackState(
      position: position ?? now.position,
      duration: const Duration(minutes: 1),
      playing: playing ?? now.playing,
      ended: ended ?? now.ended,
      speed: speed ?? now.speed,
      muted: muted ?? now.muted,
    );
  }
}

/// Makes the players a coordinator asks for, and keeps them.
class FakeAudioPlayers() {
  /// Every player made, in order.
  final List<FakeAudioPlayer> made = [];

  /// When set, the players made from now on fail to open their file
  /// with this.
  Object? openError;

  FakeAudioPlayer get last => made.last;

  /// The players not disposed of: never more than one.
  List<FakeAudioPlayer> get alive => [
    for (final player in made)
      if (!player.disposed) player,
  ];

  MediaReaderAudioPlayer create() {
    final player = FakeAudioPlayer(made.length + 1, openError);
    made.add(player);
    return player;
  }

  /// A coordinator that plays through these, on [now]'s clock.
  MediaReaderAudioCoordinator coordinator({
    DateTime Function() now = DateTime.now,
  }) => MediaReaderAudioCoordinator(createPlayer: create, now: now);
}
