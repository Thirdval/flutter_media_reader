/// The plain defaults for the chrome's slots (MR10): the file's name and
/// place, a close button, and a pill for the engine's status. A host
/// replaces any of them with its own.
library;

import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';
import 'media_reader_glyph.dart';
import 'plain_widgets.dart';

/// The default top start: the file's name, and its place among the items
/// when there are several.
class const MediaReaderDefaultTitle({
  required final MediaReaderState state,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatelessWidget {
  // On a plate of the canvas's colour: a page of a document is often
  // white, and the name must be read over it.
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: chrome.background.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (state.count > 1)
            Text(
              chrome.strings.position(state.index + 1, state.count),
              style: TextStyle(
                color: chrome.foreground.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
        ],
      ),
    ),
  );
}

/// The default top end: a round close button.
class const MediaReaderDefaultClose({
  required final VoidCallback onPressed,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: chrome.strings.close,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: chrome.background.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 32,
                child: switch (chrome.glyph?.call(
                  context,
                  MediaReaderGlyph.close,
                  chrome.foreground,
                  MediaReaderGlyphButton.glyphSize,
                )) {
                  null => CustomPaint(painter: _Cross(chrome.foreground)),
                  final icon => Center(
                    child: ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: MediaReaderGlyphButton.glyphSize,
                        child: icon,
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The default status: a pill with the engine's own status.
class const MediaReaderDefaultStatus({
  required final String status,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: chrome.background.withValues(alpha: 0.6),
      shape: const StadiumBorder(),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(status, style: const TextStyle(fontSize: 13)),
    ),
  );
}

/// A cross, drawn rather than taken from an icon font the host may not
/// ship.
class const _Cross(final Color color) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final arm = size.shortestSide * 0.18;
    final centre = size.center(Offset.zero);
    canvas
      ..drawLine(centre - Offset(arm, arm), centre + Offset(arm, arm), paint)
      ..drawLine(centre - Offset(arm, -arm), centre + Offset(arm, -arm), paint);
  }

  @override
  bool shouldRepaint(_Cross old) => old.color != color;
}
