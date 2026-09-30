/// The archive engine (MEDIA_READER_PLAN.md R6): zip, tar and gzip
/// listed with their sizes, and an entry opened through the registry in a
/// reader of its own. A zip is listed from its end and a tar from its
/// headers, so a large archive on a server is listed after reading a
/// little of it, and only the entry that is opened is fetched.
library;

import 'package:flutter/widgets.dart';

import '../../io/media_reader_transport.dart';
import '../../item/media_reader_item.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'archive_view.dart';

/// Shows what an archive holds.
class const MediaReaderArchiveEngine({
  /// Fetches a remote archive, a range at a time.
  final MediaReaderTransport transport = const MediaReaderIoTransport(),

  /// The size of the ranges a remote archive comes in, in bytes.
  final int blockSize = 256 * 1024,

  /// The largest entry that is taken out, in bytes, and the largest
  /// gzip file that is unpacked: gzip is one stream, read whole.
  final int maxEntryBytes = 64 * 1024 * 1024,
}) implements MediaReaderEngine {
  /// What the reader unpacks. 7z and rar are left to the card.
  static const Set<String> _formats = {'zip', 'tar', 'gz'};

  @override
  String get id => 'archive';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      item.kind == MediaKind.archive && _formats.contains(item.format);

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderArchiveView(engine: this, item: item, page: page);
}
