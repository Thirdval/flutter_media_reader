/// An engine shows one kind of file (MEDIA_READER_PLAN.md §2.1): an
/// adapter over a maintained plugin, chosen per platform by the registry.
library;

import 'package:flutter/widgets.dart';

import '../item/media_reader_item.dart';
import '../shell/media_reader_page.dart';

/// Shows the files it can, on the platforms it can.
abstract interface class MediaReaderEngine() {
  /// A stable name: for logs, for tests, and for a host that replaces one
  /// engine.
  String get id;

  /// Whether this engine shows [item] on [platform]. It is asked with the
  /// file's name, content type and kind alone: nothing is fetched to
  /// decide.
  bool canShow(MediaReaderItem item, TargetPlatform platform);

  /// The engine's widget for [item] on [page].
  ///
  /// [item] is the host's item, or its preview read as an item when that
  /// is what this engine can show; [MediaReaderPage.item] is always the
  /// host's. An engine that turns out not to show the file calls
  /// [MediaReaderPage.fail], and the file's card takes its place.
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  );
}
