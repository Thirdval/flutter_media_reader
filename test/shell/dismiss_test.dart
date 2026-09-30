import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/dismissible.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late FakeEngine engine;
  late MediaReaderEngines engines;
  late int dismissed;
  setUp(() {
    engine = FakeEngine('fake', kinds: {MediaKind.picture});
    engines = MediaReaderEngines([engine]);
    dismissed = 0;
  });

  Future<void> pump(WidgetTester tester, {bool dismissible = true}) =>
      pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onDismissed: dismissible ? () => dismissed++ : null,
      );

  /// How far down the canvas has been dragged.
  double offset(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(MediaReaderDismissible),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform
      .getTranslation()
      .y;

  /// How much of the canvas's colour is left.
  double canvas(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(MediaReaderView),
              matching: find.byType(ColoredBox),
            )
            .first,
      )
      .color
      .a;

  group('a drag down', () {
    testWidgets('dismisses once it is long enough', (tester) async {
      await pump(tester);

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pump();

      expect(dismissed, 1);
    });

    testWidgets('moves the canvas and fades the reader as it goes', (
      tester,
    ) async {
      await pump(tester);
      expect(canvas(tester), 1);

      final gesture = await tester.startGesture(const Offset(400, 200));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 140));
      await tester.pump();

      expect(offset(tester), greaterThan(100));
      expect(canvas(tester), inExclusiveRange(0, 1));
      expect(dismissed, 0);

      await gesture.up();
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('fades the chrome without rebuilding its slots', (
      tester,
    ) async {
      var slotBuilds = 0;
      await pumpReader(
        tester,
        items: pictures(),
        engines: engines,
        onDismissed: () => dismissed++,
        chrome: MediaReaderChrome(
          bottomStart: (context, state) {
            slotBuilds++;
            return const Text('Reply');
          },
        ),
      );
      final before = slotBuilds;
      final pageBuilds = engine.builds;

      final gesture = await tester.startGesture(const Offset(400, 200));
      for (var step = 0; step < 5; step++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();
      }

      final fade = tester.widget<Opacity>(
        find.ancestor(of: find.text('Reply'), matching: find.byType(Opacity)),
      );
      expect(fade.opacity, inExclusiveRange(0, 1));
      expect(slotBuilds, before);
      expect(engine.builds, pageBuilds);
      await gesture.up();
    });

    testWidgets('settles back when it is short', (tester) async {
      await pump(tester);

      await tester.drag(find.byType(PageView), const Offset(0, 80));
      await tester.pumpAndSettle();

      expect(dismissed, 0);
      expect(offset(tester), 0);
      expect(canvas(tester), 1);
    });

    testWidgets('dismisses when it is short but fast', (tester) async {
      await pump(tester);

      await tester.fling(find.byType(PageView), const Offset(0, 80), 2000);
      await tester.pump();

      expect(dismissed, 1);
    });

    testWidgets('upwards does nothing', (tester) async {
      await pump(tester);

      await tester.drag(find.byType(PageView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(dismissed, 0);
      expect(offset(tester), 0);
    });

    testWidgets('does nothing where the reader cannot be dismissed', (
      tester,
    ) async {
      await pump(tester, dismissible: false);

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(offset(tester), 0);
    });

    testWidgets('is left to an engine that holds downward drags', (
      tester,
    ) async {
      await pump(tester);

      engine.pages['a.jpg']!.holdsDismiss.value = true;
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(dismissed, 0);
      expect(offset(tester), 0);

      engine.pages['a.jpg']!.holdsDismiss.value = false;
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('with a mouse does not dismiss: a mouse does not drag pages', (
      tester,
    ) async {
      await pump(tester);

      await tester.drag(
        find.byType(PageView),
        const Offset(0, 300),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(dismissed, 0);
    });

    testWidgets('returns the canvas when the host keeps the reader', (
      tester,
    ) async {
      await pump(tester);

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pump();
      expect(dismissed, 1);
      expect(offset(tester), greaterThan(0));

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(offset(tester), 0);
      expect(canvas(tester), 1);
    });
  });

  group('Esc', () {
    testWidgets('dismisses', (tester) async {
      await pump(tester);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(dismissed, 1);
    });

    testWidgets('is left to the host where the reader cannot be dismissed', (
      tester,
    ) async {
      await pump(tester, dismissible: false);
      await tester.pump();

      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.escape);

      expect(handled, isFalse);
    });
  });
}
