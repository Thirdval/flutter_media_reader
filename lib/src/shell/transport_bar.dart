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

  @override
  Widget build(BuildContext context) {
    final strings = chrome.strings;
    final colour = chrome.foreground;
    const time = TextStyle(
      fontSize: 12,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder(
        valueListenable: playback.state,
        builder: (context, state, _) => DecoratedBox(
          decoration: ShapeDecoration(
            color: chrome.background.withValues(alpha: 0.6),
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                MediaReaderGlyphButton(
                  glyph: state.playing
                      ? MediaReaderGlyph.pause
                      : MediaReaderGlyph.play,
                  label: state.playing ? strings.pause : strings.play,
                  colour: colour,
                  onPressed: () => _toggle(state),
                ),
                Text(formatPlaybackTime(state.position), style: time),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: MediaReaderWaveform(
                      position: state.position,
                      duration: state.duration,
                      buffered: state.buffered,
                      peaks: peaks,
                      onSeek: (position) =>
                          unawaited(playback.seekTo(position)),
                      color: colour,
                      semanticLabel: strings.seek,
                    ),
                  ),
                ),
                if (state.remaining case final remaining?)
                  Text('-${formatPlaybackTime(remaining)}', style: time),
                MediaReaderTextButton(
                  text: strings.speed(state.speed),
                  onPressed: () => _nextSpeed(state),
                ),
                MediaReaderGlyphButton(
                  glyph: state.muted
                      ? MediaReaderGlyph.muted
                      : MediaReaderGlyph.sound,
                  label: state.muted ? strings.unmute : strings.mute,
                  colour: colour,
                  onPressed: () => unawaited(playback.setMuted(!state.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
