/// The chrome over the canvas (MEDIA_READER_PLAN.md §2.1): the slots laid
/// out, in reading order, hidden and brought back by a tap on the canvas.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'default_slots.dart';
import 'media_reader_chrome.dart';
import 'transport_bar.dart';

/// Where each part of the reader comes in the reading order: the top
/// slots, the page, then what sits below it.
abstract final class MediaReaderOrder() {
  static const double topStart = 0;
  static const double topEnd = 1;
  static const double page = 2;
  static const double controls = 3;
  static const double status = 4;
  static const double contextPill = 5;
  static const double bottomStart = 6;
  static const double bottomEnd = 7;
}

/// Shows and hides the chrome, and fades it as a dismissing drag goes on.
/// Neither rebuilds the slots in [child].
class const MediaReaderChromeLayer({
  /// Whether the person has the chrome showing. With a screen reader or
  /// switch control it always shows: a hidden close button cannot be
  /// reached.
  required final ValueListenable<bool> visible,

  /// How far a dismissing drag has gone, 0..1.
  required final ValueListenable<double> dismissing,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: dismissing,
    builder: (context, dismissing, child) =>
        Opacity(opacity: 1 - dismissing, child: child),
    child: ValueListenableBuilder(
      valueListenable: visible,
      builder: (context, visible, child) {
        final shown = visible || MediaQuery.accessibleNavigationOf(context);
        return IgnorePointer(
          ignoring: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            child: child,
          ),
        );
      },
      child: child,
    ),
  );
}

/// Lays the slots out over the canvas. Its empty middle lets taps and
/// drags through to the page.
class const MediaReaderChromeSlots({
  required final MediaReaderChrome chrome,
  required final MediaReaderState state,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final status = state.status;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _slot(
                      context,
                      MediaReaderOrder.topStart,
                      chrome.topStart,
                      MediaReaderDefaultTitle(state: state, chrome: chrome),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _slot(
                  context,
                  MediaReaderOrder.topEnd,
                  chrome.topEnd,
                  switch (state.close) {
                    null => null,
                    final close => MediaReaderDefaultClose(
                      onPressed: close,
                      chrome: chrome,
                    ),
                  },
                ),
              ],
            ),
            const Spacer(),
            _slot(
              context,
              MediaReaderOrder.controls,
              chrome.controls,
              switch (state.playback) {
                null => null,
                final playback => MediaReaderTransportBar(
                  playback: playback,
                  chrome: chrome,
                  peaks: state.item.peaks,
                ),
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: _slot(
                context,
                MediaReaderOrder.status,
                chrome.status,
                status == null
                    ? null
                    : MediaReaderDefaultStatus(status: status, chrome: chrome),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: _slot(
                context,
                MediaReaderOrder.contextPill,
                chrome.contextPill,
                null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _slot(
                      context,
                      MediaReaderOrder.bottomStart,
                      chrome.bottomStart,
                      null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _slot(
                  context,
                  MediaReaderOrder.bottomEnd,
                  chrome.bottomEnd,
                  null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The host's widget for a slot, or the plain default; at its place in
  /// the reading order.
  Widget _slot(
    BuildContext context,
    double order,
    MediaReaderSlotBuilder? builder,
    Widget? plain,
  ) => Semantics(
    container: true,
    sortKey: OrdinalSortKey(order),
    child: builder?.call(context, state) ?? plain ?? const SizedBox.shrink(),
  );
}
