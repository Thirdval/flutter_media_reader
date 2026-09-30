/// The Markdown engine (MEDIA_READER_PLAN.md R6, MR12): rendered by
/// `flutter_markdown_plus`. A link goes to the host, and an image is
/// never fetched.
library;

import 'package:flutter/widgets.dart';

import '../../io/media_reader_transport.dart';
import '../../item/media_reader_item.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'markdown_view.dart';

/// Shows Markdown files laid out, or as they are written.
class const MediaReaderMarkdownEngine({
  /// Fetches a remote file, a range at a time.
  final MediaReaderTransport transport = const MediaReaderIoTransport(),

  /// The largest file that is laid out; a larger one is shown as it is
  /// written, like any text.
  final int maxFormattedBytes = 1024 * 1024,

  /// The most of a file that is taken into memory, in bytes.
  final int maxBytes = 32 * 1024 * 1024,
}) implements MediaReaderEngine {
  @override
  String get id => 'markdown';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      item.kind == MediaKind.markdown;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderMarkdownView(engine: this, item: item, page: page);
}
