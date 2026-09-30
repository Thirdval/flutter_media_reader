import 'package:flutter/gestures.dart';
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

  /// The host's menu: Reply, and Share where export is allowed; each
  /// remembers the item it was pressed for.
  final pressed = <String>[];
  final told = <MediaReaderState>[];
  setUp(() {
    pressed.clear();
    told.clear();
  });
  MediaReaderChrome chromeWithMenu() => MediaReaderChrome(
    menu: (context, state) {
      told.add(state);
      return [
        (
          label: 'Reply',
          onPressed: () => pressed.add('Reply ${state.item.name}'),
        ),
        if (state.canExport)
          (
            label: 'Share',
            onPressed: () => pressed.add('Share ${state.item.name}'),
          ),
      ];
    },
  );

  Future<void> pumpWithMenu(
    WidgetTester tester, {
    MediaReaderPolicy policy = const MediaReaderPolicy(),
    VoidCallback? onDismissed,
    ValueChanged<MediaReaderItem>? onItemShown,
  }) => pumpReader(
    tester,
    items: pictures(3),
    engines: engines,
    chrome: chromeWithMenu(),
    policy: policy,
    onDismissed: onDismissed,
    onItemShown: onItemShown,
  );

  Future<void> rightClick(WidgetTester tester, Offset at) async {
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pump();
  }

  group("the host's menu", () {
    testWidgets('opens on a right-click, with the actions for the file on '
        'screen', (tester) async {
      await pumpWithMenu(tester);

      await rightClick(tester, const Offset(300, 300));

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(told.single.item.name, 'a.jpg');
      expect(told.single.index, 0);
      // At the pointer.
      expect(tester.getTopLeft(find.text('Reply')).dx, greaterThan(300));
      expect(tester.getTopLeft(find.text('Reply')).dy, greaterThan(300));
    });

    testWidgets('an action chosen runs, and the menu is gone', (tester) async {
      await pumpWithMenu(tester);
      await rightClick(tester, const Offset(300, 300));

      await tester.tap(find.text('Reply'));
      await tester.pump();

      expect(pressed, ['Reply a.jpg']);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('follows the policy through the state it is told', (
      tester,
    ) async {
      await pumpWithMenu(
        tester,
        policy: const MediaReaderPolicy(canExport: false),
      );

      await rightClick(tester, const Offset(300, 300));

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
    });

    testWidgets('is for the file on screen now', (tester) async {
      await pumpWithMenu(tester);
      await swipeToNext(tester);

      await rightClick(tester, const Offset(300, 300));
      await tester.tap(find.text('Reply'));

      expect(pressed, ['Reply b.jpg']);
    });

    testWidgets('a tap elsewhere closes it, and reaches nothing below', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpWithMenu(tester, onDismissed: () => dismissed++);
      await rightClick(tester, const Offset(300, 300));

      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      expect(find.text('Reply'), findsNothing);
      expect(dismissed, 0);
      // The chrome was not toggled by that tap either.
      expect(engine.pages['a.jpg']!.chromeVisible.value, isTrue);
    });

    testWidgets('Esc closes it, and not the reader; the keys then page '
        'again', (tester) async {
      var dismissed = 0;
      await pumpWithMenu(tester, onDismissed: () => dismissed++);
      await rightClick(tester, const Offset(300, 300));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Reply'), findsNothing);
      expect(dismissed, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('fake:b.jpg'), findsOneWidget);
    });

    testWidgets('a right-click elsewhere moves it there', (tester) async {
      await pumpWithMenu(tester);
      await rightClick(tester, const Offset(300, 300));

      await rightClick(tester, const Offset(100, 100));

      expect(find.text('Reply'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Reply')).dy, lessThan(200));
    });

    testWidgets('paging away closes it', (tester) async {
      await pumpWithMenu(tester);
      await rightClick(tester, const Offset(300, 300));

      // The arrows are still the reader's.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(find.text('fake:b.jpg'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('a long press with a finger opens it above the finger', (
      tester,
    ) async {
      await pumpWithMenu(tester);

      await tester.longPressAt(const Offset(300, 400));
      await tester.pump();

      expect(find.text('Reply'), findsOneWidget);
      expect(tester.getBottomLeft(find.text('Share')).dy, lessThan(400));
    });

    testWidgets('a mouse held down does not open it', (tester) async {
      await pumpWithMenu(tester);

      final gesture = await tester.startGesture(
        const Offset(300, 400),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('stays within the reader near an edge', (tester) async {
      await pumpWithMenu(tester);

      await rightClick(tester, const Offset(790, 590));

      final menu = tester.getRect(find.text('Reply'));
      expect(menu.right, lessThan(800));
      expect(menu.bottom, lessThan(600));
    });

    testWidgets('without one, a right-click does nothing', (tester) async {
      await pumpReader(tester, items: pictures(3), engines: engines);

      await rightClick(tester, const Offset(300, 300));

      expect(find.text('Reply'), findsNothing);
      expect(engine.pages['a.jpg']!.chromeVisible.value, isTrue);
    });

    testWidgets('one with nothing in it shows nothing', (tester) async {
      await pumpReader(
        tester,
        items: pictures(3),
        engines: engines,
        chrome: MediaReaderChrome(menu: (context, state) => const []),
      );

      await rightClick(tester, const Offset(300, 300));

      expect(find.byType(Focus), findsWidgets);
      expect(find.bySemanticsLabel('Actions'), findsNothing);
    });

    testWidgets('is read as a menu of buttons', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWithMenu(tester);

      await rightClick(tester, const Offset(300, 300));

      expect(find.bySemanticsLabel('Actions'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Reply')),
        matchesSemantics(label: 'Reply', isButton: true, hasTapAction: true),
      );
      // What is under the menu is not read while it is up.
      expect(find.bySemanticsLabel('Close'), findsNothing);
      semantics.dispose();
    });

    testWidgets("an engine's own menu over text stands", (tester) async {
      await pumpReader(
        tester,
        items: [
          item(
            'a.txt',
            source: MediaReaderSource.bytes(
              Uint8List.fromList('hello there'.codeUnits),
            ),
          ),
        ],
        chrome: chromeWithMenu(),
      );
      await pumpUntil(
        tester,
        () => find.text('hello there').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();

      // A long press on a word is the text's: it selects the word.
      await tester.longPressAt(
        tester.getTopLeft(find.text('hello there')) + const Offset(12, 8),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
    });
  });
}
