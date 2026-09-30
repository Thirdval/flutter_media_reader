/// The few plain widgets the reader draws itself, where no host widget
/// stands and no icon font or design system can be assumed: a button and
/// a busy ring.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';

/// A plain pill button in the chrome's colours.
class const MediaReaderPlainButton({
  required final String label,
  required final VoidCallback onPressed,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderPlainButton> createState() => _MediaReaderPlainButtonState();
}

class _MediaReaderPlainButtonState() extends State<MediaReaderPlainButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colour = widget.chrome.foreground;
    final lit = _focused || _hovered;
    return Semantics(
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        onShowHoverHighlight: (hovered) => setState(() => _hovered = hovered),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onPressed(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colour.withValues(alpha: lit ? 0.16 : 0),
              shape: StadiumBorder(
                side: BorderSide(
                  color: colour.withValues(alpha: _focused ? 1 : 0.5),
                  width: _focused ? 2 : 1,
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(widget.label, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A ring that turns while a file is on the way. It stands still where
/// the person has asked for less motion.
class const MediaReaderBusy({
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderBusy> createState() => _MediaReaderBusyState();
}

class _MediaReaderBusyState()
    extends State<MediaReaderBusy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.chrome.strings.loading,
    child: SizedBox.square(
      dimension: 28,
      child: CustomPaint(painter: _Ring(widget.chrome.foreground, _turn)),
    ),
  );
}

class const _Ring(final Color color, final Animation<double> turn)
    extends CustomPainter {
  this : super(repaint: turn);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(2);
    canvas
      ..drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        paint..color = color.withValues(alpha: 0.2),
      )
      ..drawArc(
        rect,
        turn.value * math.pi * 2,
        math.pi * 0.6,
        false,
        paint..color = color,
      );
  }

  @override
  bool shouldRepaint(_Ring old) => old.color != color;
}

/// The glyphs the reader draws itself: no icon font is assumed.
enum MediaReaderGlyph() {
  play,
  pause,
  sound,
  muted,
}

/// A round button with a drawn glyph: no icon font is assumed.
class const MediaReaderGlyphButton({
  required final MediaReaderGlyph glyph,
  required final String label,
  required final Color colour,
  required final VoidCallback? onPressed,
  super.key,
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

/// A button that is a short word: a speed.
class const MediaReaderTextButton({
  required final String text,
  required final VoidCallback? onPressed,
  super.key,
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

class const _GlyphPainter(final MediaReaderGlyph glyph, final Color colour)
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
      case MediaReaderGlyph.play:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 5, c.dy - 8)
            ..lineTo(c.dx + 8, c.dy)
            ..lineTo(c.dx - 5, c.dy + 8)
            ..close(),
          fill,
        );
      case MediaReaderGlyph.pause:
        canvas
          ..drawRect(Rect.fromLTWH(c.dx - 6, c.dy - 7, 4, 14), fill)
          ..drawRect(Rect.fromLTWH(c.dx + 2, c.dy - 7, 4, 14), fill);
      case MediaReaderGlyph.sound || MediaReaderGlyph.muted:
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
        if (glyph == MediaReaderGlyph.sound) {
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
