/// A remote file read a block at a time (MEDIA_READER_PLAN.md R5,
/// MR11): what an engine that seeks needs of a large file, a PDF's
/// pages, without fetching all of it. The blocks are kept where the
/// policy allows, and nowhere else (MR9).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../item/media_reader_policy.dart';
import '../shell/media_reader_page.dart';
import 'media_reader_block_file.dart';
import 'media_reader_block_memory.dart';
import 'media_reader_fetcher.dart';

/// Reads the page's remote file by blocks of [blockSize] bytes, each
/// fetched once, at the location the page keeps.
///
/// Where the blocks stay follows the policy's cache:
/// - none: in memory while the file is open, gone when it is closed;
/// - memory: in memory between showings too, up to a budget the whole
///   app shares;
/// - a directory: in a file there, read back the next time.
final class MediaReaderBlockReader({
  required final MediaReaderPage _page,

  /// The file's id: what its blocks are kept under.
  required final String _id,
  final MediaReaderFetcher _fetcher = const MediaReaderFetcher(),
  MediaReaderCache? cache,
  final int blockSize = 256 * 1024,

  /// How long a block may take to come. Whatever reads through this
  /// reader is held up while it waits, so a connection that has stalled
  /// is given up on.
  final Duration _timeout = const Duration(seconds: 60),
}) {
  final MediaReaderCache _cache = cache ?? _page.policy.cache;

  late final MediaReaderBlockMemory _memory = switch (_cache) {
    MediaReaderMemoryCache() => MediaReaderBlockMemory.shared,
    // The file's own, and let go of with it.
    _ => MediaReaderBlockMemory(),
  };
  late final MediaReaderBlockFile? _file = switch (_cache) {
    MediaReaderDirectoryCache(:final path) => MediaReaderBlockFile(
      directory: path,
      id: _id,
      blockSize: blockSize,
    ),
    _ => null,
  };
  final Map<int, Future<Uint8List>> _fetching = {};
  final Completer<void> _closing = Completer();
  bool _closed = false;

  /// What the last fetch that failed threw: why a read came back short.
  /// Null while every read has been answered.
  Object? failure;

  /// How many bytes have been fetched from the server by this reader.
  int fetched = 0;

  /// The key the blocks are kept under: a block of another size is
  /// another block.
  String get _key => '$_id@$blockSize';

  /// The file's length. The first block is fetched to learn it, unless
  /// the length is already kept.
  Future<int> length() async {
    final kept = _memory.totalOf(_key) ?? _file?.total;
    if (kept != null) return kept;
    await _block(0);
    return _memory.totalOf(_key) ??
        (throw const MediaReaderFetchException(status: 206));
  }

  /// Fills [buffer] with up to [size] bytes from [position], and says how
  /// many it put there: fewer than asked only at the end of the file.
  Future<int> read(Uint8List buffer, int position, int size) async {
    try {
      final end = math.min(position + size, await length());
      var at = position;
      while (at < end) {
        final index = at ~/ blockSize;
        final block = await _block(index);
        final from = at - index * blockSize;
        final count = math.min(block.length - from, end - at);
        // The server sent less than the length it stated.
        if (count <= 0) break;
        buffer.setRange(at - position, at - position + count, block, from);
        at += count;
      }
      return at - position;
    } on Object catch (error) {
      failure = error;
      rethrow;
    }
  }

  /// The reader is done with the file: what the policy does not let stay
  /// is let go of, and a read that is waiting fails at once.
  void close() {
    if (_closed) return;
    _closed = true;
    _closing.complete();
    _file?.close();
    if (!identical(_memory, MediaReaderBlockMemory.shared)) _memory.clear();
  }

  Future<Uint8List> _block(int index) async {
    if (_closed) throw const MediaReaderFetchException();
    final held = _memory.read(_key, index);
    if (held != null) return held;
    final onDisk = _file?.read(index);
    if (onDisk != null) {
      _keep(index, onDisk, toFile: false);
      return onDisk;
    }
    // The callback returns nothing: a future it returned would be waited
    // for, and the one in the map is this very one.
    return await (_fetching[index] ??= _fetch(index).whenComplete(() {
      unawaited(_fetching.remove(index));
    }));
  }

  Future<Uint8List> _fetch(int index) async {
    final start = index * blockSize;
    Uint8List? whole;
    final part = await _unlessClosed(
      _fetcher
          .fetchRange(_page, (
            start: start,
            end: start + blockSize - 1,
          ), onWhole: (bytes) => whole = bytes)
          .timeout(
            _timeout,
            onTimeout: () => throw MediaReaderFetchException(
              cause: TimeoutException('A range did not come', _timeout),
            ),
          ),
    );
    fetched += whole?.length ?? part.bytes.length;
    if (whole case final whole?) {
      // The server does not serve ranges: it sent all of the file, and
      // all of it is kept, so it is not asked for again.
      _total = whole.length;
      for (var at = 0, i = 0; at < whole.length; at += blockSize, i++) {
        final end = math.min(at + blockSize, whole.length);
        _keep(i, Uint8List.sublistView(whole, at, end));
      }
      return part.bytes;
    }
    // A file shorter than a block needs no stated length.
    _total =
        part.total ??
        (index == 0 && part.bytes.length < blockSize
            ? part.bytes.length
            : null);
    _keep(index, part.bytes);
    return part.bytes;
  }

  /// [work]'s answer, or a failure as soon as the reader is closed:
  /// nobody is left to wait for it.
  Future<T> _unlessClosed<T>(Future<T> work) {
    final done = Completer<T>();
    unawaited(
      work.then(
        (value) {
          if (!done.isCompleted) done.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!done.isCompleted) done.completeError(error, stack);
        },
      ),
    );
    unawaited(
      _closing.future.then((_) {
        if (!done.isCompleted) {
          done.completeError(const MediaReaderFetchException());
        }
      }),
    );
    return done.future;
  }

  set _total(int? total) {
    if (total == null || _closed) return;
    _memory.setTotal(_key, total);
    _file?.total = total;
  }

  void _keep(int index, Uint8List block, {bool toFile = true}) {
    if (_closed) return;
    _memory.write(_key, index, block);
    if (toFile) _file?.write(index, block);
  }
}
