/// The track a playing file is followed and scrubbed along
/// (MEDIA_READER_PLAN.md R4, MR6): the sound's peaks as bars where the
/// host has them, a plain line where it has not.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'transport_bar.dart' show formatPlaybackTime;

/// A waveform, or a plain track, with how far the file has played. A
/// tap or a drag along it seeks; to a screen reader it is a slider.
///
/// It runs left to right in every language, as players do.
class const MediaReaderWaveform({
  required final Duration position,

  /// The file's length; null while it is not known, and then nothing can
  /// be sought.
  required final Duration? duration,
  required final ValueChanged<Duration> onSeek,

  /// The sound's peaks, each 0..1, as the host has them (MR6). Null or
  /// empty draws a plain track with a thumb.
  final List<double>? peaks,

  /// How far the file is buffered; drawn on the plain track.
  final Duration buffered = Duration.zero,
  required final Color color,

  /// What a screen reader calls the slider.
  final String semanticLabel = 'Position',
  final double height = 40,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderWaveform> createState() => _MediaReaderWaveformState();
}

class _MediaReaderWaveformState() extends State<MediaReaderWaveform> {
  /// What a screen reader's "increase" and "decrease" move by.
  static const _step = Duration(seconds: 5);

  /// Where the drag is, 0..1, while there is one.
  double? _dragging;

  double _fractionOf(Duration at) => switch (widget.duration) {
    null || Duration.zero => 0,
    final duration => (at.inMicroseconds / duration.inMicroseconds).clamp(0, 1),
  };

  double _fractionAt(double x) =>
      (x / math.max(1, context.size?.width ?? 1)).clamp(0, 1);

  void _seekTo(double fraction) {
    final duration = widget.duration;
    if (duration != null) widget.onSeek(duration * fraction);
  }

  /// The position [by] further on, kept inside the file; null while the
  /// file's length is not known.
  Duration? _nudged(Duration by) {
    final duration = widget.duration;
    if (duration == null) return null;
    final to = widget.position + by;
    if (to < Duration.zero) return Duration.zero;
    return to > duration ? duration : to;
  }

  @override
  Widget build(BuildContext context) {
    final forward = _nudged(_step);
    final back = _nudged(-_step);
    final peaks = widget.peaks;
    final played = _dragging ?? _fractionOf(widget.position);
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: formatPlaybackTime(widget.position),
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
          height: widget.height,
          child: CustomPaint(
            painter: peaks == null || peaks.isEmpty
                ? _Track(
                    played: played,
                    buffered: _fractionOf(widget.buffered),
                    colour: widget.color,
                  )
                : _Bars(peaks: peaks, played: played, colour: widget.color),
          ),
        ),
      ),
    );
  }
}

/// A line, the part buffered, the part played, and a thumb.
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

/// The peaks as bars: as many as fit, each the loudest of the peaks it
/// stands for, the played ones in full colour.
class const _Bars({
  required final List<double> peaks,
  required final double played,
  required final Color colour,
}) extends CustomPainter {
  static const _width = 3.0;
  static const _gap = 2.0;
  static const _least = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final count = math.max(1, (size.width + _gap) ~/ (_width + _gap));
    final paint = Paint()
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var bar = 0; bar < count; bar++) {
      final from = bar * peaks.length ~/ count;
      final to = math.max(from + 1, (bar + 1) * peaks.length ~/ count);
      var peak = 0.0;
      for (var i = from; i < to && i < peaks.length; i++) {
        // A peak that is not a number counts as silence.
        if (peaks[i] > peak) peak = peaks[i];
      }
      final half = math.max(_least, peak.clamp(0, 1) * size.height) / 2;
      final x = _width / 2 + bar * (_width + _gap);
      final isPlayed = (bar + 0.5) / count <= played;
      canvas.drawLine(
        Offset(x, y - half + _width / 2),
        Offset(x, y + half - _width / 2),
        paint..color = colour.withValues(alpha: isPlayed ? 1 : 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_Bars old) =>
      old.played != played || old.colour != colour || old.peaks != peaks;
}
