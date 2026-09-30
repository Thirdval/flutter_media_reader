/// Opening an archive by what it is (MEDIA_READER_PLAN.md R6): a zip
/// from its end, a tar from its headers, a gzip whole.
library;

import 'dart:io';
import 'dart:typed_data';

import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../shell/media_reader_page.dart';
import 'archive_entry.dart';
import 'read_at.dart';
import 'tar_reader.dart';
import 'zip_reader.dart';

/// An archive that is open: its entries, and what reads it.
final class MediaReaderOpenArchive(
  final List<MediaReaderArchiveEntry> entries,
  final MediaReaderReadAt? _file,
) {
  /// How many files it holds, in all of its folders.
  int get fileCount => entries.where((entry) => !entry.isDirectory).length;

  /// What is in [folder]: its folders, then its files, each in order of
  /// name. A folder no entry names, but paths run through, is there too.
  List<MediaReaderArchiveEntry> inFolder(String folder) {
    final prefix = folder.isEmpty ? '' : '$folder/';
    final folders = <String, MediaReaderArchiveEntry>{};
    final files = <MediaReaderArchiveEntry>[];
    for (final entry in entries) {
      if (!entry.path.startsWith(prefix)) continue;
      final rest = entry.path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash < 0 && !entry.isDirectory) {
        files.add(entry);
      } else {
        final name = slash < 0 ? rest : rest.substring(0, slash);
        folders.putIfAbsent(
          name,
          () => MediaReaderArchiveEntry(
            path: '$prefix$name',
            size: 0,
            isDirectory: true,
          ),
        );
      }
    }
    int byName(MediaReaderArchiveEntry a, MediaReaderArchiveEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return [...folders.values.toList()..sort(byName), ...files..sort(byName)];
  }

  void close() => _file?.close();
}

/// Opens [item] for [page]. A gzip stream is read whole, up to
/// [maxBytes]; a zip and a tar are read where they are.
Future<MediaReaderOpenArchive> openMediaReaderArchive({
  required MediaReaderItem item,
  required MediaReaderPage page,
  required MediaReaderFetcher fetcher,
  required int blockSize,
  required int maxBytes,
}) async {
  final strings = page.chrome.strings;
  final file = MediaReaderReadAt.of(
    item,
    page,
    fetcher: fetcher,
    blockSize: blockSize,
  );
  try {
    switch (item.format) {
      case 'zip':
        return MediaReaderOpenArchive(
          await MediaReaderZip.list(
            file,
            locked: strings.locked,
            unsupported: strings.notShown,
          ),
          file,
        );
      case 'tar':
        return MediaReaderOpenArchive(await MediaReaderTar.list(file), file);
      case 'gz':
        final length = await file.length();
        if (length > maxBytes) throw MediaReaderArchiveTooLarge(maxBytes);
        final inner = gunzip(await file.read(0, length), limit: maxBytes);
        file.close();
        final name = item.name.toLowerCase();
        // A tar inside: by the name, or by the mark a tar carries.
        final tar =
            name.endsWith('.tar.gz') ||
            name.endsWith('.tgz') ||
            (inner.length > 262 &&
                String.fromCharCodes(inner, 257, 262) == 'ustar');
        if (tar) {
          return MediaReaderOpenArchive(
            await MediaReaderTar.list(MediaReaderBytesAt(inner)),
            null,
          );
        }
        // One file, named as the archive is without its ending.
        final dot = item.name.lastIndexOf('.');
        final innerName = name.endsWith('.gz') && dot > 0
            ? item.name.substring(0, dot)
            : item.name;
        return MediaReaderOpenArchive([
          MediaReaderArchiveEntry(
            path: innerName,
            size: inner.length,
            extract: (limit) async => inner,
          ),
        ], null);
      default:
        throw MediaReaderArchiveError('Not an archive: ${item.format}');
    }
  } on Object {
    file.close();
    rethrow;
  }
}

/// [bytes] gunzipped, never past [limit].
Uint8List gunzip(List<int> bytes, {required int limit}) {
  final out = BytesBuilder(copy: false);
  final input = gzip.decoder.startChunkedConversion(_Counting(out, limit));
  try {
    input
      ..add(bytes)
      ..close();
  } on FormatException catch (error) {
    throw MediaReaderArchiveError(error.message);
  }
  return out.takeBytes();
}

/// Takes what the decoder gives, up to a limit.
final class _Counting(final BytesBuilder _out, final int _limit)
    implements Sink<List<int>> {
  @override
  void add(List<int> chunk) {
    _out.add(chunk);
    if (_out.length > _limit) throw MediaReaderArchiveTooLarge(_limit);
  }

  @override
  void close() {}
}
