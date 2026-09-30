/// The default transport against a real server on this machine's
/// loopback: the test binding's pretend HTTP client is set aside.
library;

import 'dart:io';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late Uri base;
  final seen = <HttpHeaders>[];
  final file = List<int>.generate(500, (i) => i % 256);

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    server.listen((request) async {
      seen.add(request.headers);
      final response = request.response;
      if (request.uri.path == '/gone') {
        response.statusCode = HttpStatus.gone;
      } else if (request.headers.value(HttpHeaders.rangeHeader)
          case final range?) {
        final bounds = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        final start = int.parse(bounds.group(1)!);
        final end = bounds.group(2)!.isEmpty
            ? file.length - 1
            : int.parse(bounds.group(2)!);
        response
          ..statusCode = HttpStatus.partialContent
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${file.length}',
          )
          ..add(file.sublist(start, end + 1));
      } else {
        response
          ..contentLength = file.length
          ..add(file);
      }
      await response.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  Future<List<int>> bodyOf(MediaReaderResponse response) async => [
    for (final chunk in await response.body.toList()) ...chunk,
  ];

  group('MediaReaderIoTransport', () {
    const transport = MediaReaderIoTransport();

    test("GETs the file with the host's headers", () async {
      final response = await transport.get(
        base.resolve('/file'),
        headers: {'authorization': 'Bearer abc'},
      );

      expect(response.status, 200);
      expect(response.length, 500);
      expect(response.total, isNull);
      expect(await bodyOf(response), file);
      expect(seen.last.value('authorization'), 'Bearer abc');
    });

    test('asks for a range, and reads the length of the whole', () async {
      final response = await transport.get(
        base.resolve('/file'),
        range: (start: 100, end: 149),
      );

      expect(response.status, 206);
      expect(response.total, 500);
      expect(await bodyOf(response), file.sublist(100, 150));
      expect(seen.last.value(HttpHeaders.rangeHeader), 'bytes=100-149');
    });

    test('asks to the end of the file with an open range', () async {
      final response = await transport.get(
        base.resolve('/file'),
        range: (start: 450, end: null),
      );

      expect(await bodyOf(response), file.sublist(450));
      expect(seen.last.value(HttpHeaders.rangeHeader), 'bytes=450-');
    });

    test('hands a refusal back as it is', () async {
      final response = await transport.get(base.resolve('/gone'));

      expect(response.status, 410);
      await response.body.drain<void>();
    });
  });
}
