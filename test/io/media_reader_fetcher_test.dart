import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  final file = Uint8List.fromList(List.generate(1000, (i) => i % 251));

  /// A page whose remote source the fake host resolves, and the fetcher
  /// over a fake transport that serves [file] at every path.
  ({MediaReaderPage page, FakeResolve host, FakeTransport transport})
  setUpFetch({Map<String, String> headers = const {}}) {
    final host = FakeResolve();
    final page = MediaReaderPage(
      item: item(
        'a.bin',
        source: MediaReaderSource.remote(() async {
          final location = await host.call();
          return MediaReaderLocation(location.uri, headers: headers);
        }),
      ),
    );
    addTearDown(page.dispose);
    final transport = FakeTransport({'/1': file, '/2': file, '/3': file});
    return (page: page, host: host, transport: transport);
  }

  group('MediaReaderFetcher.fetch', () {
    test('brings the file from the location the page keeps', () async {
      final (:page, :host, :transport) = setUpFetch(
        headers: {'authorization': 'Bearer abc'},
      );

      final bytes = await MediaReaderFetcher(transport).fetch(page);

      expect(bytes, file);
      expect(host.calls, 1);
      expect(transport.requests.single.uri, Uri.parse('https://files.test/1'));
      expect(transport.requests.single.headers, {
        'authorization': 'Bearer abc',
      });
      expect(transport.requests.single.range, isNull);
    });

    test('reports how much has come', () async {
      final (:page, host: _, :transport) = setUpFetch();
      final progress = <(int, int?)>[];

      await MediaReaderFetcher(transport).fetch(
        page,
        onProgress: (received, total) => progress.add((received, total)),
      );

      expect(progress.last, (1000, 1000));
    });

    for (final status in [401, 403, 410]) {
      test('asks for a fresh location when the kept one is refused '
          'with $status', () async {
        final (:page, :host, :transport) = setUpFetch();
        transport.status = (uri) => uri.path == '/1' ? status : null;

        final bytes = await MediaReaderFetcher(transport).fetch(page);

        expect(bytes, file);
        expect(host.calls, 2);
        expect(transport.requests.map((request) => request.uri.path), [
          '/1',
          '/2',
        ]);
      });
    }

    test('gives up when the fresh location is refused too', () async {
      final (:page, :host, :transport) = setUpFetch();
      transport.status = (_) => 410;

      await expectLater(
        MediaReaderFetcher(transport).fetch(page),
        throwsA(
          isA<MediaReaderFetchException>()
              .having((e) => e.status, 'status', 410)
              .having((e) => e.refused, 'refused', isTrue),
        ),
      );
      expect(host.calls, 2);
    });

    test('does not ask again for a file that is not there', () async {
      final (:page, :host, :transport) = setUpFetch();
      transport.status = (_) => 404;

      await expectLater(
        MediaReaderFetcher(transport).fetch(page),
        throwsA(
          isA<MediaReaderFetchException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.refused, 'refused', isFalse),
        ),
      );
      expect(host.calls, 1);
    });

    test('says when the server was never reached', () async {
      final (:page, host: _, :transport) = setUpFetch();
      transport.failure = const SocketException('offline');

      await expectLater(
        MediaReaderFetcher(transport).fetch(page),
        throwsA(
          isA<MediaReaderFetchException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.cause, 'cause', isA<SocketException>()),
        ),
      );
    });

    test('stops at the limit', () async {
      final (:page, host: _, :transport) = setUpFetch();

      await expectLater(
        MediaReaderFetcher(transport).fetch(page, limit: 999),
        throwsA(isA<MediaReaderTooLarge>()),
      );
      expect(
        await MediaReaderFetcher(transport).fetch(page, limit: 1000),
        file,
      );
    });

    test("lets the host's own failure through", () async {
      final (:page, :host, :transport) = setUpFetch();
      host.failure = const MediaReaderUnavailable('Removed by a moderator.');

      await expectLater(
        MediaReaderFetcher(transport).fetch(page),
        throwsA(isA<MediaReaderUnavailable>()),
      );
      expect(page.failure.value, 'Removed by a moderator.');
      expect(transport.requests, isEmpty);
    });
  });

  group('MediaReaderFetcher.fetchRange', () {
    test('brings the bytes asked for, and the length of the whole', () async {
      final (:page, host: _, :transport) = setUpFetch();

      final part = await MediaReaderFetcher(transport)
          .fetchRange(page, (start: 100, end: 199));

      expect(part.bytes, file.sublist(100, 200));
      expect(part.total, 1000);
      expect(transport.requests.single.range, (start: 100, end: 199));
    });

    test('reads to the end when the range is open', () async {
      final (:page, host: _, :transport) = setUpFetch();

      final part = await MediaReaderFetcher(transport)
          .fetchRange(page, (start: 900, end: null));

      expect(part.bytes, file.sublist(900));
    });

    test('cuts the range out when the server sends the whole file', () async {
      final (:page, host: _, :transport) = setUpFetch();
      transport.ranges = false;

      final part = await MediaReaderFetcher(transport)
          .fetchRange(page, (start: 100, end: 199));

      expect(part.bytes, file.sublist(100, 200));
      expect(part.total, 1000);
    });

    test('renews a refused location as a whole fetch does', () async {
      final (:page, :host, :transport) = setUpFetch();
      transport.status = (uri) => uri.path == '/1' ? 410 : null;

      final part = await MediaReaderFetcher(transport)
          .fetchRange(page, (start: 0, end: 9));

      expect(part.bytes, file.sublist(0, 10));
      expect(host.calls, 2);
    });
  });
}
