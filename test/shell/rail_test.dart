import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/rail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late FakeEngine engine;
  late MediaReaderEngines engines;
  setUp(() {
    engine = FakeEngine('fake', kinds: {MediaKind.picture});
    engines = MediaReaderEngines([engine]);
  });

  /// A desktop window, 1200 by 800.
  void wide(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder tile(String name) => find.descendant(
    of: find.byType(MediaReaderRail),
    matching: find.text(name),
  );

  group('the rail', () {
    testWidgets('stands at the start of a wide window, with every file, '
        'and the canvas beside it', (tester) async {
      wide(tester);
      await pumpReader(tester, items: pictures(), engines: engines);

      for (final name in ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg', 'e.jpg']) {
        expect(tile(name), findsOneWidget);
      }
      expect(tester.getTopLeft(find.byType(PageView)).dx, 104);
      expect(tester.getSize(find.byType(PageView)).width, 1200 - 104);
    });

    testWidgets('a tap on a file goes to it, and only it comes on screen', (
      tester,
    ) async {
      wide(tester);
      final shown = <String>[];
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onItemShown: (item) => shown.add(item.name),
      );

      await tester.tap(tile('e.jpg'));
      await tester.pumpAndSettle();

      expect(find.text('fake:e.jpg'), findsOneWidget);
      expect(shown, ['a.jpg', 'e.jpg']);
    });

    testWidgets('marks the file on screen, and follows the paging', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      wide(tester);
      await pumpReader(tester, items: pictures(), engines: engines);

      expect(
        tester.getSemantics(find.bySemanticsLabel('a.jpg, 1 of 5')),
        matchesSemantics(
          label: 'a.jpg, 1 of 5',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('b.jpg, 2 of 5')),
        matchesSemantics(
          label: 'b.jpg, 2 of 5',
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('b.jpg, 2 of 5')),
        matchesSemantics(
          label: 'b.jpg, 2 of 5',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('shows a poster where the host gives one, and the kind '
        'where not', (tester) async {
      wide(tester);
      await pumpReader(
        tester,
        items: [
          MediaReaderItem(
            id: 'a',
            name: 'a.jpg',
            source: MediaReaderSource.bytes(Uint8List(0)),
            poster: (context) =>
                const ColoredBox(key: Key('poster'), color: Color(0xFF00FF00)),
          ),
          item('b.pdf'),
          item('notes'),
        ],
        engines: engines,
      );

      expect(
        find.descendant(
          of: find.byType(MediaReaderRail),
          matching: find.byKey(const Key('poster')),
        ),
        findsOneWidget,
      );
      expect(tile('PDF'), findsOneWidget);
      expect(tile('notes'), findsOneWidget);
    });

    testWidgets('keeps the file on screen in view', (tester) async {
      wide(tester);
      final items = [for (var i = 0; i < 40; i++) item('$i.jpg')];
      await pumpReader(
        tester,
        items: items,
        initialIndex: 30,
        engines: engines,
      );
      await tester.pump();

      expect(tile('30.jpg'), findsOneWidget);
      expect(tester.getRect(tile('30.jpg')).bottom, lessThan(800));
      expect(tile('0.jpg'), findsNothing);

      await tester.tap(tile('25.jpg'));
      await tester.pumpAndSettle();
      // Two files earlier are in view: the rail scrolls only as far as it
      // has to.
      expect(tile('25.jpg'), findsOneWidget);
      expect(tester.getRect(tile('25.jpg')).top, greaterThan(0));
    });

    testWidgets('hides with the chrome, and comes back with it', (
      tester,
    ) async {
      wide(tester);
      await pumpReader(tester, items: pictures(), engines: engines);

      await tester.tapAt(const Offset(600, 400));
      await tester.pumpAndSettle();
      expect(tile('a.jpg'), findsNothing);
      expect(tester.getTopLeft(find.byType(PageView)).dx, 0);

      await tester.tapAt(const Offset(600, 400));
      await tester.pumpAndSettle();
      expect(tile('a.jpg'), findsOneWidget);
      expect(tester.getTopLeft(find.byType(PageView)).dx, 104);
    });

    testWidgets('is not there on a narrow window', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);

      expect(find.byType(MediaReaderRail), findsNothing);
      expect(tester.getTopLeft(find.byType(PageView)).dx, 0);
    });

    testWidgets('is not there for a lone file', (tester) async {
      wide(tester);
      await pumpReader(tester, items: pictures(1), engines: engines);

      expect(find.byType(MediaReaderRail), findsNothing);
    });

    testWidgets('the host can ask for none', (tester) async {
      wide(tester);
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: const MediaReaderChrome(railFromWidth: double.infinity),
      );

      expect(find.byType(MediaReaderRail), findsNothing);
    });

    testWidgets('stands at the end right to left', (tester) async {
      wide(tester);
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        textDirection: TextDirection.rtl,
      );

      expect(tester.getTopLeft(find.byType(MediaReaderRail)).dx, 1200 - 104);
      expect(tester.getTopLeft(find.byType(PageView)).dx, 0);
    });
  });
}
