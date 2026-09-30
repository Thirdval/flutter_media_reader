import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/io/media_reader_block_file.dart';
import 'package:flutter_media_reader/src/io/media_reader_block_memory.dart';
import 'package:flutter_media_reader/src/io/media_reader_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  // Two and a half blocks of 100 bytes.
  final file = Uint8List.fromList(List.generate(250, (i) => i % 251));

  late FakeResolve host;
  late FakeTransport transport;
  setUp(() {
    host = FakeResolve();
    transport = FakeTransport({'/1': file, '/2': file, '/3': file});
    MediaReaderBlockMemory.shared.clear();
  });

  MediaReaderPage pageOf(MediaReaderPolicy policy) {
    final page = MediaReaderPage(
      item: item('a.pdf', source: MediaReaderSource.remote(host.call)),
      policy: policy,
    );
    addTearDown(page.dispose);
    return page;
  }

  /// A reader of `a.pdf` by blocks of 100 bytes, under [cache].
  MediaReaderBlockReader reader({
    MediaReaderCache cache = const MediaReaderCache.none(),
    bool canExport = true,
  }) {
    final reader = MediaReaderBlockReader(
      page: pageOf(MediaReaderPolicy(canExport: canExport, cache: cache)),
      id: 'a.pdf',
      fetcher: MediaReaderFetcher(transport),
      blockSize: 100,
    );
    addTearDown(reader.close);
    return reader;
  }

  /// The ranges asked of the server, in order.
  List<(int, int?)> ranges() => [
    for (final request in transport.requests)
      (request.range!.start, request.range!.end),
  ];

  Future<Uint8List> readAt(
    MediaReaderBlockReader reader,
    int position,
    int size,
  ) async {
    final buffer = Uint8List(size);
    final count = await reader.read(buffer, position, size);
    return Uint8List.sublistView(buffer, 0, count);
  }

  group('MediaReaderBlockReader', () {
    test('learns the length with the first block', () async {
      final blocks = reader();

      expect(await blocks.length(), 250);
      expect(ranges(), [(0, 99)]);
      expect(host.calls, 1);
    });

    test('reads across blocks, fetching each one once', () async {
      final blocks = reader();

      expect(await readAt(blocks, 90, 120), file.sublist(90, 210));
      expect(await readAt(blocks, 95, 10), file.sublist(95, 105));

      expect(ranges(), [(0, 99), (100, 199), (200, 299)]);
      expect(blocks.fetched, 250);
      expect(host.calls, 1);
    });

    test('reads the end first, as a PDF is read', () async {
      final blocks = reader();

      expect(await readAt(blocks, 240, 10), file.sublist(240));

      // The first block for the length, then the block asked for.
      expect(ranges(), [(0, 99), (200, 299)]);
    });

    test('a read past the end comes back short', () async {
      final blocks = reader();

      expect(await readAt(blocks, 240, 50), file.sublist(240));
      expect(await readAt(blocks, 400, 10), isEmpty);
    });

    test('two reads of a block on its way ask for it once', () async {
      final blocks = reader();

      final both = await Future.wait([
        readAt(blocks, 0, 10),
        readAt(blocks, 50, 10),
      ]);

      expect(both, [file.sublist(0, 10), file.sublist(50, 60)]);
      expect(transport.requests, hasLength(1));
    });

    test('a file shorter than a block needs no stated length', () async {
      transport = FakeTransport({'/1': file.sublist(0, 40)})..ranges = false;
      final blocks = reader();

      expect(await blocks.length(), 40);
      expect(await readAt(blocks, 30, 20), file.sublist(30, 40));
    });

    test('a server without ranges is asked for the file once', () async {
      transport.ranges = false;
      final blocks = reader();

      expect(await readAt(blocks, 240, 10), file.sublist(240));
      expect(await readAt(blocks, 120, 30), file.sublist(120, 150));

      expect(transport.requests, hasLength(1));
      expect(blocks.fetched, 250);
    });

    test('a location that is refused is renewed', () async {
      transport.status = (uri) => uri.path == '/1' ? 410 : null;
      final blocks = reader();

      expect(await readAt(blocks, 0, 10), file.sublist(0, 10));

      expect(host.calls, 2);
      expect(transport.requests.map((request) => request.uri.path), [
        '/1',
        '/2',
      ]);
    });

    test('a range that stalls is given up on', () async {
      final stalled = Completer<void>();
      transport.hold = (uri, range) => stalled.future;
      final blocks = MediaReaderBlockReader(
        page: pageOf(const MediaReaderPolicy()),
        id: 'a.pdf',
        fetcher: MediaReaderFetcher(transport),
        blockSize: 100,
        timeout: const Duration(milliseconds: 50),
      );
      addTearDown(blocks.close);

      await expectLater(
        blocks.read(Uint8List(10), 0, 10),
        throwsA(
          isA<MediaReaderFetchException>().having(
            (error) => error.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );
      stalled.complete();
    });

    test('closing fails a read that is waiting, at once', () async {
      final stalled = Completer<void>();
      transport.hold = (uri, range) => stalled.future;
      final blocks = reader();
      final reading = blocks.read(Uint8List(10), 0, 10);

      blocks.close();

      await expectLater(reading, throwsA(isA<MediaReaderFetchException>()));
      // And nothing is read after it.
      await expectLater(
        blocks.read(Uint8List(10), 0, 10),
        throwsA(isA<MediaReaderFetchException>()),
      );
      stalled.complete();
    });

    test('a block that does not come fails the read, and says why', () async {
      final blocks = reader();
      await blocks.length();
      transport.failure = const SocketException('No route to host');

      await expectLater(
        blocks.read(Uint8List(10), 150, 10),
        throwsA(isA<MediaReaderFetchException>()),
      );

      expect(blocks.failure, isA<MediaReaderFetchException>());
    });
  });

  group('where the blocks stay', () {
    test('with no cache, a closed file is fetched again', () async {
      final first = reader();
      await readAt(first, 0, 250);
      first.close();
      transport.requests.clear();

      await readAt(reader(), 0, 250);

      expect(transport.requests, hasLength(3));
      expect(MediaReaderBlockMemory.shared.bytes, 0);
    });

    test('in memory, a second showing fetches nothing', () async {
      const cache = MediaReaderCache.memory();
      final first = reader(cache: cache);
      await readAt(first, 0, 250);
      first.close();
      transport.requests.clear();

      final again = reader(cache: cache);
      expect(await again.length(), 250);
      expect(await readAt(again, 0, 250), file);

      expect(transport.requests, isEmpty);
      expect(again.fetched, 0);
    });

    test('the host lets go of what is in memory, as on a sign-out', () async {
      const cache = MediaReaderCache.memory();
      final first = reader(cache: cache);
      await readAt(first, 0, 250);
      first.close();
      expect(MediaReaderBlockMemory.shared.bytes, 250);

      MediaReaderCache.clearMemory();

      expect(MediaReaderBlockMemory.shared.bytes, 0);
      transport.requests.clear();
      await readAt(reader(cache: cache), 0, 250);
      expect(transport.requests, hasLength(3));
    });

    test('in a directory, a second showing reads from it', () async {
      final directory = Directory.systemTemp.createTempSync('blocks_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final cache = MediaReaderCache.directory(directory.path);
      final first = reader(cache: cache);
      await readAt(first, 0, 150);
      first.close();
      transport.requests.clear();

      final again = reader(cache: cache);
      expect(await again.length(), 250);
      expect(await readAt(again, 0, 150), file.sublist(0, 150));
      expect(transport.requests, isEmpty);

      // What was not kept is fetched, and kept in its turn.
      expect(await readAt(again, 200, 50), file.sublist(200));
      expect(ranges(), [(200, 299)]);

      final name = MediaReaderBlockFile.nameOf('a.pdf');
      expect(
        directory.listSync().map((entry) => entry.uri.pathSegments.last),
        unorderedEquals(['$name.blocks', '$name.json']),
      );
    });

    test('with export off, nothing is written to the directory', () async {
      final directory = Directory.systemTemp.createTempSync('blocks_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final blocks = reader(
        cache: MediaReaderCache.directory(directory.path),
        canExport: false,
      );

      await readAt(blocks, 0, 250);
      blocks.close();

      expect(directory.listSync(), isEmpty);
    });
  });

  group('MediaReaderBlockFile', () {
    late Directory directory;
    setUp(() {
      directory = Directory.systemTemp.createTempSync('blocks_');
      addTearDown(() => directory.deleteSync(recursive: true));
    });

    MediaReaderBlockFile open({int blockSize = 100}) {
      final kept = MediaReaderBlockFile(
        directory: directory.path,
        id: 'file/1?x',
        blockSize: blockSize,
      );
      addTearDown(kept.close);
      return kept;
    }

    test('keeps blocks at their places, and gives them back', () {
      final kept = open()..total = 250;

      kept
        ..write(2, file.sublist(200))
        ..write(0, file.sublist(0, 100));

      expect(kept.read(0), file.sublist(0, 100));
      expect(kept.read(1), isNull);
      expect(kept.read(2), file.sublist(200));
    });

    test('gives a name that is safe, and its own for each id', () {
      final name = MediaReaderBlockFile.nameOf('file/1?x');

      expect(name, matches(RegExp(r'^file1x-[0-9a-f]{16}$')));
      expect(MediaReaderBlockFile.nameOf('file/1?y'), isNot(name));
      expect(MediaReaderBlockFile.nameOf('file1x'), isNot(name));
      expect(
        MediaReaderBlockFile.nameOf('x' * 300).length,
        lessThanOrEqualTo(60),
      );
    });

    test('a file of another length under the same id starts afresh', () {
      open()
        ..total = 250
        ..write(0, file.sublist(0, 100))
        ..close();

      final again = open()..total = 300;

      expect(again.read(0), isNull);
    });

    test('blocks of another size are not taken as kept', () {
      open()
        ..total = 250
        ..write(0, file.sublist(0, 100))
        ..close();

      final again = open(blockSize: 50);

      expect(again.total, isNull);
      expect(again.read(0), isNull);
    });

    test('a note that cannot be read is nothing kept', () {
      final name = MediaReaderBlockFile.nameOf('file/1?x');
      File('${directory.path}/$name.json').writeAsStringSync('{"total": 2');

      final kept = open();

      expect(kept.total, isNull);
      expect(kept.read(0), isNull);
    });

    test('a directory that cannot be written to keeps nothing, and fails '
        'nothing', () {
      // A file stands where the directory should be.
      final blocked = File('${directory.path}/blocked')..writeAsStringSync('');
      final kept = MediaReaderBlockFile(
        directory: blocked.path,
        id: 'a',
        blockSize: 100,
      );

      kept
        ..total = 250
        ..write(0, file.sublist(0, 100));

      expect(kept.read(0), isNull);
      kept.close();
    });
  });

  group('MediaReaderBlockMemory', () {
    test('lets go of the block read longest ago, past its budget', () {
      final memory = MediaReaderBlockMemory(maxBytes: 250);
      final block = Uint8List(100);
      memory
        ..write('a', 0, block)
        ..write('a', 1, block);
      // The first is read again: the second is now the eldest.
      memory.read('a', 0);

      memory.write('b', 0, block);

      expect(memory.read('a', 1), isNull);
      expect(memory.read('a', 0), isNotNull);
      expect(memory.read('b', 0), isNotNull);
      expect(memory.bytes, 200);
    });

    test('holds a block larger than its budget while it is the only one', () {
      final memory = MediaReaderBlockMemory(maxBytes: 10)
        ..write('a', 0, Uint8List(100));

      expect(memory.read('a', 0), isNotNull);
    });
  });
}
