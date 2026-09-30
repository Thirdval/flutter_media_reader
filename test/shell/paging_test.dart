import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late FakeEngine engine;
  late MediaReaderEngines engines;
  setUp(() {
    engine = FakeEngine('fake', kinds: {MediaKind.picture});
    engines = MediaReaderEngines([engine]);
  });

  /// The name of the item whose page is on screen: a neighbour is built
  /// but not painted, which a finder leaves out.
  String onScreen(WidgetTester tester) => engine.alive.singleWhere(
    (name) => find.text('fake:$name').evaluate().isNotEmpty,
  );

  group('paging', () {
    testWidgets('the item asked for is shown first', (tester) async {
      await pumpReader(
        tester,
        items: pictures(),
        initialIndex: 2,
        engines: engines,
      );

      expect(onScreen(tester), 'c.jpg');
    });

    testWidgets('an index outside the items is brought inside', (tester) async {
      await pumpReader(
        tester,
        items: pictures(),
        initialIndex: 9,
        engines: engines,
      );

      expect(onScreen(tester), 'e.jpg');
    });

    testWidgets('the neighbours are prepared, and only they', (tester) async {
      await pumpReader(
        tester,
        items: pictures(),
        initialIndex: 2,
        engines: engines,
      );

      expect(engine.alive, unorderedEquals(['b.jpg', 'c.jpg', 'd.jpg']));
      expect(engine.pages['c.jpg']!.isCurrent.value, isTrue);
      expect(engine.pages['b.jpg']!.isCurrent.value, isFalse);
      expect(engine.pages['d.jpg']!.isCurrent.value, isFalse);
    });

    testWidgets('a drag sideways goes to the next item', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);

      await swipeToNext(tester);

      expect(onScreen(tester), 'b.jpg');
      expect(engine.pages['b.jpg']!.isCurrent.value, isTrue);
      expect(engine.pages['a.jpg']!.isCurrent.value, isFalse);
    });

    testWidgets('pages further off are released', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      final first = engine.pages['a.jpg']!;

      await swipeToNext(tester);
      await swipeToNext(tester);
      await swipeToNext(tester);

      expect(onScreen(tester), 'd.jpg');
      expect(engine.alive, unorderedEquals(['c.jpg', 'd.jpg', 'e.jpg']));
      // The released page's notifiers are disposed with it.
      expect(() => first.status.addListener(() {}), throwsFlutterError);
    });

    testWidgets('the host hears of each item that comes on screen', (
      tester,
    ) async {
      final shown = <String>[];
      await pumpReader(
        tester,
        items: pictures(),
        initialIndex: 1,
        engines: engines,
        onItemShown: (item) => shown.add(item.name),
      );
      await tester.pump();
      expect(shown, ['b.jpg']);

      await swipeToNext(tester);
      await swipeToPrevious(tester);

      // A neighbour being prepared was never reported.
      expect(shown, ['b.jpg', 'c.jpg', 'b.jpg']);
    });

    testWidgets('an engine that holds sideways drags stops the paging', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(), engines: engines);

      engine.pages['a.jpg']!.holdsPaging.value = true;
      await tester.pump();
      await swipeToNext(tester);
      expect(onScreen(tester), 'a.jpg');

      engine.pages['a.jpg']!.holdsPaging.value = false;
      await tester.pump();
      await swipeToNext(tester);
      expect(onScreen(tester), 'b.jpg');
    });

    testWidgets('two items may not share an id', (tester) async {
      await pumpReader(
        tester,
        items: [
          item('a.jpg', id: 'same'),
          item('b.jpg', id: 'same'),
        ],
        engines: engines,
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('no items is an empty canvas', (tester) async {
      await pumpReader(tester, items: const []);

      expect(tester.takeException(), isNull);
      expect(find.byType(PageView), findsNothing);
    });
  });

  group('the keyboard', () {
    testWidgets('the arrows go between items', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(onScreen(tester), 'b.jpg');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(onScreen(tester), 'a.jpg');
    });

    testWidgets('the arrows stop at the ends', (tester) async {
      await pumpReader(tester, items: pictures(2), engines: engines);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(onScreen(tester), 'a.jpg');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(onScreen(tester), 'b.jpg');
    });

    testWidgets('right to left, the left arrow goes to the next item', (
      tester,
    ) async {
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        textDirection: TextDirection.rtl,
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(onScreen(tester), 'b.jpg');
    });

    testWidgets('an engine that holds sideways drags still pages by key', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      engine.pages['a.jpg']!.holdsPaging.value = true;
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(onScreen(tester), 'b.jpg');
    });

    testWidgets('a reader that does not take the keyboard leaves the keys', (
      tester,
    ) async {
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        autofocus: false,
      );
      await tester.pump();

      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(handled, isFalse);
      expect(onScreen(tester), 'a.jpg');
    });
  });

  group('when the host changes the items', () {
    testWidgets('the file on screen stays on screen', (tester) async {
      final shown = <String>[];
      final items = pictures(3);
      await pumpReader(
        tester,
        items: items,
        initialIndex: 1,
        engines: engines,
        onItemShown: (item) => shown.add(item.name),
      );
      await tester.pump();
      final page = engine.pages['b.jpg']!;

      // An older picture loads in front.
      await pumpReader(
        tester,
        items: [item('z.jpg'), ...items],
        initialIndex: 1,
        engines: engines,
        onItemShown: (item) => shown.add(item.name),
      );
      await tester.pump();

      expect(onScreen(tester), 'b.jpg');
      expect(engine.pages['b.jpg'], same(page));
      expect(page.index, 2);
      expect(page.count, 4);
      expect(page.isCurrent.value, isTrue);
      expect(shown, ['b.jpg']);

      // Paging carries on from where the file now is.
      await swipeToPrevious(tester);
      expect(onScreen(tester), 'a.jpg');
      await swipeToPrevious(tester);
      expect(onScreen(tester), 'z.jpg');
      expect(shown, ['b.jpg', 'a.jpg', 'z.jpg']);
    });

    testWidgets('when that file is removed, its place is taken', (
      tester,
    ) async {
      final shown = <String>[];
      final items = pictures(3);
      await pumpReader(
        tester,
        items: items,
        initialIndex: 1,
        engines: engines,
        onItemShown: (item) => shown.add(item.name),
      );
      await tester.pump();

      await pumpReader(
        tester,
        items: [items[0], items[2]],
        initialIndex: 1,
        engines: engines,
        onItemShown: (item) => shown.add(item.name),
      );
      await tester.pump();

      expect(onScreen(tester), 'c.jpg');
      expect(engine.alive, unorderedEquals(['a.jpg', 'c.jpg']));
      expect(shown, ['b.jpg', 'c.jpg']);
    });

    testWidgets('when the last file is removed, the one before is shown', (
      tester,
    ) async {
      final items = pictures(3);
      await pumpReader(tester, items: items, initialIndex: 2, engines: engines);

      await pumpReader(
        tester,
        items: items.sublist(0, 2),
        initialIndex: 2,
        engines: engines,
      );
      await tester.pump();

      expect(onScreen(tester), 'b.jpg');
    });
  });

  group('disposal', () {
    testWidgets('removing the reader releases every page', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      final pages = engine.pages.values.toList();
      expect(pages, isNotEmpty);

      await tester.pumpWidget(const SizedBox());

      expect(engine.alive, isEmpty);
      for (final page in pages) {
        expect(() => page.isCurrent.addListener(() {}), throwsFlutterError);
        expect(() => page.status.addListener(() {}), throwsFlutterError);
      }
    });

    testWidgets('a page the shell released tells it nothing more', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      final page = engine.pages['a.jpg']!;
      await tester.pumpWidget(const SizedBox());

      // An engine's late callback, after its page is gone.
      page
        ..fail('too late')
        ..toggleChrome()
        ..dispose();

      expect(tester.takeException(), isNull);
    });
  });
}
