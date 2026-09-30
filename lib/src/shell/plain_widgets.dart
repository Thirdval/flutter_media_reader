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
