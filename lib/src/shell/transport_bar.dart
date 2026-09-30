/// The plain default transport for what plays (MR10): play and pause, a
/// scrubber, the time played and left, speed and mute. A host replaces
/// it through the chrome's `controls` slot.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';
import 'media_reader_playback.dart';

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
                _GlyphButton(
                  glyph: state.playing ? _Glyph.pause : _Glyph.play,
                  label: state.playing ? strings.pause : strings.play,
                  colour: colour,
                  onPressed: () => _toggle(state),
                ),
                Text(formatPlaybackTime(state.position), style: time),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: MediaReaderScrubber(
                      state: state,
                      onSeek: (position) =>
                          unawaited(playback.seekTo(position)),
                      chrome: chrome,
                    ),
                  ),
                ),
                if (state.remaining case final remaining?)
                  Text('-${formatPlaybackTime(remaining)}', style: time),
                _TextButton(
                  text: strings.speed(state.speed),
                  onPressed: () => _nextSpeed(state),
                ),
                _GlyphButton(
                  glyph: state.muted ? _Glyph.muted : _Glyph.sound,
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

/// A track to scrub along: how far the file has played, how far it is
/// buffered, and a drag or a tap to seek.
class const MediaReaderScrubber({
  required final MediaReaderPlaybackState state,
  required final ValueChanged<Duration> onSeek,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderScrubber> createState() => _MediaReaderScrubberState();
}

class _MediaReaderScrubberState() extends State<MediaReaderScrubber> {
  /// What a screen reader's "increase" and "decrease" move by.
  static const _step = Duration(seconds: 5);

  /// Where the thumb is while it is dragged, 0..1.
  double? _dragging;

  double _fractionAt(double x) =>
      (x / math.max(1, context.size?.width ?? 1)).clamp(0, 1);

  void _seekTo(double fraction) {
    final duration = widget.state.duration;
    if (duration != null) widget.onSeek(duration * fraction);
  }

  /// The position [by] further on, kept inside the file; null while the
  /// file's length is not known.
  Duration? _nudged(Duration by) {
    final duration = widget.state.duration;
    if (duration == null) return null;
    final to = widget.state.position + by;
    if (to < Duration.zero) return Duration.zero;
    return to > duration ? duration : to;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final forward = _nudged(_step);
    final back = _nudged(-_step);
    return Semantics(
      slider: true,
      label: widget.chrome.strings.seek,
      value: formatPlaybackTime(state.position),
      increasedValue: forward == null ? null : formatPlaybackTime(forward),
      decreasedValue: back == null ? null : formatPlaybackTime(back),
      onIncrease: forward == null ? null : () => widget.onSeek(forward),
      onDecrease: back == null ? null : () => widget.onSeek(back),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _seekTo(_fractionAt(details.localPosition.dx)),
        onHorizontalDragStart: (details) =>
            setState(() => _dragging = _fractionAt(details.localPosition.dx)),
        onHorizontalDragUpdate: (details) =>
            setState(() => _dragging = _fractionAt(details.localPosition.dx)),
        onHorizontalDragEnd: (_) {
          final to = _dragging;
          setState(() => _dragging = null);
          if (to != null) _seekTo(to);
        },
        onHorizontalDragCancel: () => setState(() => _dragging = null),
        child: SizedBox(
          height: 40,
          child: CustomPaint(
            painter: _Track(
              played: _dragging ?? state.progress,
              buffered: state.bufferedProgress,
              colour: widget.chrome.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class const _Track({
  required final double played,
  required final double buffered,
  required final Color colour,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    void line(double to, double alpha) => canvas.drawLine(
      Offset(2, y),
      Offset(2 + (size.width - 4) * to, y),
      paint..color = colour.withValues(alpha: alpha),
    );
    line(1, 0.25);
    if (buffered > 0) line(buffered, 0.45);
    if (played > 0) line(played, 1);
    canvas.drawCircle(
      Offset(2 + (size.width - 4) * played, y),
      6,
      Paint()..color = colour,
    );
  }

  @override
  bool shouldRepaint(_Track old) =>
      old.played != played || old.buffered != buffered || old.colour != colour;
}

enum _Glyph() {
  play,
  pause,
  sound,
  muted,
}

/// A round button with a drawn glyph: no icon font is assumed.
class const _GlyphButton({
  required final _Glyph glyph,
  required final String label,
  required final Color colour,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 40,
          child: CustomPaint(painter: _GlyphPainter(glyph, colour)),
        ),
      ),
    ),
  );
}

class const _TextButton({
  required final String text,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class const _GlyphPainter(final _Glyph glyph, final Color colour)
    extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = colour;
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    switch (glyph) {
      case _Glyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 5, c.dy - 8)
            ..lineTo(c.dx + 8, c.dy)
            ..lineTo(c.dx - 5, c.dy + 8)
            ..close(),
          fill,
        );
      case _Glyph.pause:
        canvas
          ..drawRect(Rect.fromLTWH(c.dx - 6, c.dy - 7, 4, 14), fill)
          ..drawRect(Rect.fromLTWH(c.dx + 2, c.dy - 7, 4, 14), fill);
      case _Glyph.sound || _Glyph.muted:
        // A speaker: a box and a cone.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 9, c.dy - 3)
            ..lineTo(c.dx - 5, c.dy - 3)
            ..lineTo(c.dx, c.dy - 7)
            ..lineTo(c.dx, c.dy + 7)
            ..lineTo(c.dx - 5, c.dy + 3)
            ..lineTo(c.dx - 9, c.dy + 3)
            ..close(),
          fill,
        );
        if (glyph == _Glyph.sound) {
          canvas
            ..drawArc(
              Rect.fromCircle(center: c, radius: 5),
              -0.8,
              1.6,
              false,
              stroke,
            )
            ..drawArc(
              Rect.fromCircle(center: c, radius: 9),
              -0.8,
              1.6,
              false,
              stroke,
            );
        } else {
          canvas
            ..drawLine(
              Offset(c.dx + 4, c.dy - 4),
              Offset(c.dx + 10, c.dy + 4),
              stroke,
            )
            ..drawLine(
              Offset(c.dx + 10, c.dy - 4),
              Offset(c.dx + 4, c.dy + 4),
              stroke,
            );
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.colour != colour;
}
