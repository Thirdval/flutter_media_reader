/// A zip archive read from its end (MEDIA_READER_PLAN.md R6): the list
/// of what it holds is at the end of the file, so a large archive is
/// listed after reading a little of it, and an entry is read only when
/// it is opened.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'archive_entry.dart';
import 'read_at.dart';

/// Reads a zip's list of entries, and an entry out of it.
abstract final class MediaReaderZip() {
  static const _endSignature = 0x06054b50;
  static const _end64Locator = 0x07064b50;
  static const _end64Signature = 0x06064b50;
  static const _centralSignature = 0x02014b50;
  static const _localSignature = 0x04034b50;

  /// The entries of the zip at [file]. An entry that cannot be taken out
  /// says [locked] when it is encrypted, [unsupported] when it is packed
  /// a way the reader does not unpack.
  static Future<List<MediaReaderArchiveEntry>> list(
    MediaReaderReadAt file, {
    required String locked,
    required String unsupported,
  }) async {
    final length = await file.length();
    // The end record, and the comment that may follow it.
    final tailStart = length > 65557 ? length - 65557 : 0;
    final tail = await file.read(tailStart, length - tailStart);
    final data = ByteData.sublistView(tail);
    var end = -1;
    for (var at = tail.length - 22; at >= 0; at--) {
      if (data.getUint32(at, Endian.little) == _endSignature) {
        end = at;
        break;
      }
    }
    if (end < 0) throw const MediaReaderArchiveError('No end record');
    int count = data.getUint16(end + 10, Endian.little);
    int size = data.getUint32(end + 12, Endian.little);
    int offset = data.getUint32(end + 16, Endian.little);
    // A large zip keeps the real numbers in a second record before it.
    if (count == 0xFFFF || size == 0xFFFFFFFF || offset == 0xFFFFFFFF) {
      final locator = end - 20;
      if (locator < 0 ||
          data.getUint32(locator, Endian.little) != _end64Locator) {
        throw const MediaReaderArchiveError('No zip64 end record');
      }
      final at = data.getUint64(locator + 8, Endian.little);
      final record = ByteData.sublistView(await file.read(at, 56));
      if (record.lengthInBytes < 56 ||
          record.getUint32(0, Endian.little) != _end64Signature) {
        throw const MediaReaderArchiveError('A bad zip64 end record');
      }
      count = record.getUint64(32, Endian.little);
      size = record.getUint64(40, Endian.little);
      offset = record.getUint64(48, Endian.little);
    }
    final central = await file.read(offset, size);
    if (central.length < size) {
      throw const MediaReaderArchiveError('The list is cut short');
    }
    return _entries(
      central,
      count,
      file,
      locked: locked,
      unsupported: unsupported,
    );
  }

  static List<MediaReaderArchiveEntry> _entries(
    Uint8List central,
    int count,
    MediaReaderReadAt file, {
    required String locked,
    required String unsupported,
  }) {
    final data = ByteData.sublistView(central);
    final entries = <MediaReaderArchiveEntry>[];
    var at = 0;
    for (var i = 0; i < count && at + 46 <= central.length; i++) {
      if (data.getUint32(at, Endian.little) != _centralSignature) break;
      final flags = data.getUint16(at + 8, Endian.little);
      final method = data.getUint16(at + 10, Endian.little);
      var packed = data.getUint32(at + 20, Endian.little);
      var size = data.getUint32(at + 24, Endian.little);
      final nameLength = data.getUint16(at + 28, Endian.little);
      final extraLength = data.getUint16(at + 30, Endian.little);
      final commentLength = data.getUint16(at + 32, Endian.little);
      var local = data.getUint32(at + 42, Endian.little);
      final nameBytes = Uint8List.sublistView(
        central,
        at + 46,
        at + 46 + nameLength,
      );
      // Bit 11 says the name is UTF-8; otherwise it is an old code page,
      // read as Latin-1.
      final name = flags & 0x800 != 0
          ? utf8.decode(nameBytes, allowMalformed: true)
          : latin1.decode(nameBytes);
      // The zip64 extra field holds what did not fit, in this order.
      var extra = at + 46 + nameLength;
      final extraEnd = extra + extraLength;
      while (extra + 4 <= extraEnd) {
        final id = data.getUint16(extra, Endian.little);
        final length = data.getUint16(extra + 2, Endian.little);
        if (id == 0x0001) {
          var field = extra + 4;
          if (size == 0xFFFFFFFF && field + 8 <= extraEnd) {
            size = data.getUint64(field, Endian.little);
            field += 8;
          }
          if (packed == 0xFFFFFFFF && field + 8 <= extraEnd) {
            packed = data.getUint64(field, Endian.little);
            field += 8;
          }
          if (local == 0xFFFFFFFF && field + 8 <= extraEnd) {
            local = data.getUint64(field, Endian.little);
          }
        }
        extra += 4 + length;
      }
      at += 46 + nameLength + extraLength + commentLength;
      final isDirectory = name.endsWith('/');
      final path = isDirectory ? name.substring(0, name.length - 1) : name;
      if (path.isEmpty) continue;
      final encrypted = flags & 0x1 != 0;
      final known = method == 0 || method == 8;
      entries.add(
        MediaReaderArchiveEntry(
          path: path,
          size: size,
          isDirectory: isDirectory,
          unsupported: isDirectory
              ? null
              : encrypted
              ? locked
              : known
              ? null
              : unsupported,
          extract: isDirectory || encrypted || !known
              ? null
              : (limit) => _extract(
                  file,
                  local: local,
                  packed: packed,
                  size: size,
                  deflated: method == 8,
                  limit: limit,
                ),
        ),
      );
    }
    return entries;
  }

  static Future<Uint8List> _extract(
    MediaReaderReadAt file, {
    required int local,
    required int packed,
    required int size,
    required bool deflated,
    required int limit,
  }) async {
    if (size > limit) throw MediaReaderArchiveTooLarge(limit);
    final header = ByteData.sublistView(await file.read(local, 30));
    if (header.lengthInBytes < 30 ||
        header.getUint32(0, Endian.little) != _localSignature) {
      throw const MediaReaderArchiveError('A bad entry header');
    }
    // The local header's own name and extra lengths, which may differ.
    final start =
        local +
        30 +
        header.getUint16(26, Endian.little) +
        header.getUint16(28, Endian.little);
    final bytes = await file.read(start, packed);
    if (bytes.length < packed) {
      throw const MediaReaderArchiveError('An entry is cut short');
    }
    if (!deflated) return bytes;
    return inflateRaw(bytes, limit: limit);
  }
}

/// [bytes] inflated (deflate without a header), never past [limit].
Uint8List inflateRaw(List<int> bytes, {required int limit}) {
  final out = _Counting(limit);
  final input = ZLibDecoder(raw: true).startChunkedConversion(out);
  input
    ..add(bytes)
    ..close();
  return out.bytes.takeBytes();
}

/// Takes what the decoder gives, up to a limit.
final class _Counting(final int _limit) implements Sink<List<int>> {
  final BytesBuilder bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    bytes.add(chunk);
    if (bytes.length > _limit) throw MediaReaderArchiveTooLarge(_limit);
  }

  @override
  void close() {}
}
