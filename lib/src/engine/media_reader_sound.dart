/// One sound at a time for the app (MEDIA_READER_PLAN.md R4): a video
/// that starts to play stops the voice note that was playing, and a
/// voice note stops the video.
library;

import 'package:flutter/foundation.dart';

/// Who has the sound. What starts to play takes it, and what had it is
/// told to stop.
abstract final class MediaReaderSound() {
  static Object? _holder;
  static VoidCallback? _quiet;

  /// [holder] starts to play: what held the sound before it is told to
  /// be quiet. [quiet] is what stops [holder] in its turn.
  static void take(Object holder, {required VoidCallback quiet}) {
    if (identical(_holder, holder)) return;
    final last = _quiet;
    _holder = holder;
    _quiet = quiet;
    last?.call();
  }

  /// [holder] is gone: it is not told to be quiet any more.
  static void release(Object holder) {
    if (!identical(_holder, holder)) return;
    _holder = null;
    _quiet = null;
  }
}
