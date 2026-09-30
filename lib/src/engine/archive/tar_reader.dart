/// A tar archive read header by header (MEDIA_READER_PLAN.md R6): each
/// entry says how long it is, so the data between the headers is never
/// read to make the list.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'archive_entry.dart';
import 'read_at.dart';

/// Reads a tar's list of entries, and an entry out of it.
abstract final class MediaReaderTar() {
  static const _block = 512;

  /// The entries of the tar at [file].
  static Future<List<MediaReaderArchiveEntry>> list(
    MediaReaderReadAt file,
  ) async {
    final length = await file.length();
    final entries = <MediaReaderArchiveEntry>[];
    String? longName;
    var at = 0;
    while (at + _block <= length) {
      final header = await file.read(at, _block);
      if (header.length < _block || header.every((byte) => byte == 0)) break;
      final size = _octal(header, 124, 12);
      final type = header[156];
      final data = at + _block;
      at = data + (size + _block - 1) ~/ _block * _block;
      switch (type) {
        // A GNU long name: the next entry's name is this entry's data.
        case 0x4C:
          longName = _string(await file.read(data, size), 0, size);
          continue;
        // A pax header: it may carry the path.
        case 0x78:
          final text = _string(await file.read(data, size), 0, size);
          for (final record in text.split('\n')) {
            final space = record.indexOf(' ');
            final equals = record.indexOf('=');
            if (space < 0 || equals < space) continue;
            if (record.substring(space + 1, equals) == 'path') {
              longName = record.substring(equals + 1);
            }
          }
          continue;
        // Global pax headers and the like say nothing about a file.
        case 0x67:
          continue;
      }
      var name = longName ?? _string(header, 0, 100);
      longName = null;
      // A ustar header may keep the start of a long path apart.
      if (_string(header, 257, 5) == 'ustar') {
        final prefix = _string(header, 345, 155);
        if (prefix.isNotEmpty) name = '$prefix/$name';
      }
      final isDirectory = type == 0x35 || name.endsWith('/');
      final path = name.endsWith('/')
          ? name.substring(0, name.length - 1)
          : name;
      if (path.isEmpty) continue;
      // A plain file, or an old tar's file with no type.
      final isFile = type == 0x30 || type == 0;
      if (!isDirectory && !isFile) continue;
      entries.add(
        MediaReaderArchiveEntry(
          path: path,
          size: isDirectory ? 0 : size,
          isDirectory: isDirectory,
          extract: isDirectory
              ? null
              : (limit) async {
                  if (size > limit) throw MediaReaderArchiveTooLarge(limit);
                  final bytes = await file.read(data, size);
                  if (bytes.length < size) {
                    throw const MediaReaderArchiveError(
                      'An entry is cut short',
                    );
                  }
                  return bytes;
                },
        ),
      );
    }
    return entries;
  }

  /// A number written in octal, ended by a space or a nul.
  static int _octal(Uint8List header, int at, int length) {
    final end = at + length;
    var i = at;
    while (i < end && (header[i] == 0x20 || header[i] == 0)) {
      i++;
    }
    var value = 0;
    while (i < end && header[i] >= 0x30 && header[i] <= 0x37) {
      value = value * 8 + (header[i] - 0x30);
      i++;
    }
    return value;
  }

  /// A string ended by a nul, or by the field's end.
  static String _string(Uint8List bytes, int at, int length) {
    var end = at;
    while (end < at + length && end < bytes.length && bytes[end] != 0) {
      end++;
    }
    return utf8.decode(bytes.sublist(at, end), allowMalformed: true);
  }
}
