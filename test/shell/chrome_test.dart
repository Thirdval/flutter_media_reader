import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/default_slots.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late FakeEngine engine;
  late MediaReaderEngines engines;
  setUp(() {
    engine = FakeEngine('fake', kinds: {MediaKind.picture});
    engines = MediaReaderEngines([engine]);
  });

  /// A chrome whose every slot says its own name, and what it was told.
  MediaReaderChrome hostChrome(Map<String, MediaReaderState> told) {
    MediaReaderSlotBuilder slot(String name) => (context, state) {
      told[name] = state;
      return Text(name);
    };
    return MediaReaderChrome(
      topStart: slot('top start'),
      topEnd: slot('top end'),
      bottomStart: slot('bottom start'),
      bottomEnd: slot('bottom end'),
      contextPill: slot('context pill'),
      status: slot('status'),
    );
  }

  group("the host's slots", () {
    testWidgets('every slot is built', (tester) async {
      final told = <String, MediaReaderState>{};

      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: hostChrome(told),
      );

      for (final name in [
        'top start',
        'top end',
        'bottom start',
        'bottom end',
        'context pill',
        'status',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
    });

    testWidgets('ride above the keyboard', (tester) async {
      // 800 by 600, the keyboard's 300 at the bottom.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);

      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: hostChrome({}),
      );

      expect(
        tester.getBottomLeft(find.text('bottom end')).dy,
        lessThanOrEqualTo(300),
      );
    });

    testWidgets('a slot is told the item on screen and its place', (
      tester,
    ) async {
      final told = <String, MediaReaderState>{};
      final items = [
        item('a.jpg', data: 'shared by Ruth'),
        item('b.jpg', data: 'shared by Boaz'),
      ];
      await pumpReader(
        tester,
        items: items,
        engines: engines,
        chrome: hostChrome(told),
        onDismissed: () {},
      );

      expect(told['top start']!.item, same(items[0]));
      expect(told['top start']!.item.data, 'shared by Ruth');
      expect(told['top start']!.index, 0);
      expect(told['top start']!.count, 2);
      expect(told['top end']!.close, isNotNull);

      await swipeToNext(tester);

      expect(told['top start']!.item.data, 'shared by Boaz');
      expect(told['bottom start']!.index, 1);
    });

    testWidgets('with export off, the chrome learns it', (tester) async {
      final told = <String, MediaReaderState>{};
      final chrome = MediaReaderChrome(
        bottomStart: (context, state) {
          told['bottom start'] = state;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Reply'),
              if (state.canExport) const Text('Share'),
            ],
          );
        },
      );

      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: chrome,
      );
      expect(find.text('Share'), findsOneWidget);

      // An admin turns downloads off while the reader is open.
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: chrome,
        policy: const MediaReaderPolicy(canExport: false),
      );

      expect(told['bottom start']!.canExport, isFalse);
      expect(find.text('Share'), findsNothing);
      expect(find.text('Reply'), findsOneWidget);
      expect(engine.pages['a.jpg']!.policy.canExport, isFalse);
    });

    testWidgets('a slot closes the reader through what it is told', (
      tester,
    ) async {
      var dismissed = 0;
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onDismissed: () => dismissed++,
        chrome: MediaReaderChrome(
          topEnd: (context, state) =>
              GestureDetector(onTap: state.close, child: const Text('Done')),
        ),
      );

      await tester.tap(find.text('Done'));

      expect(dismissed, 1);
    });

    testWidgets('slots inherit the chrome\'s colour for their text', (
      tester,
    ) async {
      const ink = Color(0xFF102030);
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: MediaReaderChrome(
          foreground: ink,
          bottomStart: (context, state) => const Text('Reply'),
        ),
      );

      final style = DefaultTextStyle.of(tester.element(find.text('Reply')));
      expect(style.style.color, ink);
      expect(style.style.decoration, TextDecoration.none);
    });
  });

  group('the plain defaults', () {
    Finder inTitle(String text) => find.descendant(
      of: find.byType(MediaReaderDefaultTitle),
      matching: find.text(text),
    );

    testWidgets('the top start names the file and its place', (tester) async {
      await pumpReader(
        tester,
        items: pictures(),
        initialIndex: 1,
        engines: engines,
      );

      expect(inTitle('b.jpg'), findsOneWidget);
      expect(inTitle('2 of 5'), findsOneWidget);
    });

    testWidgets('a lone file has no place to name', (tester) async {
      await pumpReader(tester, items: pictures(1), engines: engines);

      expect(inTitle('a.jpg'), findsOneWidget);
      expect(inTitle('1 of 1'), findsNothing);
    });

    testWidgets('the top end closes the reader', (tester) async {
      var dismissed = 0;
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onDismissed: () => dismissed++,
      );

      await tester.tap(find.byType(MediaReaderDefaultClose));

      expect(dismissed, 1);
    });

    testWidgets('a reader that cannot be dismissed has no close button', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(), engines: engines);

      expect(find.byType(MediaReaderDefaultClose), findsNothing);
    });

    testWidgets('the other slots are empty', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);

      expect(find.byType(MediaReaderDefaultStatus), findsNothing);
    });

    testWidgets("the host's words are used", (tester) async {
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: MediaReaderChrome(
          strings: MediaReaderStrings(
            position: (position, count) => '$position sur $count',
          ),
        ),
      );

      expect(inTitle('1 sur 5'), findsOneWidget);
    });
  });

  group("an engine's status", () {
    testWidgets('shows in the default pill', (tester) async {
      await pumpReader(tester, items: pictures(), engines: engines);

      engine.pages['a.jpg']!.status.value = '1 of 15';
      await tester.pump();
      expect(find.text('1 of 15'), findsOneWidget);

      engine.pages['a.jpg']!.status.value = null;
      await tester.pump();
      expect(find.byType(MediaReaderDefaultStatus), findsNothing);
    });

    testWidgets("reaches the host's slots", (tester) async {
      final told = <String, MediaReaderState>{};
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: hostChrome(told),
      );

      engine.pages['a.jpg']!.status.value = '0:42 / 3:10';
      await tester.pump();

      expect(told['status']!.status, '0:42 / 3:10');
    });

    testWidgets('is the status of the page on screen, not a neighbour\'s', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      engine.pages['a.jpg']!.status.value = 'first';
      engine.pages['b.jpg']!.status.value = 'second';
      await tester.pump();
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);

      await swipeToNext(tester);

      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    });

    testWidgets('that ticks rebuilds the slots, and no page', (tester) async {
      var slotBuilds = 0;
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        chrome: MediaReaderChrome(
          status: (context, state) {
            slotBuilds++;
            return Text(state.status ?? '');
          },
        ),
      );
      final pageBuilds = engine.builds;
      final before = slotBuilds;

      for (final second in [1, 2, 3]) {
        engine.pages['a.jpg']!.status.value = '0:0$second / 3:10';
        await tester.pump();
      }

      expect(find.text('0:03 / 3:10'), findsOneWidget);
      expect(slotBuilds, before + 3);
      expect(engine.builds, pageBuilds);
    });

    testWidgets('may be set while the engine builds', (tester) async {
      final eager = _EagerEngine();

      await pumpReader(
        tester,
        items: pictures(),
        engines: MediaReaderEngines([eager]),
      );
      expect(tester.takeException(), isNull);
      await tester.pump();

      expect(find.text('page 1'), findsOneWidget);
    });
  });

  group('a tap on the canvas', () {
    testWidgets('hides the chrome, and another brings it back', (tester) async {
      var dismissed = 0;
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onDismissed: () => dismissed++,
      );
      final page = engine.pages['a.jpg']!;
      final close = tester.getCenter(find.byType(MediaReaderDefaultClose));
      expect(page.chromeVisible.value, isTrue);

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      expect(page.chromeVisible.value, isFalse);

      // Hidden chrome takes no taps: this one reaches the canvas.
      await tester.tapAt(close);
      await tester.pumpAndSettle();
      expect(dismissed, 0);
      expect(page.chromeVisible.value, isTrue);

      await tester.tapAt(close);
      expect(dismissed, 1);
    });

    testWidgets('leaves the chrome showing for a screen reader', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      var dismissed = 0;
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onDismissed: () => dismissed++,
      );

      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MediaReaderDefaultClose));

      expect(dismissed, 1);
    });

    testWidgets('an engine that takes taps toggles the chrome itself', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(), engines: engines);
      final page = engine.pages['a.jpg']!;

      page.toggleChrome();
      await tester.pumpAndSettle();

      expect(page.chromeVisible.value, isFalse);
      // The chrome is one for the reader: a neighbour sees the same.
      expect(engine.pages['b.jpg']!.chromeVisible.value, isFalse);
    });
  });
}

/// Sets its status while building, as an engine that knows its page count
/// at once would.
class _EagerEngine() implements MediaReaderEngine {
  @override
  String get id => 'eager';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) => true;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) {
    page.status.value = 'page ${page.index + 1}';
    return const SizedBox.expand();
  }
}
