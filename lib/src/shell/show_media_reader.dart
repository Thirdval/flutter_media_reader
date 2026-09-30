/// The reader as a route (MEDIA_READER_PLAN.md §2.2).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../engine/media_reader_engines.dart';
import '../item/media_reader_item.dart';
import '../item/media_reader_policy.dart';
import 'media_reader_chrome.dart';
import 'media_reader_view.dart';

/// Opens the reader over the app at [items]`[initialIndex]`. The future
/// completes when the reader is dismissed: a drag down, Esc, the close
/// button, or the platform's back.
///
/// The route is see-through, so the page beneath shows as the reader is
/// dragged away.
Future<void> showMediaReader(
  BuildContext context, {
  required List<MediaReaderItem> items,
  int initialIndex = 0,
  MediaReaderChrome chrome = const MediaReaderChrome(),
  MediaReaderPolicy policy = const MediaReaderPolicy(),
  MediaReaderEngines engines = MediaReaderEngines.standard,
  ValueChanged<MediaReaderItem>? onItemShown,
  ValueChanged<Uri>? onLink,
  bool useRootNavigator = true,
}) => Navigator.of(context, rootNavigator: useRootNavigator).push<void>(
  PageRouteBuilder<void>(
    opaque: false,
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => MediaReaderView(
      items: items,
      initialIndex: initialIndex,
      chrome: chrome,
      policy: policy,
      engines: engines,
      onItemShown: onItemShown,
      onLink: onLink,
      onDismissed: () => unawaited(Navigator.of(context).maybePop()),
    ),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
);
