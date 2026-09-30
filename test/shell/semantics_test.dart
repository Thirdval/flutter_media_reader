import 'package:flutter/rendering.dart';
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

  /// What the reader has announced, in order.
  List<String> announcements(WidgetTester tester) {
    final said = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (Object? message) async {
        if (message case {
          'type': 'announce',
          'data': {'message': final String text},
        }) {
          said.add(text);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    return said;
  }

  /// The first thing a node says, itself or through what is in it.
  String firstLabel(SemanticsNode node) {
    if (node.label.isNotEmpty) return node.label.split('\n').first;
    return node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .map(firstLabel)
        .firstWhere((label) => label.isNotEmpty, orElse: () => '');
  }

  group('semantics', () {
    testWidgets('each page says its file and its place', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(tester, items: pictures(3), engines: engines);

      expect(find.bySemanticsLabel(RegExp('a.jpg, 1 of 3')), findsOneWidget);

      await swipeToNext(tester);

      expect(find.bySemanticsLabel(RegExp('b.jpg, 2 of 3')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a page is announced when it comes on screen', (tester) async {
      final said = announcements(tester);
      await pumpReader(tester, items: pictures(3), engines: engines);
      await tester.pump();
      // Opening announces nothing: the platform speaks for a new screen.
      expect(said, isEmpty);

      await swipeToNext(tester);
      await swipeToNext(tester);

      expect(said, ['b.jpg, 2 of 3', 'c.jpg, 3 of 3']);
    });

    testWidgets("the announcement is in the host's words", (tester) async {
      final said = announcements(tester);
      await pumpReader(
        tester,
        items: pictures(3),
        engines: engines,
        chrome: MediaReaderChrome(
          strings: MediaReaderStrings(
            page: (name, position, count) => '$name, $position sur $count',
          ),
        ),
      );

      await swipeToNext(tester);

      expect(said, ['b.jpg, 2 sur 3']);
    });

    testWidgets('the slots and the page come in reading order', (tester) async {
      final semantics = tester.ensureSemantics();
      MediaReaderSlotBuilder slot(String name) =>
          (context, state) => Text(name);
      await pumpReader(
        tester,
        items: pictures(1),
        engines: engines,
        chrome: MediaReaderChrome(
          topStart: slot('who shared it'),
          topEnd: slot('close'),
          bottomStart: slot('reply and forward'),
          bottomEnd: slot('more'),
          contextPill: slot('shared in #general'),
          status: slot('1 of 15'),
        ),
      );

      // The reader's own node: the first in it that names its children.
      final reader = tester.getSemantics(
        find
            .descendant(
              of: find.byType(MediaReaderView),
              matching: find.byWidgetPredicate(
                (widget) => widget is Semantics && widget.explicitChildNodes,
              ),
            )
            .first,
      );
      final order = [
        for (final node in reader.debugListChildrenInOrder(
          DebugSemanticsDumpOrder.traversalOrder,
        ))
          firstLabel(node),
      ];

      expect(order, [
        'who shared it',
        'close',
        'a.jpg',
        '1 of 15',
        'shared in #general',
        'reply and forward',
        'more',
      ]);
      semantics.dispose();
    });

    testWidgets('the default close button is a button with a name', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(
        tester,
        items: pictures(1),
        engines: engines,
        onDismissed: () {},
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Close')),
        isSemantics(label: 'Close', isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });
  });
}
