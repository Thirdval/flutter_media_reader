import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/engine/text/text_line.dart';
import 'package:flutter_media_reader/src/shell/text_menu.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late WatchedEngine engine;
  late FakeTransport transport;

  MediaReaderItem text(
    String name,
    String content, {
    MediaReaderSource? source,
  }) => MediaReaderItem(
    id: name,
    name: name,
    source: source ?? MediaReaderSource.bytes(utf8.encode(content)),
  );

  Future<MediaReaderPage> pumpText(
    WidgetTester tester,
    List<MediaReaderItem> items, {
    int maxBytes = 32 * 1024 * 1024,
    int blockSize = 64,
    ValueChanged<MediaReaderItem>? onItemShown,
  }) async {
    engine = WatchedEngine(
      MediaReaderTextEngine(
        transport: transport,
        maxBytes: maxBytes,
        blockSize: blockSize,
      ),
    );
    await pumpReader(
      tester,
      items: items,
      engines: MediaReaderEngines([engine]),
      onItemShown: onItemShown,
    );
    // Bytes in memory are read in a few turns; a file on disk or a
    // server takes real time, and the test waits for it.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    return engine.pages[items.first.id]!;
  }

  setUp(() {
    transport = FakeTransport();
    // What one test's file left in memory is not the next test's file.
    MediaReaderCache.clearMemory();
  });

  /// The lines on screen, in order.
  List<String> shown(WidgetTester tester) => [
    for (final line in tester.widgetList<MediaReaderTextLine>(
      find.byType(MediaReaderTextLine),
    ))
      line.range == null
          ? line.text
          : line.text.substring(line.range!.start, line.range!.end),
  ];

  Iterable<Text> texts(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text));

  group('a text opens', () {
    testWidgets('from bytes, its lines in order', (tester) async {
      final page = await pumpText(tester, [
        text('notes.txt', 'First line\nSecond line\n\nFourth'),
      ]);

      expect(shown(tester), ['First line', 'Second line', '', 'Fourth']);
      expect(page.document.value, isNotNull);
      expect(page.holdsDismiss.value, isTrue);
    });

    testWidgets('from a file on the device', (tester) async {
      final directory = Directory.systemTemp.createTempSync('text_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/notes.txt')
        ..writeAsStringSync('on disk');

      await pumpText(tester, [
        text('notes.txt', '', source: MediaReaderSource.file(file.path)),
      ]);
      // The disk answers in its own time.
      await pumpUntil(tester, () => shown(tester).isNotEmpty);

      expect(shown(tester), ['on disk']);
    });

    testWidgets('from a signed URL, showing its start while the rest '
        'comes', (tester) async {
      final content = [for (var i = 0; i < 40; i++) 'line $i'].join('\n');
      final bytes = utf8.encode(content);
      final rest = Completer<void>();
      transport = FakeTransport({'/1': bytes})
        ..hold = (uri, range) => range!.start == 0 ? null : rest.future;
      final host = FakeResolve();

      await pumpText(tester, [
        text('notes.log', '', source: MediaReaderSource.remote(host.call)),
      ]);

      // The first 64 bytes: the first lines are up, the rest is not.
      expect(shown(tester).first, 'line 0');
      expect(shown(tester).length, lessThan(40));

      rest.complete();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(shown(tester).last, 'line 39');
      expect(host.calls, 1);
    });

    testWidgets('only when its page comes on screen', (tester) async {
      final host = FakeResolve();
      transport = FakeTransport({'/1': utf8.encode('later')});
      await pumpText(tester, [
        text('a.txt', 'first'),
        text('b.txt', '', source: MediaReaderSource.remote(host.call)),
      ]);
      expect(host.calls, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(host.calls, 1);
      expect(shown(tester), contains('later'));
    });

    testWidgets('as UTF-16, and as Windows-1252', (tester) async {
      await pumpText(tester, [
        MediaReaderItem(
          id: 'a',
          name: 'a.txt',
          source: MediaReaderSource.bytes(
            Uint8List.fromList([
              0xFF, 0xFE, //
              for (final unit in 'Grüße'.codeUnits) ...[unit & 0xFF, unit >> 8],
            ]),
          ),
        ),
        MediaReaderItem(
          id: 'b',
          name: 'b.txt',
          source: MediaReaderSource.bytes(
            Uint8List.fromList([0x63, 0x61, 0x66, 0xE9]),
          ),
        ),
      ]);
      expect(shown(tester), ['Grüße']);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(shown(tester), ['café']);
    });

    testWidgets('cut short past the limit, and says so', (tester) async {
      final content = [for (var i = 0; i < 100; i++) 'line $i'].join('\n');

      await pumpText(tester, [text('big.log', content)], maxBytes: 100);

      expect(shown(tester).length, lessThan(20));
      expect(find.text('The first 100 B of 789 B are shown.'), findsOneWidget);
    });

    testWidgets('and says why when it does not', (tester) async {
      transport.failure = const SocketException('no route');
      await pumpText(tester, [
        text('a.txt', '', source: MediaReaderSource.remote(FakeResolve().call)),
      ]);

      expect(
        find.text('This file could not be reached. Check the connection.'),
        findsOneWidget,
      );
    });
  });

  group('how a text is set', () {
    testWidgets('prose in the reader\'s own face, code in one of equal '
        'widths', (tester) async {
      await pumpText(tester, [
        text('notes.txt', 'prose'),
        text('main.dart', 'code'),
      ]);
      expect(texts(tester).first.style?.fontFamily, isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(texts(tester).first.style?.fontFamily, 'monospace');
    });

    testWidgets('JSON laid out to be read, or as it is written', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final page = await pumpText(tester, [text('rota.json', '{"a":[1,2]}')]);
      expect(shown(tester), ['{', '  "a": [', '    1,', '    2', '  ]', '}']);

      final formatted = page.document.value!.state.value.toggles.singleWhere(
        (toggle) => toggle.label == 'Formatted',
      );
      expect(formatted.on, isTrue);
      formatted.onChanged(false);
      await tester.pumpAndSettle();

      expect(shown(tester), ['{"a":[1,2]}']);
      // The plain bar has the same choice.
      expect(find.text('Formatted'), findsOneWidget);
      expect(find.text('Wrap'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a long line wrapped at the column, or not', (tester) async {
      final page = await pumpText(tester, [text('long.log', 'x' * 300)]);
      // In rows: the line is several widgets of the same height.
      expect(shown(tester).length, greaterThan(1));
      expect(shown(tester).join(), 'x' * 300);
      expect(page.holdsPaging.value, isFalse);

      final wrap = page.document.value!.state.value.toggles.first;
      expect(wrap.label, 'Wrap');
      wrap.onChanged(false);
      await tester.pumpAndSettle();

      expect(shown(tester), ['x' * 300]);
      // It goes on to the right: sideways drags are its own.
      expect(page.holdsPaging.value, isTrue);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('builds only the lines on screen', (tester) async {
      final content = [for (var i = 0; i < 100000; i++) 'line $i'].join('\n');

      await pumpText(tester, [text('big.log', content)]);

      expect(shown(tester).length, lessThan(100));
      expect(shown(tester).first, 'line 0');
    });
  });

  group('searching', () {
    testWidgets('finds the text, goes to the first match, and on', (
      tester,
    ) async {
      final content = [
        for (var i = 0; i < 5000; i++) i == 3000 || i == 4000 ? 'harvest' : 'l',
      ].join('\n');
      final page = await pumpText(tester, [text('big.log', content)]);
      final document = page.document.value!;

      document.search('harvest');
      await tester.pumpAndSettle();

      expect(document.state.value.matchCount, 2);
      expect(document.state.value.matchNumber, 1);
      expect(shown(tester), contains('harvest'));
      expect(shown(tester), isNot(contains('line 0')));

      await document.nextMatch();
      await tester.pumpAndSettle();
      expect(document.state.value.matchNumber, 2);
    });

    testWidgets('finds its way through prose too', (tester) async {
      final content = [
        for (var i = 0; i < 400; i++)
          i == 350 ? 'the harvest supper' : 'a line of prose, number $i',
      ].join('\n');
      final page = await pumpText(tester, [text('notes.txt', content)]);
      final document = page.document.value!;

      document.search('supper');
      await tester.pumpAndSettle();

      expect(document.state.value.matchCount, 1);
      expect(shown(tester), contains('the harvest supper'));
    });

    testWidgets('marks the matches on the lines', (tester) async {
      final page = await pumpText(tester, [
        text('a.txt', 'a harvest, a HARVEST'),
      ]);

      page.document.value!.search('harvest');
      await tester.pumpAndSettle();

      final line = tester.widget<MediaReaderTextLine>(
        find.byType(MediaReaderTextLine),
      );
      expect(line.pattern, isNotNull);
      expect(line.active, 0);
    });
  });

  group('the page', () {
    testWidgets('a tap hides the chrome, and another brings it back', (
      tester,
    ) async {
      final page = await pumpText(tester, [text('a.txt', 'hello')]);

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(page.chromeVisible.value, isFalse);

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(page.chromeVisible.value, isTrue);
    });

    testWidgets('Page Down and End scroll the lines', (tester) async {
      final content = [for (var i = 0; i < 1000; i++) 'line $i'].join('\n');
      await pumpText(tester, [text('big.log', content)]);
      expect(shown(tester).first, 'line 0');

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(shown(tester).first, isNot('line 0'));

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(shown(tester).last, 'line 999');
    });
  });

  group('selected text', () {
    late List<String> copied;
    setUp(() {
      copied = [];
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
    });

    testWidgets('is copied with its line breaks', (tester) async {
      await pumpText(tester, [text('a.txt', 'one\ntwo\nthree')]);

      // A long press on a word selects it and brings up the menu.
      await tester.longPressAt(
        tester.getTopLeft(find.text('two\n')) + const Offset(12, 8),
      );
      await tester.pumpAndSettle();
      final menu = tester.widget<MediaReaderTextMenu>(
        find.byType(MediaReaderTextMenu),
      );
      expect(menu.actions.map((action) => action.label), [
        'Copy',
        'Select all',
      ]);

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied.single, 'one\ntwo\nthree');
    });

    testWidgets('all of a long text is copied, not only what is built', (
      tester,
    ) async {
      final content = [for (var i = 0; i < 3000; i++) 'line $i'].join('\n');
      await pumpText(tester, [text('big.log', content)]);

      await tester.longPressAt(
        tester.getTopLeft(find.text('line 5\n')) + const Offset(12, 8),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      // The menu stays on the screen, though the selection runs off it.
      expect(
        tester.getRect(find.byType(MediaReaderTextMenu)).bottom,
        lessThan(600),
      );
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied.single, content);
    });
  });
}
