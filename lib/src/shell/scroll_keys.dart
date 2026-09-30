/// The keys that scroll a page that reads (R6): the arrows, Page Up and
/// Page Down, Home and End, and the space bar.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Scrolls [controller] for [event], and says whether it did.
KeyEventResult scrollByKey(ScrollController controller, KeyEvent event) {
  if (event is KeyUpEvent || !controller.hasClients) {
    return KeyEventResult.ignored;
  }
  final position = controller.position;
  final page = position.viewportDimension * 0.9;
  final to = switch (event.logicalKey) {
    LogicalKeyboardKey.arrowDown => position.pixels + 48,
    LogicalKeyboardKey.arrowUp => position.pixels - 48,
    LogicalKeyboardKey.pageDown ||
    LogicalKeyboardKey.space => position.pixels + page,
    LogicalKeyboardKey.pageUp => position.pixels - page,
    LogicalKeyboardKey.home => 0.0,
    LogicalKeyboardKey.end => position.maxScrollExtent,
    _ => null,
  };
  if (to == null) return KeyEventResult.ignored;
  controller.jumpTo(to.clamp(0, position.maxScrollExtent));
  return KeyEventResult.handled;
}
