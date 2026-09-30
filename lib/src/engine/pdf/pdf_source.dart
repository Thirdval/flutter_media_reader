/// Opens a PDF from the item's source (MEDIA_READER_PLAN.md R5): a
/// remote file by ranges through the page's location, a file on the
/// device, or bytes in memory.
library;

import 'dart:async';

import 'package:pdfrx/pdfrx.dart';

import '../../io/media_reader_blocks.dart';
import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import 'pdf_engine.dart';

/// An open PDF, and what reads it when it is remote.
typedef MediaReaderOpenPdf = ({
  PdfDocument document,
  MediaReaderBlockReader? reader,
});

int _opened = 0;

/// Opens [item] for [page].
///
/// Throws what the host's resolve throws, a [MediaReaderFetchException]
/// when the file does not come, a [PdfPasswordException] when it is
/// protected and no password opens it, and a [PdfException] when it is
/// not a PDF that PDFium reads.
Future<MediaReaderOpenPdf> openMediaReaderPdf({
  required MediaReaderItem item,
  required MediaReaderPage page,
  required MediaReaderPdfEngine engine,

  /// A read failed once the document was open: the network went, the
  /// location was refused for good.
  required void Function(Object error) onReadFailure,
}) async {
  // It does its work once, and nothing after.
  await pdfrxFlutterInitialize();
  // Its own for each opening: pdfrx keeps what it knows of a document
  // under this name.
  final name = 'media-reader:${item.id}:${_opened++}';
  var attempt = 0;
  final ask = engine.password;
  final PdfPasswordProvider? password = ask == null
      ? null
      : () => ask(page.item, attempt++);
  switch (item.source) {
    case MediaReaderFileSource(:final path):
      final document = await PdfDocument.openFile(
        path,
        passwordProvider: password,
        useProgressiveLoading: true,
      );
      return (document: document, reader: null);
    case MediaReaderBytesSource(:final bytes):
      final document = await PdfDocument.openData(
        bytes,
        sourceName: name,
        passwordProvider: password,
        useProgressiveLoading: true,
      );
      return (document: document, reader: null);
    case MediaReaderRemoteSource():
      final reader = MediaReaderBlockReader(
        page: page,
        // A file and the PDF made of it are kept apart.
        id: '${item.id}:${item.format}',
        fetcher: MediaReaderFetcher(engine.transport),
        blockSize: engine.blockSize,
      );
      var open = false;
      try {
        final document = await PdfDocument.openCustom(
          fileSize: await reader.length(),
          read: (buffer, position, size) async {
            try {
              return await reader.read(buffer, position, size);
            } on Object catch (error) {
              if (open) onReadFailure(error);
              rethrow;
            }
          },
          sourceName: name,
          passwordProvider: password,
          useProgressiveLoading: true,
          // A file of one range is read whole, as it comes in one answer
          // anyway. A larger one is read as PDFium asks, so its first
          // page is up before the rest has come.
          maxSizeToCacheOnMemory: engine.blockSize,
        );
        open = true;
        return (document: document, reader: reader);
      } on Object catch (error) {
        reader.close();
        // Why PDFium could not read is what the fetch said, not what
        // PDFium made of a read that came back empty.
        if (error is PdfPasswordException) rethrow;
        throw reader.failure ?? error;
      }
  }
}
