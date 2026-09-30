import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/io/media_reader_block_file.dart';
import 'package:flutter_media_reader/src/io/media_reader_block_memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../support/fakes.dart';
import '../support/pdf.dart';

void main() {
  late Directory pdfrxKeeps;
  setUpAll(() => pdfrxKeeps = setUpPdfium());
  setUp(MediaReaderBlockMemory.shared.clear);

  MediaReaderItem pdf(String id, MediaReaderSource source) =>
      MediaReaderItem(id: id, name: '$id.pdf', source: source);

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  /// The reader, with the PDF engine reading through [transport] by
  /// blocks of 64 KB.
  Future<void> pumpPdfReader(
    WidgetTester tester,
    List<MediaReaderItem> items, {
    FakeTransport? transport,
    MediaReaderPdfPassword? password,
    MediaReaderPolicy policy = const MediaReaderPolicy(),
  }) => pumpReader(
    tester,
    items: items,
    policy: policy,
    engines: MediaReaderEngines([
      MediaReaderPdfEngine(
        transport: transport ?? FakeTransport(),
        password: password,
        blockSize: 64 * 1024,
      ),
    ]),
  );

  group('a PDF opens', () {
    testWidgets('from bytes in memory, at its first page', (tester) async {
      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.bytes(pdfOf(3))),
      ]);

      await pumpPdf(tester, () => shows('1 of 3'));

      expect(find.byType(PdfViewer), findsOneWidget);
      await settlePdf(tester);
    });

    testWidgets('from a file on the device', (tester) async {
      final directory = Directory.systemTemp.createTempSync('pdf_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/rota.pdf')
        ..writeAsBytesSync(pdfOf(2));

      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.file(file.path)),
      ]);

      await pumpPdf(tester, () => shows('1 of 2'));
      await settlePdf(tester);
    });

    testWidgets('from a signed URL, by ranges, asking the host once', (
      tester,
    ) async {
      // Some 300 KB: five blocks of 64 KB.
      final bytes = pdfOf(40, padding: 300 * 1024);
      final host = FakeResolve();
      final transport = FakeTransport({'/1': bytes});

      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.remote(host.call)),
      ], transport: transport);
      await pumpPdf(tester, () => shows('1 of 40'));
      await settlePdf(tester);

      expect(host.calls, 1);
      expect(transport.requests, isNotEmpty);
      for (final request in transport.requests) {
        final range = request.range!;
        expect(range.end! - range.start + 1, 64 * 1024);
      }
      // Each block was asked for once.
      final starts = transport.requests.map((request) => request.range!.start);
      expect(starts.toSet(), hasLength(starts.length));
      await closePdf(tester);
    });

    testWidgets('at its first page before the rest of the file has come', (
      tester,
    ) async {
      // Some 600 KB, in blocks of 64 KB: the first has the first pages,
      // the last has the table that says where everything is.
      final bytes = pdfOf(
        400,
        lines: (page) => [for (var i = 0; i < 40; i++) 'Page $page, line $i'],
      );
      final blocks = (bytes.length / (64 * 1024)).ceil();
      expect(blocks, greaterThan(6));
      // The blocks between the two are slow in coming.
      final middle = Completer<void>();
      final transport = FakeTransport({'/1': bytes})
        ..hold = (uri, range) {
          final block = range!.start ~/ (64 * 1024);
          return block > 0 && block < blocks - 2 ? middle.future : null;
        };

      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.remote(FakeResolve().call)),
      ], transport: transport);
      await pumpPdf(tester, () => shows('1 of 400'));

      // The page is up, and most of the file has not been served.
      expect(middle.isCompleted, isFalse);
      expect(find.byType(PdfViewer), findsOneWidget);

      middle.complete();
      await settlePdf(tester, 20);
      expect(tester.takeException(), isNull);
      await closePdf(tester);
    });

    testWidgets('as the PDF a host made of an Office file', (tester) async {
      await pumpPdfReader(tester, [
        MediaReaderItem(
          id: 'minutes',
          name: 'Minutes.docx',
          source: MediaReaderSource.bytes(Uint8List(8)),
          preview: MediaReaderPreview(
            source: MediaReaderSource.bytes(pdfOf(2)),
            contentType: 'application/pdf',
          ),
        ),
      ]);

      await pumpPdf(tester, () => shows('1 of 2'));
      // The chrome names the file, not its PDF.
      expect(find.text('Minutes.docx'), findsOneWidget);
      await settlePdf(tester);
    });

    testWidgets('only when its page comes on screen', (tester) async {
      final host = FakeResolve();
      final transport = FakeTransport({'/1': pdfOf(2)});
      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.bytes(pdfOf(3))),
        pdf('b', MediaReaderSource.remote(host.call)),
      ], transport: transport);
      await pumpPdf(tester, () => shows('1 of 3'));
      await settlePdf(tester);

      // The neighbour is built, and has asked for nothing.
      expect(host.calls, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await pumpPdf(tester, () => shows('1 of 2'));
      await settlePdf(tester);

      expect(host.calls, 1);
      await closePdf(tester);
    });

    testWidgets('at a fresh location when the kept one is refused', (
      tester,
    ) async {
      final bytes = pdfOf(2);
      final host = FakeResolve();
      final transport = FakeTransport({'/1': bytes, '/2': bytes})
        ..status = (uri) => uri.path == '/1' ? 410 : null;

      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.remote(host.call)),
      ], transport: transport);
      await pumpPdf(tester, () => shows('1 of 2'));
      await settlePdf(tester);

      expect(host.calls, 2);
      await closePdf(tester);
    });
  });

  group('a PDF that does not open', () {
    testWidgets('because it did not come says so, and a retry opens it', (
      tester,
    ) async {
      final transport = FakeTransport({'/1': pdfOf(2), '/2': pdfOf(2)})
        ..failure = const SocketException('No route to host');
      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.remote(FakeResolve().call)),
      ], transport: transport);

      await pumpPdf(
        tester,
        () => shows('This file could not be reached. Check the connection.'),
      );

      transport.failure = null;
      await tester.tap(find.text('Try again'));
      await pumpPdf(tester, () => shows('1 of 2'));
      await settlePdf(tester);
      await closePdf(tester);
    });

    testWidgets('because it is not a PDF says so', (tester) async {
      await pumpPdfReader(tester, [
        pdf(
          'a',
          MediaReaderSource.bytes(
            Uint8List.fromList('Not a PDF at all.'.codeUnits),
          ),
        ),
      ]);

      await pumpPdf(tester, () => shows('This file could not be opened.'));

      expect(find.byType(PdfViewer), findsNothing);
    });

    testWidgets("because the host says so shows the host's words", (
      tester,
    ) async {
      final host = FakeResolve()
        ..failure = const MediaReaderUnavailable('Removed by its author.');
      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.remote(host.call)),
      ]);

      await pumpPdf(tester, () => shows('Removed by its author.'));
    });
  });

  group('a protected PDF', () {
    final locked = pdfOf(2, password: 'harvest');

    testWidgets('asks the host until a password opens it', (tester) async {
      final asked = <(String, int)>[];
      await pumpPdfReader(
        tester,
        [pdf('a', MediaReaderSource.bytes(locked))],
        password: (item, attempt) async {
          asked.add((item.id, attempt));
          return attempt == 0 ? 'supper' : 'harvest';
        },
      );

      await pumpPdf(tester, () => shows('1 of 2'));
      await settlePdf(tester);

      expect(asked, [('a', 0), ('a', 1)]);
    });

    testWidgets('shows its card when the host gives up', (tester) async {
      await pumpPdfReader(tester, [
        pdf('a', MediaReaderSource.bytes(locked)),
      ], password: (item, attempt) async => null);

      await pumpPdf(
        tester,
        () => shows('This file is protected by a password.'),
      );
    });

    testWidgets('shows its card when the host has no way to ask', (
      tester,
    ) async {
      await pumpPdfReader(tester, [pdf('a', MediaReaderSource.bytes(locked))]);

      await pumpPdf(
        tester,
        () => shows('This file is protected by a password.'),
      );
    });
  });

  group('what a PDF leaves behind', () {
    final bytes = pdfOf(4, padding: 100 * 1024);

    Future<void> openAndClose(
      WidgetTester tester,
      MediaReaderPolicy policy,
      FakeTransport transport,
    ) async {
      await pumpPdfReader(
        tester,
        [pdf('a', MediaReaderSource.remote(FakeResolve().call))],
        transport: transport,
        policy: policy,
      );
      await pumpPdf(tester, () => shows('1 of 4'));
      await settlePdf(tester);
      await closePdf(tester);
    }

    testWidgets('is in the directory the policy names, and nowhere else', (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync('reader_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final policy = MediaReaderPolicy(
        cache: MediaReaderCache.directory(directory.path),
      );
      final transport = FakeTransport({'/1': bytes});

      await openAndClose(tester, policy, transport);

      final name = MediaReaderBlockFile.nameOf('a:pdf');
      expect(
        directory.listSync().map((entry) => entry.uri.pathSegments.last),
        unorderedEquals(['$name.blocks', '$name.json']),
      );

      // The next showing reads what was kept.
      final again = FakeTransport({'/1': bytes});
      await openAndClose(tester, policy, again);
      expect(again.requests, isEmpty);
    });

    testWidgets('is nothing on disk with export off', (tester) async {
      final directory = Directory.systemTemp.createTempSync('reader_');
      addTearDown(() => directory.deleteSync(recursive: true));

      await openAndClose(
        tester,
        MediaReaderPolicy(
          canExport: false,
          cache: MediaReaderCache.directory(directory.path),
        ),
        FakeTransport({'/1': bytes}),
      );

      expect(directory.listSync(), isEmpty);
    });

    testWidgets('is nothing at all with no cache', (tester) async {
      const policy = MediaReaderPolicy(cache: MediaReaderCache.none());
      await openAndClose(tester, policy, FakeTransport({'/1': bytes}));

      final again = FakeTransport({'/1': bytes});
      await openAndClose(tester, policy, again);

      expect(again.requests, isNotEmpty);
      expect(MediaReaderBlockMemory.shared.bytes, 0);
    });

    test("is never in pdfrx's own cache", () {
      expect(pdfrxKeeps.listSync(recursive: true), isEmpty);
    });
  });
}
