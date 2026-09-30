/// Runs the example on a device, for the platform matrix of
/// MEDIA_READER_PLAN.md §5:
///
///     cd example && fvm flutter test integration_test -d <device>
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpExample(WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
  }

  /// Opens the sample named [name], scrolling the list to it first.
  Future<void> open(WidgetTester tester, String name) async {
    await tester.scrollUntilVisible(
      find.text(name),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The scroll lands in the next frame; the tap is aimed after it.
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('a file opens as its card, pages, and closes', (tester) async {
    await pumpExample(tester);

    await open(tester, 'Rota_October.pdf');

    expect(find.byType(MediaReaderView), findsOneWidget);
    expect(find.text('PDF · 258 KB'), findsOneWidget);
    expect(find.text('Save to device'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);

    // Most of a page's width, whatever the device's: on to the next file.
    final width = tester.getSize(find.byType(PageView)).width;
    await tester.drag(find.byType(PageView), Offset(-width * 0.6, 0));
    await tester.pumpAndSettle();
    expect(find.text('Document · 57 KB'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MediaReaderView), findsNothing);
  });

  testWidgets('with saving off, the host shows no export action', (
    tester,
  ) async {
    await pumpExample(tester);

    await tester.tap(find.text('Members can save and share files'));
    await tester.pumpAndSettle();
    await open(tester, 'model.glb');

    expect(find.text('File · 7 MB'), findsOneWidget);
    expect(find.text('Save to device'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Reply'), findsOneWidget);
  });

  testWidgets('the plain defaults close the reader', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpExample(tester);

    await tester.tap(find.text("The host's chrome"));
    await tester.pumpAndSettle();
    await open(tester, 'harvest_supper.jpg');
    expect(find.text('1 of 10'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaReaderView), findsNothing);
    semantics.dispose();
  });

  testWidgets('a drag down closes the reader', (tester) async {
    await pumpExample(tester);
    await open(tester, 'baptism.mp4');

    final height = tester.getSize(find.byType(PageView)).height;
    await tester.drag(find.byType(PageView), Offset(0, height * 0.5));
    await tester.pumpAndSettle();

    expect(find.byType(MediaReaderView), findsNothing);
  });
}
