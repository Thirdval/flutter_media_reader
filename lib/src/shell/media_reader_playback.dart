/// What plays on a page (video in R3, audio in R4), as the chrome's
/// transport controls see it: its state, and the commands a control
/// gives.
library;

import 'package:flutter/foundation.dart';

/// Where a playing file stands.
class const MediaReaderPlaybackState({
  final Duration position = Duration.zero,

  /// The file's length, once it is known.
  final Duration? duration,

  /// How far into the file has been buffered.
  final Duration buffered = Duration.zero,
  final bool playing = false,

  /// Waiting for data before it can go on.
  final bool buffering = false,

  /// Played to its end.
  final bool ended = false,
  final double speed = 1,
  final bool muted = false,
}) {
  /// How far through the file the position is, 0..1; 0 while the length
  /// is not known.
  double get progress => _fraction(position);

  /// How far through the file the buffer reaches, 0..1.
  double get bufferedProgress => _fraction(buffered);

  /// The time left; null while the length is not known.
  Duration? get remaining => switch (duration) {
    null => null,
    final duration => duration > position ? duration - position : Duration.zero,
  };

  double _fraction(Duration at) => switch (duration) {
    null || Duration.zero => 0,
    final duration => (at.inMicroseconds / duration.inMicroseconds).clamp(0, 1),
  };
}

/// What plays on a page. An engine that plays something sets it as the
/// page's `playback`; the chrome's controls drive it.
abstract interface class MediaReaderPlayback() {
  ValueListenable<MediaReaderPlaybackState> get state;

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> setMuted(bool muted);
}
