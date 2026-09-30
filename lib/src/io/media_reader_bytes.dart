/// A file's bytes as they come (MEDIA_READER_PLAN.md R6, MR11): a remote
/// file a range at a time at the location the page keeps, a file on the
/// device a piece at a time, or bytes in memory. Never more than a limit:
/// an engine that takes a file into memory says how much it takes.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../item/media_reader_item.dart';
import '../item/media_reader_source.dart';
import '../shell/media_reader_page.dart';
import 'media_reader_blocks.dart';
import 'media_reader_fetcher.dart';

/// What was loaded of a file.
typedef MediaReaderLoaded = ({
  /// The file's bytes, from its start.
  Uint8List bytes,

  /// The file's own length: more than [bytes] has when the file was cut
  /// at the limit.
  int total,
});

/// Loads [item]'s bytes for [page], up to [limit] of them.
final class MediaReaderByteLoader({
  required final MediaReaderItem _item,
  required final MediaReaderPage _page,
  required final int _limit,
  final MediaReaderFetcher _fetcher = const MediaReaderFetcher(),

  /// The size of the pieces the file comes in.
  final int _blockSize = 256 * 1024,
}) {
  MediaReaderBlockReader? _reader;
  bool _cancelled = false;

  /// Loads the file. [onPart] is told each time more of it is there:
  /// the buffer all of it goes into, and how much of the buffer is
  /// filled, so that an engine can show the start of a long file while
  /// the rest comes.
  ///
  /// Throws what the host's resolve throws, a [MediaReaderFetchException]
  /// when a remote file does not come, and a [FileSystemException] when a
  /// file on the device cannot be read.
  Future<MediaReaderLoaded> load({
    void Function(Uint8List buffer, int filled)? onPart,
  }) async {
    switch (_item.source) {
      case MediaReaderBytesSource(:final bytes):
        final kept = bytes.length > _limit
            ? Uint8List.sublistView(bytes, 0, _limit)
            : bytes;
        onPart?.call(kept, kept.length);
        return (bytes: kept, total: bytes.length);
      case MediaReaderFileSource(:final path):
        final file = await File(path).open();
        try {
          final total = await file.length();
          return await _fill(
            total,
            (buffer, at, count) => file.readInto(buffer, at, at + count),
            onPart,
          );
        } finally {
          await file.close();
        }
      case MediaReaderRemoteSource():
        final reader = _reader = MediaReaderBlockReader(
          page: _page,
          id: '${_item.id}:${_item.format}',
          fetcher: _fetcher,
          blockSize: _blockSize,
        );
        try {
          return await _fill(
            await reader.length(),
            (buffer, at, count) => reader.read(
              Uint8List.sublistView(buffer, at, at + count),
              at,
              count,
            ),
            onPart,
          );
        } finally {
          // What was read is in the buffer now, and where the policy
          // keeps it.
          reader.close();
        }
    }
  }

  /// Gives the load up: a piece on its way is not waited for.
  void cancel() {
    _cancelled = true;
    _reader?.close();
  }

  Future<MediaReaderLoaded> _fill(
    int total,
    Future<int> Function(Uint8List buffer, int at, int count) read,
    void Function(Uint8List buffer, int filled)? onPart,
  ) async {
    final buffer = Uint8List(math.min(total, _limit));
    var at = 0;
    while (at < buffer.length && !_cancelled) {
      final count = await read(
        buffer,
        at,
        math.min(_blockSize, buffer.length - at),
      );
      // The file is shorter than it said.
      if (count <= 0) break;
      at += count;
      onPart?.call(buffer, at);
    }
    final bytes = at == buffer.length
        ? buffer
        : Uint8List.sublistView(buffer, 0, at);
    return (bytes: bytes, total: total);
  }
}
