/// The plain menu the reader shows over selected text (MR9, MR10): Copy
/// and Select all, and nothing that takes the text out of the app another
/// way.
library;

import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';

/// One thing the menu offers.
typedef MediaReaderTextMenuAction = ({String label, VoidCallback onPressed});

/// A row of short words, each a button, in the chrome's colours.
class const MediaReaderTextMenu({
  required final List<MediaReaderTextMenuAction> actions,
  required final MediaReaderChrome chrome,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
                    child: Center(
                      widthFactor: 1,
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
  );
}
