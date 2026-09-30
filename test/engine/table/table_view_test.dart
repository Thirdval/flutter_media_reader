import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/text_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../support/fakes.dart';

void main() {
  late WatchedEngine engine;
  late FakeTransport transport;
  setUp(() {
    transport = FakeTransport();
    MediaReaderCache.clearMemory();
  });

  MediaReaderItem table(
    String name,
    String content, {
    MediaReaderSource? source,
  }) => MediaReaderItem(
    id: name,
    name: name,
    source: source ?? MediaReaderSource.bytes(utf8.encode(content)),
  );

  Future<MediaReaderPage> pumpTable(
    WidgetTester tester,
    List<MediaReaderItem> items, {
    int blockSize = 64,
  }) async {
    engine = WatchedEngine(
      MediaReaderTableEngine(transport: transport, blockSize: blockSize),
    );
    await pumpReader(
      tester,
      items: items,
      engines: MediaReaderEngines([engine]),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    return engine.pages[items.first.id]!;
  }

  /// The cells on screen, in order.
  List<String> cells(WidgetTester tester) => [
    for (final cell in tester.widgetList<TableViewCell>(
      find.byType(TableViewCell),
    ))
      tester
          .widget<Text>(
            find.descendant(
              of: find.byWidget(cell),
              matching: find.byType(Text),
            ),
          )
          .textSpan!
          .toPlainText()
          .trim(),
  ];

  group('a table opens', () {
    testWidgets('with its header row and its cells', (tester) async {
      final page = await pumpTable(tester, [
        table('rota.csv', 'name,role\nRuth,Welcome\n"Okoro, Daniel",Sound\n'),
      ]);

      expect(cells(tester), [
        'name',
        'role',
        'Ruth',
        'Welcome',
        'Okoro, Daniel',
        'Sound',
      ]);
      expect(page.status.value, '3 rows');
      expect(page.document.value, isNotNull);
      expect(page.holdsDismiss.value, isTrue);
      expect(page.holdsPaging.value, isFalse);
    });

    testWidgets('written with tabs, by its name', (tester) async {
      await pumpTable(tester, [table('rota.tsv', 'a\tb\n1\t2\n')]);

      expect(cells(tester), ['a', 'b', '1', '2']);
    });

    testWidgets('written with semicolons, by its rows', (tester) async {
      await pumpTable(tester, [table('rota.csv', 'a;b\n1;2\n')]);

      expect(cells(tester), ['a', 'b', '1', '2']);
    });

    testWidgets('of a hundred thousand rows, building only those on '
        'screen', (tester) async {
      final content = [
        'id,name',
        for (var i = 0; i < 100000; i++) '$i,person $i',
      ].join('\n');
      final page = await pumpTable(tester, [table('big.csv', content)]);

      expect(page.status.value, '100,001 rows');
      expect(cells(tester).length, lessThan(200));
      expect(cells(tester).first, 'id');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(cells(tester), contains('person 99999'));
      // The header stays.
      expect(cells(tester).first, 'id');
    });

    testWidgets('as its rows come from a signed URL', (tester) async {
      final content = [
        'id,name',
        for (var i = 0; i < 40; i++) '$i,person $i',
      ].join('\n');
      final rest = Completer<void>();
      transport = FakeTransport({'/1': utf8.encode(content)})
        ..hold = (uri, range) => range!.start == 0 ? null : rest.future;

      await pumpTable(tester, [
        table(
          'rota.csv',
          '',
          source: MediaReaderSource.remote(FakeResolve().call),
        ),
      ]);
      expect(cells(tester), contains('person 0'));
      expect(cells(tester), isNot(contains('person 39')));

      rest.complete();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(cells(tester), contains('person 39'));
    });

    testWidgets('wider than the screen takes sideways drags', (tester) async {
      final page = await pumpTable(tester, [
        table(
          'wide.csv',
          [
            for (var row = 0; row < 3; row++)
              [for (var c = 0; c < 20; c++) 'column $c of row $row'].join(','),
          ].join('\n'),
        ),
      ]);
      await tester.pump();

      expect(page.holdsPaging.value, isTrue);
    });
  });

  group('searching', () {
    testWidgets('finds a row far down, and goes to it', (tester) async {
      final content = [
        'id,name',
        for (var i = 0; i < 5000; i++) '$i,${i == 4000 ? 'Harvest' : 'x'}',
      ].join('\n');
      final page = await pumpTable(tester, [table('big.csv', content)]);
      final document = page.document.value!;

      document.search('harvest');
      await tester.pumpAndSettle();

      expect(document.state.value.matchCount, 1);
      expect(cells(tester), contains('Harvest'));
      expect(cells(tester), contains('4000'));
    });
  });

  group('selected cells', () {
    testWidgets('are copied with tabs between them, and rows on lines', (
      tester,
    ) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final data = call.arguments as Map<Object?, Object?>;
              copied.add(data['text']! as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpTable(tester, [table('rota.csv', 'name,role\nRuth,Welcome\n')]);

      await tester.longPressAt(
        tester.getTopLeft(find.text('Ruth\t')) + const Offset(10, 10),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MediaReaderTextMenu), findsOneWidget);
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      // All of a small file is the file itself.
      expect(copied.single, 'name,role\nRuth,Welcome\n');
    });
  });
}
