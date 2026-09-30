/// The text engine (MEDIA_READER_PLAN.md R6): plain text, logs, code,
/// JSON, XML and the like, in Flutter's own text, a line at a time.
library;

import 'package:flutter/widgets.dart';

import '../../io/media_reader_transport.dart';
import '../../item/media_reader_item.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'text_view.dart';

/// What a text is, for how it is set: prose in the reader's own face,
/// the rest in a face of equal widths.
enum MediaReaderTextFlavour() {
  prose,
  code,
  json,
  xml,
}

/// Shows text files. A long one shows its start while the rest comes,
/// and builds only the lines on screen.
class const MediaReaderTextEngine({
  /// Fetches a remote file, a range at a time.
  final MediaReaderTransport transport = const MediaReaderIoTransport(),

  /// The most of a file that is taken into memory, in bytes. A longer
  /// file shows its start, and says so at its end.
  final int maxBytes = 32 * 1024 * 1024,

  /// The largest JSON or XML file that is laid out to be read; a larger
  /// one is shown as it is written.
  final int maxFormattedBytes = 1024 * 1024,

  /// The size of the ranges a remote file comes in, in bytes.
  final int blockSize = 256 * 1024,
}) implements MediaReaderEngine {
  static const Set<String> _prose = {'txt', 'text', 'srt', 'vtt', ''};
  static const Set<String> _xml = {'xml', 'svg', 'plist', 'xsd', 'rss'};

  /// What [item] is, by its name first: a `.json` sent as `text/plain`
  /// is JSON.
  static MediaReaderTextFlavour flavourOf(MediaReaderItem item) {
    final name = item.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1);
    final format = item.format;
    if (extension == 'json' || format == 'json') {
      return MediaReaderTextFlavour.json;
    }
    if (_xml.contains(extension) || format == 'xml') {
      return MediaReaderTextFlavour.xml;
    }
    return _prose.contains(extension) && (format == 'txt' || format.isEmpty)
        ? MediaReaderTextFlavour.prose
        : MediaReaderTextFlavour.code;
  }

  @override
  String get id => 'text';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      item.kind == MediaKind.text;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderTextView(engine: this, item: item, page: page);
}
