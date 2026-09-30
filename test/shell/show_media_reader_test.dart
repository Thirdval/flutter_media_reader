import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/default_slots.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  /// An app with one page, and the context to open the reader from.
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext host;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: Builder(
          builder: (context) {
            host = context;
            return const Center(child: Text('the conversation'));
          },
        ),
      ),
    );
    return host;
  }

  /// Opens the reader and says whether its future has completed.
  Future<bool Function()> open(
    WidgetTester tester, {
    int initialIndex = 0,
    ValueChanged<MediaReaderItem>? onItemShown,
  }) async {
    final host = await pumpHost(tester);
    var closed = false;
    unawaited(
      showMediaReader(
        host,
        items: [item('a.glb'), item('b.glb'), item('c.glb')],
        initialIndex: initialIndex,
        onItemShown: onItemShown,
      ).then((_) => closed = true),
    );
    await tester.pumpAndSettle();
    return () => closed;
  }

  group('showMediaReader', () {
    testWidgets('follows the items as the host changes them', (tester) async {
      final host = await pumpHost(tester);
      final live = ValueNotifier([item('a.glb'), item('b.glb')]);
      addTearDown(live.dispose);
      unawaited(showMediaReader(host, items: live.value, liveItems: live));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      live.value = [item('a.glb'), item('b.glb'), item('c.glb')];
      await tester.pumpAndSettle();

      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('opens the reader over the app, at the item asked for', (
      tester,
    ) async {
      final shown = <String>[];
      final closed = await open(
        tester,
        initialIndex: 1,
        onItemShown: (item) => shown.add(item.name),
      );

      expect(find.byType(MediaReaderView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MediaReaderDefaultTitle),
          matching: find.text('b.glb'),
        ),
        findsOneWidget,
      );
      expect(shown, ['b.glb']);
      expect(closed(), isFalse);
      // The page beneath is still there, to show through a dismissing drag.
      expect(find.text('the conversation'), findsOneWidget);
    });

    testWidgets('completes when the close button is pressed', (tester) async {
      final closed = await open(tester);

      await tester.tap(find.byType(MediaReaderDefaultClose));
      await tester.pumpAndSettle();

      expect(closed(), isTrue);
      expect(find.byType(MediaReaderView), findsNothing);
      expect(find.text('the conversation'), findsOneWidget);
    });

    testWidgets('completes on Esc', (tester) async {
      final closed = await open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closed(), isTrue);
      expect(find.byType(MediaReaderView), findsNothing);
    });

    testWidgets('completes on a drag down', (tester) async {
      final closed = await open(tester);

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(closed(), isTrue);
      expect(find.byType(MediaReaderView), findsNothing);
    });

    testWidgets("completes on the platform's back", (tester) async {
      final closed = await open(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(closed(), isTrue);
      expect(find.byType(MediaReaderView), findsNothing);
    });
  });
}
