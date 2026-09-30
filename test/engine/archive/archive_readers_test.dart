import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/engine/archive/archive_entry.dart';
import 'package:flutter_media_reader/src/engine/archive/archive_open.dart';
import 'package:flutter_media_reader/src/engine/archive/read_at.dart';
import 'package:flutter_media_reader/src/engine/archive/tar_reader.dart';
import 'package:flutter_media_reader/src/engine/archive/zip_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/archives.dart';
import '../../support/fakes.dart';

void main() {
  final notes = utf8.encode('The rota for October.\n');
  final noise = Uint8List.fromList(
    List.generate(300 * 1024, (i) => Random(7).nextInt(256)),
  );

  Future<List<MediaReaderArchiveEntry>> zipEntries(Uint8List zip) =>
      MediaReaderZip.list(
        MediaReaderBytesAt(zip),
        locked: 'locked',
        unsupported: 'unsupported',
      );

  Map<String, ({int size, bool dir})> shape(List<MediaReaderArchiveEntry> e) =>
      {
        for (final entry in e)
          entry.path: (size: entry.size, dir: entry.isDirectory),
      };

  group('MediaReaderZip', () {
    test('lists the files and folders, with their sizes', () async {
      final entries = await zipEntries(
        zipOf(
          {'notes.txt': notes, 'photos/hall.bin': noise},
          folders: ['photos', 'empty'],
        ),
      );

      expect(shape(entries), {
        'photos': (size: 0, dir: true),
        'empty': (size: 0, dir: true),
        'notes.txt': (size: notes.length, dir: false),
        'photos/hall.bin': (size: noise.length, dir: false),
      });
    });

    for (final stored in [false, true]) {
      test('takes an entry out, ${stored ? 'stored' : 'deflated'}', () async {
        final entries = await zipEntries(
          zipOf({'notes.txt': notes, 'hall.bin': noise}, stored: stored),
        );

        final text = await entries[0].extract!(1024 * 1024);
        final bytes = await entries[1].extract!(1024 * 1024);

        expect(utf8.decode(text), 'The rota for October.\n');
        expect(bytes, noise);
      });
    }

    test('will not take out more than the limit', () async {
      final entries = await zipEntries(zipOf({'hall.bin': noise}));

      await expectLater(
        entries.single.extract!(1000),
        throwsA(isA<MediaReaderArchiveTooLarge>()),
      );
    });

    test('says an encrypted entry is locked', () async {
      final entries = await zipEntries(
        zipOf({'secret.txt': notes}, password: 'harvest'),
      );

      expect(entries.single.unsupported, 'locked');
      expect(entries.single.extract, isNull);
    });

    test('is not misled by what is not a zip', () async {
      await expectLater(
        zipEntries(Uint8List.fromList(utf8.encode('not a zip at all'))),
        throwsA(isA<MediaReaderArchiveError>()),
      );
    });

    test(
      'reads a remote zip from its end, and only the entry opened',
      () async {
        final zip = zipOf({'hall.bin': noise, 'notes.txt': notes});
        final host = FakeResolve();
        final transport = FakeTransport({'/1': zip});
        final page = MediaReaderPage(
          item: item('a.zip', source: MediaReaderSource.remote(host.call)),
        );
        addTearDown(page.dispose);
        final file = MediaReaderReadAt.of(
          page.item,
          page,
          fetcher: MediaReaderFetcher(transport),
          blockSize: 16 * 1024,
        );

        final entries = await MediaReaderZip.list(
          file,
          locked: 'locked',
          unsupported: 'unsupported',
        );
        final listed = transport.requests.length;
        final text = await entries
            .singleWhere((entry) => entry.path == 'notes.txt')
            .extract!(1024);
        file.close();

        expect(utf8.decode(text), 'The rota for October.\n');
        // The list from the end, the small entry near it: a few ranges of
        // the twenty the file has.
        expect(listed, lessThan(4));
        expect(transport.requests.length, lessThan(6));
        expect(host.calls, 1);
      },
    );
  });

  group('MediaReaderTar', () {
    test('lists the files and folders, and takes an entry out', () async {
      final tar = tarOf(
        {'notes.txt': notes, 'photos/hall.bin': noise},
        folders: ['photos'],
      );

      final entries = await MediaReaderTar.list(MediaReaderBytesAt(tar));

      expect(shape(entries), {
        'photos': (size: 0, dir: true),
        'notes.txt': (size: notes.length, dir: false),
        'photos/hall.bin': (size: noise.length, dir: false),
      });
      expect(await entries[1].extract!(1024), notes);
      expect(await entries[2].extract!(1024 * 1024), noise);
    });

    test('reads a long path', () async {
      final path = '${'a' * 60}/${'b' * 60}/${'c' * 60}.txt';

      final entries = await MediaReaderTar.list(
        MediaReaderBytesAt(tarOf({path: notes})),
      );

      expect(entries.single.path, path);
    });

    test('reads the headers of a remote tar, and not the data', () async {
      final tar = tarOf({'hall.bin': noise, 'notes.txt': notes});
      final transport = FakeTransport({'/1': tar});
      final page = MediaReaderPage(
        item: item(
          'a.tar',
          source: MediaReaderSource.remote(FakeResolve().call),
        ),
      );
      addTearDown(page.dispose);
      final file = MediaReaderReadAt.of(
        page.item,
        page,
        fetcher: MediaReaderFetcher(transport),
        blockSize: 16 * 1024,
      );

      final entries = await MediaReaderTar.list(file);
      file.close();

      expect(entries.map((entry) => entry.path), ['hall.bin', 'notes.txt']);
      // The first header, the one after the noise: not the noise.
      expect(transport.requests.length, lessThan(4));
    });
  });

  group('openMediaReaderArchive', () {
    Future<MediaReaderOpenArchive> open(String name, Uint8List bytes) async {
      final page = MediaReaderPage(
        item: item(name, source: MediaReaderSource.bytes(bytes)),
      );
      addTearDown(page.dispose);
      return await openMediaReaderArchive(
        item: page.item,
        page: page,
        fetcher: const MediaReaderFetcher(),
        blockSize: 16 * 1024,
        maxBytes: 1024 * 1024,
      );
    }

    test('a gzip file is the one file in it', () async {
      final archive = await open('notes.txt.gz', gzipOf(notes));

      expect(archive.entries.single.path, 'notes.txt');
      expect(await archive.entries.single.extract!(1024), notes);
      expect(archive.fileCount, 1);
    });

    test('a gzipped tar is its files', () async {
      final archive = await open(
        'rota.tar.gz',
        gzipOf(tarOf({'notes.txt': notes, 'more/x.txt': notes})),
      );

      expect(archive.entries.map((entry) => entry.path), [
        'notes.txt',
        'more/x.txt',
      ]);
    });

    test(
      'shows the folders of each folder, and its files after them',
      () async {
        final archive = await open(
          'a.zip',
          zipOf({
            'z.txt': notes,
            'b/y.txt': notes,
            'b/c/x.txt': notes,
            'a.txt': notes,
          }),
        );

        expect(archive.inFolder('').map((entry) => entry.name), [
          'b',
          'a.txt',
          'z.txt',
        ]);
        expect(archive.inFolder('b').map((entry) => entry.name), [
          'c',
          'y.txt',
        ]);
        expect(archive.inFolder('b/c').map((entry) => entry.name), ['x.txt']);
        expect(archive.fileCount, 4);
      },
    );

    test('what is not gzip says so', () async {
      await expectLater(
        open('notes.txt.gz', Uint8List.fromList(notes)),
        throwsA(isA<MediaReaderArchiveError>()),
      );
    });
  });
}
