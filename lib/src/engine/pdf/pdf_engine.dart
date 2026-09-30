/// The PDF engine (MEDIA_READER_PLAN.md R5, MR5): `pdfrx`, on PDFium, on
/// every platform. A remote PDF is read by ranges as its pages are asked
/// for, through the package's own fetcher.
library;

import 'package:flutter/widgets.dart';

import '../../io/media_reader_transport.dart';
import '../../item/media_reader_item.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'pdf_view.dart';

/// Asks the host for the password of a protected PDF. [attempt] is 0 the
/// first time, and one more each time the last answer did not open the
/// file. Null gives up: the page shows the file's card.
typedef MediaReaderPdfPassword = Future<String?> Function(
  MediaReaderItem item,
  int attempt,
);

/// Shows PDFs: continuous pages, zoom, search, text that can be selected
/// and copied. An Office file is shown through the PDF the host makes of
/// it, handed in as the item's preview (MR7).
class const MediaReaderPdfEngine({
  /// Fetches a remote PDF, a range at a time.
  final MediaReaderTransport transport = const MediaReaderIoTransport(),

  /// The host's way to ask for a password. Without it a protected PDF
  /// shows its card.
  final MediaReaderPdfPassword? password,

  /// The size of the ranges a remote PDF is read by, in bytes. Its first
  /// page needs two of them: the file's first, and its last.
  final int blockSize = 256 * 1024,

  /// The most a page is magnified.
  final double maxScale = 8,

  /// What a double tap magnifies to, over the width-fitting size.
  final double doubleTapScale = 2.5,
}) implements MediaReaderEngine {
  @override
  String get id => 'pdf';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      item.kind == MediaKind.pdf && platform != TargetPlatform.fuchsia;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderPdfView(engine: this, item: item, page: page);
}
