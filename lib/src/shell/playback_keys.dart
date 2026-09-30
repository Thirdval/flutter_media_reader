/// The keys for what plays (MEDIA_READER_PLAN.md R8): the space bar
/// plays and pauses, M mutes, and Shift with an arrow seeks.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'media_reader_playback.dart';

/// How far Shift with an arrow seeks.
const Duration playbackKeyStep = Duration(seconds: 10);

/// Drives [playback] for [event], and says whether it did. A key typed
/// into a field is the field's, and the space bar on a button the
/// button's.
KeyEventResult playbackKeys(MediaReaderPlayback? playback, KeyEvent event) {
  if (playback == null || event is KeyUpEvent) return KeyEventResult.ignored;
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused?.findAncestorWidgetOfExactType<EditableText>() != null ||
      focused?.findAncestorWidgetOfExactType<FocusableActionDetector>() !=
          null) {
    return KeyEventResult.ignored;
  }
  final shift = HardwareKeyboard.instance.isShiftPressed;
  final state = playback.state.value;
  final Future<void>? done = switch (event.logicalKey) {
    LogicalKeyboardKey.space when !shift =>
      state.playing ? playback.pause() : playback.play(),
    LogicalKeyboardKey.keyM => playback.setMuted(!state.muted),
    LogicalKeyboardKey.arrowRight when shift => playback.seekTo(
      _within(state.position + playbackKeyStep, state.duration),
    ),
    LogicalKeyboardKey.arrowLeft when shift => playback.seekTo(
      _within(state.position - playbackKeyStep, state.duration),
    ),
    _ => null,
  };
  if (done == null) return KeyEventResult.ignored;
  unawaited(done);
  return KeyEventResult.handled;
}

Duration _within(Duration at, Duration? length) {
  if (at < Duration.zero) return Duration.zero;
  return length != null && at > length ? length : at;
}
