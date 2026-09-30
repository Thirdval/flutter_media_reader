/// The plain default transport for what plays (MR10): play and pause, a
/// scrubber, the time played and left, speed and mute. A host replaces
/// it through the chrome's `controls` slot.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';
import 'media_reader_playback.dart';
import 'plain_widgets.dart';
import 'waveform.dart';

/// A time as a player shows it: "0:07", "12:34", "1:02:03".
String formatPlaybackTime(Duration time) {
  final hours = time.inHours;
  final minutes = time.inMinutes.remainder(60);
  final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

/// The default transport bar. Like every player's, it runs left to right
/// in every language.
class const MediaReaderTransportBar({
  required final MediaReaderPlayback playback,
  required final MediaReaderChrome chrome,

  /// The sound's peaks, where the host has them: the scrubber is then a
  /// waveform.
  final List<double>? peaks,
  super.key,
}) extends StatelessWidget {
  /// The speeds the speed button goes round.
  static const List<double> speeds = [1, 1.5, 2];

  void _toggle(MediaReaderPlaybackState state) =>
      unawaited(state.playing ? playback.pause() : playback.play());

  void _nextSpeed(MediaReaderPlaybackState state) {
    final at = speeds.indexOf(state.speed);
    unawaited(playback.setSpeed(speeds[(at + 1) % speeds.length]));
  }

  /// The bar's text grows to this much of the person's size: it is a
  /// compact strip, as a toolbar is (R8).
  static const double maxTextScale = 1.5;

  /// Below this width, at the text's size, the scrubber has a row of its
  /// own above the buttons.
  static const double _oneRowFrom = 340;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: ValueListenableBuilder(
        valueListenable: playback.state,
        builder: (context, state, _) => DecoratedBox(
          decoration: ShapeDecoration(
            color: chrome.background.withValues(alpha: 0.6),
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                return constraints.maxWidth < _oneRowFrom * scale
                    ? _twoRows(state)
                    : _oneRow(state);
              },
            ),
          ),
        ),
      ),
    ),
  );

  static const TextStyle _time = TextStyle(
    fontSize: 12,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  Widget _oneRow(MediaReaderPlaybackState state) => Row(
    children: [
      _playButton(state),
      Text(formatPlaybackTime(state.position), style: _time),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: _scrubber(state),
        ),
      ),
      if (state.remaining case final remaining?)
        Text('-${formatPlaybackTime(remaining)}', style: _time),
      ..._trailing(state),
    ],
  );

  /// The times share what is left between the buttons, and shrink only
  /// where even that is too little.
  Widget _twoRows(MediaReaderPlaybackState state) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: _scrubber(state),
      ),
      Row(
        children: [
          _playButton(state),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatPlaybackTime(state.position), style: _time),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(switch (state.remaining) {
                null => '',
                final remaining => '-${formatPlaybackTime(remaining)}',
              }, style: _time),
            ),
          ),
          ..._trailing(state),
        ],
      ),
    ],
  );

  Widget _playButton(MediaReaderPlaybackState state) => MediaReaderGlyphButton(
    glyph: state.playing ? MediaReaderGlyph.pause : MediaReaderGlyph.play,
    label: state.playing ? chrome.strings.pause : chrome.strings.play,
    colour: chrome.foreground,
    onPressed: () => _toggle(state),
  );

  Widget _scrubber(MediaReaderPlaybackState state) => MediaReaderWaveform(
    position: state.position,
    duration: state.duration,
    buffered: state.buffered,
    peaks: peaks,
    onSeek: (position) => unawaited(playback.seekTo(position)),
    color: chrome.foreground,
    semanticLabel: chrome.strings.seek,
  );

  List<Widget> _trailing(MediaReaderPlaybackState state) => [
    MediaReaderTextButton(
      text: chrome.strings.speed(state.speed),
      onPressed: () => _nextSpeed(state),
    ),
    MediaReaderGlyphButton(
      glyph: state.muted ? MediaReaderGlyph.muted : MediaReaderGlyph.sound,
      label: state.muted ? chrome.strings.unmute : chrome.strings.mute,
      colour: chrome.foreground,
      onPressed: () => unawaited(playback.setMuted(!state.muted)),
    ),
  ];
}
