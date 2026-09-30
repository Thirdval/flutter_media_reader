/// The plain menu the reader shows over selected text (MR9, MR10): Copy
/// and Select all, and nothing that takes the text out of the app another
/// way. The host's menu over the canvas is drawn the same way, down (R8).
library;

import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';

/// A line of short words, each a button, in the chrome's colours: across
/// over a selection, down as a menu at the pointer.
class const MediaReaderTextMenu({
  required final List<MediaReaderMenuAction> actions,
  required final MediaReaderChrome chrome,
  final Axis direction = Axis.horizontal,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: chrome.background.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: chrome.foreground.withValues(alpha: 0.25)),
      ),
    ),
    child: DefaultTextStyle(
      style: TextStyle(
        color: chrome.foreground,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.none,
      ),
      // Down, the menu is as wide as its widest word, no wider.
      child: IntrinsicWidth(
        child: Flex(
          direction: direction,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: direction == Axis.vertical
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.center,
          children: [
            for (final action in actions)
              Semantics(
                button: true,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: action.onPressed,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Align(
                        alignment: direction == Axis.vertical
                            ? AlignmentDirectional.centerStart
                            : Alignment.center,
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(action.label),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
