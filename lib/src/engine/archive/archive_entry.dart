/// What an archive holds (MEDIA_READER_PLAN.md R6): its entries, and a
/// way to take one out.
library;

import 'dart:typed_data';

/// One file, or one folder, in an archive.
class const MediaReaderArchiveEntry({
  /// The entry's path in the archive, with `/` between its parts and no
  /// `/` at its end.
  required final String path,

  /// The file's size when taken out, in bytes; 0 for a folder.
  required final int size,
  final bool isDirectory = false,

  /// Why the entry cannot be taken out, when it cannot: it is encrypted,
  /// or packed a way the reader does not unpack. Null when it can.
  final String? unsupported,

  /// Takes the file out, up to [limit] bytes. Throws
  /// [MediaReaderArchiveTooLarge] past that, and [MediaReaderArchiveError]
  /// when the archive is not what it says.
  final Future<Uint8List> Function(int limit)? extract,
}) {
  /// The last part of [path]: the file's own name.
  String get name => path.substring(path.lastIndexOf('/') + 1);

  /// The folder the entry is in: empty at the top, else with no `/` at
  /// its end.
  String get folder {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }
}

/// An archive that is not what it says it is.
class const MediaReaderArchiveError(final String message) implements Exception {
  @override
  String toString() => 'MediaReaderArchiveError: $message';
}

/// An entry larger than the reader takes out.
class const MediaReaderArchiveTooLarge(final int limit) implements Exception {
  @override
  String toString() => 'MediaReaderArchiveTooLarge(limit: $limit bytes)';
}
