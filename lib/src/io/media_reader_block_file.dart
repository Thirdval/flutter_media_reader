/// Blocks of a file kept in the host's cache directory
/// (MEDIA_READER_PLAN.md R5, MR9): the only place on disk the reader
/// writes to.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The blocks of the file [id], in two files under [directory]: the
/// blocks at their places in the file, and a note of which are there.
///
/// A disk that cannot be written to, or a note that cannot be read, is
/// not an error: the blocks are then simply not kept.
final class MediaReaderBlockFile({
  required final String directory,
  required final String id,
  required final int blockSize,
}) {
  late final String _path = '$directory/${nameOf(id)}';
  final Set<int> _have = {};
  RandomAccessFile? _blocks;
  int? _total;
  bool _opened = false;
  bool _broken = false;

  /// A file name for [id] that is safe on every platform, and its own
  /// for every id: what is safe of the id, and a hash of all of it.
  static String nameOf(String id) {
    // FNV-1a, 64 bits.
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(id)) {
      hash = (hash ^ byte) * 0x100000001b3;
    }
    String hex(int half) => half.toRadixString(16).padLeft(8, '0');
    final safe = id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    final head = safe.length > 40 ? safe.substring(0, 40) : safe;
    return '$head-${hex(hash >>> 32)}${hex(hash & 0xFFFFFFFF)}';
  }

  /// The file's length, when it was noted.
  int? get total {
    _open();
    return _total;
  }

  set total(int? total) {
    _open();
    if (total == null || total == _total) return;
    // The file under this id has changed: what was kept is another's.
    if (_total != null) _have.clear();
    _total = total;
    _note();
  }

  /// Block [index], when it is kept and whole.
  Uint8List? read(int index) {
    _open();
    final total = _total;
    if (_broken || total == null || !_have.contains(index)) return null;
    final start = index * blockSize;
    final length = (total - start).clamp(0, blockSize);
    try {
      final file = _blocks!..setPositionSync(start);
      final block = file.readSync(length);
      return block.length == length ? block : null;
    } on FileSystemException {
      _broken = true;
      return null;
    }
  }

  /// Keeps block [index].
  void write(int index, Uint8List block) {
    _open();
    if (_broken || _have.contains(index)) return;
    try {
      _blocks!
        ..setPositionSync(index * blockSize)
        ..writeFromSync(block);
      _have.add(index);
      _note();
    } on FileSystemException {
      _broken = true;
    }
  }

  void close() {
    try {
      _blocks?.closeSync();
    } on FileSystemException {
      // Nothing to let go of.
    }
    _blocks = null;
    _opened = false;
  }

  /// Opens the two files, taking up what an earlier showing kept.
  void _open() {
    if (_opened || _broken) return;
    _opened = true;
    try {
      Directory(directory).createSync(recursive: true);
      final note = File('$_path.json');
      if (note.existsSync()) _readNote(note.readAsStringSync());
      // Reading and writing anywhere in the file, without emptying it.
      _blocks = File('$_path.blocks').openSync(mode: FileMode.append);
    } on FileSystemException {
      _broken = true;
    }
  }

  void _readNote(String text) {
    try {
      final Object? note = jsonDecode(text);
      if (note
          case {
            'blockSize': final int size,
            'total': final int total,
            'have': final List<Object?> have,
          }
          when size == blockSize) {
        _total = total;
        _have.addAll(have.whereType<int>());
      }
    } on FormatException {
      // A note cut short: nothing is taken as kept.
    }
  }

  void _note() {
    if (_broken) return;
    try {
      File('$_path.json').writeAsStringSync(
        jsonEncode({
          'blockSize': blockSize,
          'total': _total,
          'have': _have.toList(),
        }),
      );
    } on FileSystemException {
      _broken = true;
    }
  }
}
