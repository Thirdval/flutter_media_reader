import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/engine/text/text_line.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/archives.dart';
import '../../support/fakes.dart';

void main() {
  final notes = utf8.encode('The rota for October.\n');
  late WatchedEngine engine;
  late FakeTransport transport;
  setUp(() {
    transport = FakeTransport();
    MediaReaderCache.clearMemory();
  });

  MediaReaderItem archive(
    String name,
    Uint8List bytes, {
    MediaReaderSource? source,
  }) => MediaReaderItem(
    id: name,
    name: name,
    source: source ?? MediaReaderSource.bytes(bytes),
  );

  /// The reader in an app with a navigator: an entry opens as a route.
  Future<MediaReaderPage> pumpArchive(
    WidgetTester tester,
    List<MediaReaderItem> items, {
    int maxEntryBytes = 64 * 1024 * 1024,
    ValueChanged<Uri>? onLink,
    VoidCallback? onDismissed,
  }) async {
    engine = WatchedEngine(
      MediaReaderArchiveEngine(
        transport: transport,
        blockSize: 16 * 1024,
        maxEntryBytes: maxEntryBytes,
      ),
    );
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: MediaReaderView(
          items: items,
          engines: MediaReaderEngines.standard.withFirst([engine]),
          onLink: onLink,
          onDismissed: onDismissed,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return engine.pages[items.first.id]!;
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  group('an archive', () {
    testWidgets('lists its folders first, then its files with their '
        'sizes', (tester) async {
      final semantics = tester.ensureSemantics();
      final page = await pumpArchive(tester, [
        archive(
          'photos.zip',
          zipOf({
            'notes.txt': notes,
            'photos/hall.bin': Uint8List(2048),
            'README.md': notes,
          }),
        ),
      ]);

      expect(page.status.value, '3 files');
      expect(shows('photos/'), isTrue);
      expect(shows('notes.txt'), isTrue);
      expect(shows('README.md'), isTrue);
      expect(shows('hall.bin'), isFalse);
      expect(find.bySemanticsLabel('notes.txt, 22 B'), findsOneWidget);
      expect(page.holdsDismiss.value, isTrue);
      semantics.dispose();
    });

    testWidgets('opens a folder in place, and goes back up', (tester) async {
      final page = await pumpArchive(tester, [
        archive(
          'photos.zip',
          zipOf({'notes.txt': notes, 'photos/2026/hall.bin': Uint8List(10)}),
        ),
      ]);

      await tester.tap(find.text('photos/'));
      await tester.pumpAndSettle();
      expect(shows('2026/'), isTrue);
      expect(shows('notes.txt'), isFalse);
      expect(page.status.value, 'photos');

      await tester.tap(find.text('2026/'));
      await tester.pumpAndSettle();
      expect(shows('hall.bin'), isTrue);
      expect(page.status.value, 'photos/2026');

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(page.status.value, 'photos');
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(page.status.value, '3 files'.replaceFirst('3', '2'));
    });

    testWidgets('opens a file in a reader over this one, through the same '
        'engines', (tester) async {
      await pumpArchive(tester, [
        archive('photos.zip', zipOf({'notes.txt': notes})),
      ]);

      await tester.tap(find.text('notes.txt'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsNWidgets(2));
      expect(find.byType(MediaReaderTextLine), findsWidgets);
      expect(shows('The rota for October.'), isTrue);

      // Its close button brings the list back.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MediaReaderView), findsOneWidget);
      expect(shows('notes.txt'), isTrue);
    });

    testWidgets('lists a zip inside a zip in its turn', (tester) async {
      await pumpArchive(tester, [
        archive(
          'outer.zip',
          zipOf({
            'inner.zip': zipOf({'deep.txt': notes}),
          }),
        ),
      ]);

      await tester.tap(find.text('inner.zip'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsNWidgets(2));
      expect(shows('deep.txt'), isTrue);
    });

    testWidgets('a tar, and a gzipped file, list as well', (tester) async {
      await pumpArchive(tester, [
        archive('a.tar', tarOf({'x.txt': notes})),
        archive('notes.txt.gz', gzipOf(notes)),
      ]);
      expect(shows('x.txt'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(shows('notes.txt'), isTrue);
    });

    testWidgets('comes by ranges from a signed URL: the list, then the '
        'entry', (tester) async {
      final host = FakeResolve();
      transport = FakeTransport({
        '/1': zipOf({'big.bin': Uint8List(200 * 1024), 'notes.txt': notes}),
      });

      await pumpArchive(tester, [
        archive(
          'a.zip',
          Uint8List(0),
          source: MediaReaderSource.remote(host.call),
        ),
      ]);
      expect(shows('notes.txt'), isTrue);
      final listed = transport.requests.length;

      await tester.tap(find.text('notes.txt'));
      await tester.pumpAndSettle();

      expect(shows('The rota for October.'), isTrue);
      expect(listed, lessThan(4));
      expect(transport.requests.length - listed, lessThan(3));
      expect(host.calls, 1);
    });
  });

  group('what cannot be opened', () {
    testWidgets('an encrypted entry is there, greyed, and says so', (
      tester,
    ) async {
      await pumpArchive(tester, [
        archive('a.zip', zipOf({'secret.txt': notes}, password: 'x')),
      ]);

      expect(
        find.textContaining('This file is protected by a password.'),
        findsOneWidget,
      );
      await tester.tap(find.text('secret.txt'));
      await tester.pumpAndSettle();
      expect(find.byType(MediaReaderView), findsOneWidget);
    });

    testWidgets('an entry too large says so where it is', (tester) async {
      await pumpArchive(tester, [
        archive('a.zip', zipOf({'big.bin': Uint8List(5000)})),
      ], maxEntryBytes: 1000);

      await tester.tap(find.text('big.bin'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsOneWidget);
      expect(
        find.textContaining('This file is too large to show here.'),
        findsOneWidget,
      );
    });

    testWidgets('what is not an archive shows its card', (tester) async {
      await pumpArchive(tester, [
        archive('a.zip', Uint8List.fromList(utf8.encode('not a zip'))),
      ]);

      expect(find.text('This file could not be opened.'), findsOneWidget);
    });

    testWidgets('an archive that does not come says so', (tester) async {
      transport.failure = const SocketException('no route');

      await pumpArchive(tester, [
        archive(
          'a.zip',
          Uint8List(0),
          source: MediaReaderSource.remote(FakeResolve().call),
        ),
      ]);

      expect(
        find.text('This file could not be reached. Check the connection.'),
        findsOneWidget,
      );
    });
  });
}
