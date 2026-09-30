/// The inline player a chat shows for a voice note (MEDIA_READER_PLAN.md
/// R4): play and pause, the waveform to follow and scrub, the time, the
/// speed. It shares the app's one player with the reader.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../item/media_reader_item.dart';
import '../../shell/media_reader_playback.dart';
import '../../shell/media_reader_strings.dart';
import '../../shell/media_reader_glyph.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/transport_bar.dart';
import '../../shell/waveform.dart';
import 'audio_coordinator.dart';
import 'audio_engine.dart';

/// Plays [item] where it stands, in a bubble.
///
/// The bar and the reader's page for the same file, on the same
/// coordinator, are one session: a note that plays inline goes on
/// playing when it is opened in the reader, and either place's controls
/// drive it. Starting another file stops it.
///
/// It is a plain bar in [color]. A host that wants its own draws it from
/// the session ([MediaReaderAudioCoordinator.attach]) and
/// [MediaReaderWaveform].
class const MediaReaderAudioBar({
  /// The file: its id, its source (and its preview, for a format the
  /// platform does not play), its peaks and its length.
  required final MediaReaderItem item,

  /// The app's shared coordinator unless the host passes another.
  final MediaReaderAudioCoordinator? coordinator,

  /// The glyphs, the waveform and the text.
  required final Color color,
  final MediaReaderStrings strings = const MediaReaderStrings(),

  /// The host's icons for the play and pause glyphs, as
  /// [MediaReaderChrome.glyph]; null keeps the bar's own drawing.
  final MediaReaderGlyphBuilder? glyph,

  /// Whether the file stops when the bar is removed. Left false, a note
  /// that is playing plays on to its end when its bubble scrolls out of
  /// sight; the host stops it with [MediaReaderAudioCoordinator.stop]
  /// when the conversation is left.
  final bool stopsWhenRemoved = false,

  /// Called when the file cannot be played, with what the host's resolve
  /// or the player threw: a `MediaReaderUnavailable` carries the host's
  /// own words. The bar goes back to its play button, and the host says
  /// why.
  final ValueChanged<Object>? onFailure,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderAudioBar> createState() => _MediaReaderAudioBarState();
}

class _MediaReaderAudioBarState() extends State<MediaReaderAudioBar> {
  MediaReaderAudioSession? _session;

  MediaReaderAudioCoordinator get _coordinator =>
      widget.coordinator ?? MediaReaderAudioCoordinator.shared;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(MediaReaderAudioBar old) {
    super.didUpdateWidget(old);
    _detach(old);
    _attach();
  }

  @override
  void dispose() {
    _detach(widget);
    super.dispose();
  }

  /// Holds the session of what this platform plays of the file: the file
  /// itself, or its preview. Attaching again for the same file gives the
  /// same session, with the host's resolve as it is now.
  void _attach() {
    final played = MediaReaderAudioEngine.playable(
      widget.item,
      defaultTargetPlatform,
    );
    if (played == null) return;
    _session = _coordinator.attach(
      widget.item.id,
      source: played.source,
      duration: widget.item.duration,
    )..failure.addListener(_onFailure);
  }

  void _detach(MediaReaderAudioBar bar) {
    final session = _session;
    if (session == null) return;
    _session = null;
    session.failure.removeListener(_onFailure);
    (bar.coordinator ?? MediaReaderAudioCoordinator.shared).detach(
      session,
      stop: bar.stopsWhenRemoved,
    );
  }

  void _onFailure() {
    final error = _session?.failure.value;
    if (error != null) widget.onFailure?.call(error);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    // A format this platform does not play, with no preview it does.
    if (session == null) {
      return Opacity(
        opacity: 0.4,
        child: _bar(
          state: MediaReaderPlaybackState(duration: widget.item.duration),
          session: null,
        ),
      );
    }
    return ValueListenableBuilder(
      valueListenable: session.state,
      builder: (context, state, _) => _bar(state: state, session: session),
    );
  }

  Widget _bar({
    required MediaReaderPlaybackState state,
    required MediaReaderAudioSession? session,
  }) {
    final colour = widget.color;
    final strings = widget.strings;
    final started = state.playing || state.position > Duration.zero;
    // Asked to play, and on its way: a tap stops it, as when it plays.
    final opening = state.buffering && !state.playing;
    final active = state.playing || opening;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colour),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MediaReaderGlyphButton(
              glyph: active ? MediaReaderGlyph.pause : MediaReaderGlyph.play,
              label: active ? strings.pause : strings.play,
              colour: opening ? colour.withValues(alpha: 0.5) : colour,
              draw: widget.glyph,
              onPressed: session == null
                  ? null
                  : () => unawaited(active ? session.pause() : session.play()),
            ),
            Expanded(
              child: MediaReaderWaveform(
                position: state.position,
                duration: state.duration,
                peaks: widget.item.peaks,
                onSeek: (position) => unawaited(session?.seekTo(position)),
                color: colour,
                semanticLabel: strings.seek,
                height: 32,
              ),
            ),
            const SizedBox(width: 8),
            // The time played once it has started, the length before.
            Text(
              formatPlaybackTime(
                started ? state.position : state.duration ?? Duration.zero,
              ),
              style: const TextStyle(
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (started && session != null)
              MediaReaderTextButton(
                text: strings.speed(state.speed),
                onPressed: () {
                  const speeds = MediaReaderTransportBar.speeds;
                  final next = speeds.indexOf(state.speed) + 1;
                  unawaited(session.setSpeed(speeds[next % speeds.length]));
                },
              ),
          ],
        ),
      ),
    );
  }
}
