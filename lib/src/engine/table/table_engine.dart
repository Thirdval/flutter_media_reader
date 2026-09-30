/// The table engine (MEDIA_READER_PLAN.md R6): CSV and TSV as a table
/// whose cells are built only where they are on screen, with a header
/// row that stays.
library;

import 'package:flutter/widgets.dart';

import '../../io/media_reader_transport.dart';
import '../../item/media_reader_item.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'table_view.dart';

/// Shows CSV and TSV files.
class const MediaReaderTableEngine({
  /// Fetches a remote file, a range at a time.
  final MediaReaderTransport transport = const MediaReaderIoTransport(),

  /// The most of a file that is taken into memory, in bytes.
  final int maxBytes = 32 * 1024 * 1024,

  /// The size of the ranges a remote file comes in, in bytes.
  final int blockSize = 256 * 1024,
}) implements MediaReaderEngine {
  @override
  String get id => 'table';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      item.kind == MediaKind.table;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderTableView(engine: this, item: item, page: page);
}
