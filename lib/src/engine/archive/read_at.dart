/// Reading a file at any place in it (MEDIA_READER_PLAN.md R6): a remote
/// file by ranges at the location the page keeps, a file on the device,
/// or bytes in memory. An archive is read this way: its list from its
/// end, and only the entry that is opened.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../io/media_reader_blocks.dart';
import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';

/// A file read at any place in it.
abstract interface class MediaReaderReadAt() {
  /// The file's length.
  Future<int> length();

  /// Up to [count] bytes from [position]: fewer only at the end of the
  /// file.
  Future<Uint8List> read(int position, int count);

  /// The file is done with.
  void close();

  /// How [item] is read for [page].
  static MediaReaderReadAt of(
    MediaReaderItem item,
    MediaReaderPage page, {
    required MediaReaderFetcher fetcher,
    required int blockSize,
  }) => switch (item.source) {
    MediaReaderBytesSource(:final bytes) => MediaReaderBytesAt(bytes),
    MediaReaderFileSource(:final path) => MediaReaderFileAt(path),
    MediaReaderRemoteSource() => MediaReaderRangesAt(
      MediaReaderBlockReader(
        page: page,
        id: '${item.id}:${item.format}',
        fetcher: fetcher,
        blockSize: blockSize,
      ),
    ),
  };
}

/// Bytes in memory.
final class MediaReaderBytesAt(final Uint8List _bytes)
    implements MediaReaderReadAt {
  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<Uint8List> read(int position, int count) async {
    final start = math.min(position, _bytes.length);
    return Uint8List.sublistView(
      _bytes,
      start,
      math.min(start + count, _bytes.length),
    );
  }

  @override
  void close() {}
}

/// A file on the device.
final class MediaReaderFileAt(final String _path) implements MediaReaderReadAt {
  RandomAccessFile? _file;

  Future<RandomAccessFile> get _open async =>
      _file ??= await File(_path).open();

  @override
  Future<int> length() async => await (await _open).length();

  @override
  Future<Uint8List> read(int position, int count) async {
    final file = await _open;
    await file.setPosition(position);
    return await file.read(count);
  }

  @override
  void close() {
    _file?.closeSync();
    _file = null;
  }
}

/// A remote file, by ranges.
final class MediaReaderRangesAt(final MediaReaderBlockReader _blocks)
    implements MediaReaderReadAt {
  @override
  Future<int> length() => _blocks.length();

  @override
  Future<Uint8List> read(int position, int count) async {
    final buffer = Uint8List(count);
    final got = await _blocks.read(buffer, position, count);
    return got == count ? buffer : Uint8List.sublistView(buffer, 0, got);
  }

  @override
  void close() => _blocks.close();
}
