import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_document.dart';
import '../support/fake_video.dart';
import '../support/fakes.dart';

/// The plain chrome at twice the text size on a small phone (R8): nothing
/// overflows, and everything can still be pressed.
void main() {
  /// A small phone, 320 by 568, with the text at 200 %.
  Future<void> pumpScaled(
    WidgetTester tester, {
    required List<MediaReaderItem> items,
    required MediaReaderEngines engines,
    MediaReaderChrome chrome = const MediaReaderChrome(),
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpReader(
      tester,
      items: items,
      engines: engines,
      chrome: chrome,
      onDismissed: () {},
    );
  }

  testWidgets('the title, the status and the close button', (tester) async {
    final semantics = tester.ensureSemantics();
    final engine = FakeEngine('fake', kinds: {MediaKind.picture});
    await pumpScaled(
      tester,
      items: [
        item('A rather long name for a picture of the harvest supper.jpg'),
        item('b.jpg'),
      ],
      engines: MediaReaderEngines([engine]),
    );
    engine.pages.values.first.status.value = '1,234 of 5,678';
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1,234 of 5,678'), findsOneWidget);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the transport', (tester) async {
    final semantics = tester.ensureSemantics();
    final engine = FakeEngine('fake', kinds: {MediaKind.video});
    await pumpScaled(
      tester,
      items: [item('a.mp4')],
      engines: MediaReaderEngines([engine]),
    );
    engine.pages['a.mp4']!.playback.value = FakePlayback(
      const MediaReaderPlaybackState(
        position: Duration(hours: 1, minutes: 23, seconds: 45),
        duration: Duration(hours: 2, minutes: 34, seconds: 56),
        speed: 1.5,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1:23:45'), findsOneWidget);
    expect(find.text('1.5×'), findsOneWidget);
    expect(find.bySemanticsLabel('Play'), findsOneWidget);
    expect(find.bySemanticsLabel('Mute'), findsOneWidget);
    // Narrow, the scrubber has a row of its own above the buttons.
    expect(
      tester.getBottomLeft(find.bySemanticsLabel('Position')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.bySemanticsLabel('Play')).dy),
    );
    semantics.dispose();
  });

  testWidgets('the document bar, its pages and its search', (tester) async {
    final semantics = tester.ensureSemantics();
    final document = FakeDocument(
      pageCount: 300,
      pageNumber: 150,
      found: const {'harvest': 12345},
    );
    await pumpScaled(
      tester,
      items: [item('a.pdf')],
      engines: MediaReaderEngines([DocumentEngine(document)]),
    );
    // The bar comes a frame after the document.
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Pages'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('150'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'harvest');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 of 12345'), findsOneWidget);
    expect(find.bySemanticsLabel('Next match'), findsOneWidget);
    // Narrow, the count and the arrows go under the field.
    expect(
      tester.getTopLeft(find.text('1 of 12345')).dy,
      greaterThan(tester.getBottomLeft(find.byType(EditableText)).dy),
    );
    semantics.dispose();
  });

  testWidgets('the card', (tester) async {
    await pumpScaled(
      tester,
      items: [
        item(
          'A rather long name for a file nobody can open here.glb',
          size: 123456789,
        ),
      ],
      engines: MediaReaderEngines.standard,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('This file cannot be shown here.'), findsOneWidget);
  });
}
