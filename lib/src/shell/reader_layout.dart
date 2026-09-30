/// The reader's parts in their places (MEDIA_READER_PLAN.md §2.1, R8):
/// the canvas with the chrome over it, the host's menu over both, and on
/// a wide window the rail of files beside them.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'canvas_menu.dart';
import 'chrome_layer.dart';
import 'media_reader_chrome.dart';
import 'rail.dart';

/// Lays the reader out.
class const MediaReaderLayout({
  required final MediaReaderChrome chrome,

  /// Whether the person has the chrome showing.
  required final ValueListenable<bool> chromeVisible,

  /// How far a dismissing drag has gone, 0..1.
  required final ValueListenable<double> dismissing,

  /// Where the host's menu is open, when it is.
  required final ValueNotifier<MediaReaderMenuAnchor?> menuAt,

  /// What the host's menu builder is told.
  required final MediaReaderState Function() state,

  /// The pages.
  required final Widget canvas,

  /// The chrome's slots, over the canvas.
  required final Widget slots,

  /// The rail of files; null where there is nothing to choose between.
  final Widget? rail,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ValueListenableBuilder(
        valueListenable: dismissing,
        builder: (context, dismissing, _) => ColoredBox(
          color: chrome.background.withValues(
            alpha: chrome.background.a * (1 - dismissing),
          ),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final reader = Stack(
            fit: StackFit.expand,
            children: [
              MediaReaderMenuTrigger(
                at: menuAt,
                enabled: chrome.menu != null,
                child: canvas,
              ),
              MediaReaderChromeLayer(
                visible: chromeVisible,
                dismissing: dismissing,
                child: slots,
              ),
              MediaReaderMenuLayer(at: menuAt, chrome: chrome, state: state),
            ],
          );
          final rail = this.rail;
          if (rail == null || constraints.maxWidth < chrome.railFromWidth) {
            return reader;
          }
          return Row(
            children: [
              _RailShown(
                visible: chromeVisible,
                dismissing: dismissing,
                child: rail,
              ),
              Expanded(child: reader),
            ],
          );
        },
      ),
    ],
  );
}

/// The rail comes and goes with the chrome, and fades with a dismissing
/// drag as the chrome does.
class const _RailShown({
  required final ValueListenable<bool> visible,
  required final ValueListenable<double> dismissing,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: visible,
    builder: (context, visible, child) {
      final shown = visible || MediaQuery.accessibleNavigationOf(context);
      return TweenAnimationBuilder<double>(
        tween: Tween(end: shown ? 1 : 0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        builder: (context, shown, child) => Offstage(
          offstage: shown == 0,
          child: SizedBox(
            width: MediaReaderRail.width * shown,
            child: ClipRect(
              child: OverflowBox(
                minWidth: MediaReaderRail.width,
                maxWidth: MediaReaderRail.width,
                alignment: AlignmentDirectional.centerEnd,
                child: child,
              ),
            ),
          ),
        ),
        child: child,
      );
    },
    child: ValueListenableBuilder(
      valueListenable: dismissing,
      builder: (context, dismissing, child) =>
          Opacity(opacity: 1 - dismissing, child: child),
      child: child,
    ),
  );
}
