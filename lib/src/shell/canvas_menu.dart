/// The host's menu over the canvas (MEDIA_READER_PLAN.md R8): opened by a
/// right-click, or a long press with a finger, and drawn by the reader
/// at that point with the host's actions for the file on screen.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';
import 'text_menu.dart';

/// Where the menu is open: the point, in the reader, and whether the menu
/// stands above it (a finger covers what is below).
typedef MediaReaderMenuAnchor = ({Offset at, bool above});

/// Opens the menu from the gestures on [child].
class const MediaReaderMenuTrigger({
  required final ValueNotifier<MediaReaderMenuAnchor?> at,

  /// Whether the host has a menu at all.
  required final bool enabled,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderMenuTrigger> createState() => _MediaReaderMenuTriggerState();
}

class _MediaReaderMenuTriggerState() extends State<MediaReaderMenuTrigger> {
  PointerDeviceKind? _kind;

  /// A long press opens the menu from a finger or a stylus. A mouse held
  /// down is not asking for one: it has a right button.
  void _onLongPress(LongPressStartDetails details) {
    if (_kind case PointerDeviceKind.touch || PointerDeviceKind.stylus) {
      widget.at.value = (at: details.localPosition, above: true);
    }
  }

  void _onSecondaryTap(TapUpDetails details) =>
      widget.at.value = (at: details.localPosition, above: false);

  // The tree keeps its shape whether the host has a menu or not: the
  // pages below must not be built anew when the chrome changes.
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _kind = event.kind,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: widget.enabled ? _onSecondaryTap : null,
      onLongPressStart: widget.enabled ? _onLongPress : null,
      child: widget.child,
    ),
  );
}

/// The open menu, over everything: a tap or Esc closes it, and so does
/// choosing an action.
class const MediaReaderMenuLayer({
  required final ValueNotifier<MediaReaderMenuAnchor?> at,
  required final MediaReaderChrome chrome,

  /// What the host's builder is told, as the menu opens.
  required final MediaReaderState Function() state,
  super.key,
}) extends StatelessWidget {
  void _close() => at.value = null;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _close();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: at,
    builder: (context, anchor, _) {
      if (anchor == null) return const SizedBox.shrink();
      final actions = chrome.menu?.call(context, state()) ?? const [];
      if (actions.isEmpty) return const SizedBox.shrink();
      // What is under the menu is not for a screen reader while it is up.
      return BlockSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              // A right-click elsewhere opens the menu there instead.
              onSecondaryTapUp: (details) =>
                  at.value = (at: details.localPosition, above: false),
            ),
            CustomSingleChildLayout(
              delegate: _MenuPlace(anchor),
              child: Semantics(
                container: true,
                label: chrome.strings.menu,
                // A scope of its own: the keys are the menu's while it is
                // up, and go back to where they were when it closes.
                child: FocusScope(
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: _onKey,
                    child: MediaReaderTextMenu(
                      chrome: chrome,
                      direction: Axis.vertical,
                      actions: [
                        for (final action in actions)
                          (
                            label: action.label,
                            onPressed: () {
                              _close();
                              action.onPressed();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The menu at its anchor, kept within the reader with a small margin.
class const _MenuPlace(final MediaReaderMenuAnchor anchor)
    extends SingleChildLayoutDelegate {
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, constraints.maxWidth - 2 * _margin),
        maxHeight: math.max(0, constraints.maxHeight - 2 * _margin),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final (:at, :above) = anchor;
    final y = above ? at.dy - _margin - childSize.height : at.dy;
    return Offset(
      at.dx.clamp(
        _margin,
        math.max(_margin, size.width - childSize.width - _margin),
      ),
      y.clamp(
        _margin,
        math.max(_margin, size.height - childSize.height - _margin),
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuPlace old) => old.anchor != anchor;
}
