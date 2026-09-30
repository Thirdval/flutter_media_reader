/// Text that can be selected and copied (MR9, MR10): Flutter's own
/// selection, with plain handles and the reader's menu of Copy and Select
/// all in place of a design system's.
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';
import 'text_menu.dart';

/// Makes the text under [child] selectable.
///
/// Copying is not an export: it is offered whatever the policy says
/// (MR9).
class const MediaReaderSelectable({
  required final MediaReaderChrome chrome,
  required final Widget child,

  /// All of the text, when "Select all" is to mean all of a file and not
  /// only the part of it that is built: a long text builds the lines on
  /// screen. Null leaves "Select all" to what is built.
  final String Function()? all,

  /// A tap on the text while nothing is selected. A tap that lets go of
  /// a selection is not one.
  final VoidCallback? onTap,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderSelectable> createState() => _MediaReaderSelectableState();
}

class _MediaReaderSelectableState() extends State<MediaReaderSelectable> {
  final FocusNode _focus = FocusNode(debugLabel: 'MediaReaderSelectable');
  late _Handles _handles = _Handles(widget.chrome.foreground);

  /// Whether "Select all" was the last thing chosen: Copy then takes all
  /// of the text.
  bool _allSelected = false;
  bool _hasSelection = false;

  // A primary pointer that went down with nothing selected: where and
  // when, to tell a tap from a drag and from a long press.
  ({Offset at, Duration when})? _down;

  void _onDown(PointerDownEvent event) {
    // A new selection is no longer all of the text.
    _allSelected = false;
    _down = event.buttons == kPrimaryButton && !_hasSelection
        ? (at: event.position, when: event.timeStamp)
        : null;
  }

  void _onUp(PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (down == null) return;
    final still = (event.position - down.at).distance < kTouchSlop;
    final quick = event.timeStamp - down.when < kLongPressTimeout;
    if (still && quick) widget.onTap?.call();
  }

  @override
  void didUpdateWidget(MediaReaderSelectable old) {
    super.didUpdateWidget(old);
    if (old.chrome.foreground != widget.chrome.foreground) {
      _handles = _Handles(widget.chrome.foreground);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Widget _menu(BuildContext context, SelectableRegionState region) {
    final strings = widget.chrome.strings;
    final all = widget.all;
    final anchors = region.contextMenuAnchors;
    // A selection may reach past the screen, as all of a long text does:
    // the menu stays on it.
    final size = MediaQuery.sizeOf(context);
    Offset onScreen(Offset anchor) => Offset(
      anchor.dx.clamp(0, size.width),
      anchor.dy.clamp(size.height * 0.15, size.height * 0.85),
    );
    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: onScreen(anchors.primaryAnchor),
        anchorBelow: onScreen(anchors.secondaryAnchor ?? anchors.primaryAnchor),
      ),
      child: MediaReaderTextMenu(
        chrome: widget.chrome,
        actions: [
          // Flutter's own say on what is offered: Copy with a selection,
          // Select all while not everything is selected. Nothing else
          // is taken from it.
          for (final item in region.contextMenuButtonItems)
            if (item.type == ContextMenuButtonType.copy)
              (
                label: strings.copy,
                onPressed: () {
                  if (_allSelected && all != null) {
                    unawaited(Clipboard.setData(ClipboardData(text: all())));
                    region.hideToolbar();
                  } else {
                    item.onPressed?.call();
                  }
                },
              )
            else if (item.type == ContextMenuButtonType.selectAll)
              (
                label: strings.selectAll,
                onPressed: () {
                  _allSelected = true;
                  region.selectAll(SelectionChangedCause.toolbar);
                },
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final region = SelectableRegion(
      focusNode: _focus,
      selectionControls: _handles,
      contextMenuBuilder: _menu,
      onSelectionChanged: (content) =>
          _hasSelection = content != null && content.plainText.isNotEmpty,
      // The pointer on the text itself: the menu and the handles float
      // above, outside.
      child: Listener(
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: (_) => _down = null,
        child: widget.child,
      ),
    );
    // They float in an overlay: the app's, or one of the page's own
    // where the host has none.
    return Overlay.maybeOf(context) == null
        ? Overlay.wrap(child: region)
        : region;
  }
}

/// Plain selection handles: a dot under each end of the selection. The
/// menu is the region's own, from its `contextMenuBuilder`.
class _Handles(final Color colour)
    extends TextSelectionControls
    with TextSelectionHandleControls {
  static const _size = 22.0;

  @override
  Size getHandleSize(double textLineHeight) => const Size.square(_size);

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) =>
      switch (type) {
        TextSelectionHandleType.left => const Offset(_size, 0),
        TextSelectionHandleType.right => Offset.zero,
        TextSelectionHandleType.collapsed => const Offset(_size / 2, 0),
      };

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) => GestureDetector(
    onTap: onTap,
    child: SizedBox.square(
      dimension: _size,
      child: CustomPaint(painter: _HandlePainter(colour, type)),
    ),
  );
}

class const _HandlePainter(
  final Color colour,
  final TextSelectionHandleType type,
) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 7.0;
    // The dot hangs from the end of the selection: from its corner.
    final centre = switch (type) {
      TextSelectionHandleType.left => Offset(size.width - radius, radius),
      TextSelectionHandleType.right => const Offset(radius, radius),
      TextSelectionHandleType.collapsed => Offset(size.width / 2, radius),
    };
    canvas.drawCircle(centre, radius, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_HandlePainter old) =>
      old.colour != colour || old.type != type;
}
