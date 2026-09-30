/// Blocks of files held in memory (MEDIA_READER_PLAN.md R5, MR9): the
/// least recently read is let go of once a budget is passed.
library;

import 'dart:collection';
import 'dart:typed_data';

/// Holds blocks of files up to [maxBytes]. A block that was let go of is
/// fetched again when it is next read.
final class MediaReaderBlockMemory({final int maxBytes = 64 * 1024 * 1024}) {
  /// What the `memory` cache keeps between two showings of a file, for
  /// the whole app.
  static final MediaReaderBlockMemory shared = MediaReaderBlockMemory();

  // In the order they were last read: the first is the eldest.
  final LinkedHashMap<(String, int), Uint8List> _blocks = LinkedHashMap();
  final Map<String, int> _totals = {};
  int _bytes = 0;

  /// How many bytes are held now.
  int get bytes => _bytes;

  /// The length of the file kept under [key], once it is known.
  int? totalOf(String key) => _totals[key];

  void setTotal(String key, int total) => _totals[key] = total;

  /// Block [index] of the file kept under [key], when it is held.
  Uint8List? read(String key, int index) {
    final block = _blocks.remove((key, index));
    if (block != null) _blocks[(key, index)] = block;
    return block;
  }

  /// Holds block [index] of the file kept under [key].
  void write(String key, int index, Uint8List block) {
    _bytes -= _blocks.remove((key, index))?.length ?? 0;
    _blocks[(key, index)] = block;
    _bytes += block.length;
    while (_bytes > maxBytes && _blocks.length > 1) {
      _bytes -= _blocks.remove(_blocks.keys.first)!.length;
    }
  }

  /// Lets go of everything.
  void clear() {
    _blocks.clear();
    _totals.clear();
    _bytes = 0;
  }
}
