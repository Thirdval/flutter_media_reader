import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/document_bar.dart';
import 'package:flutter_media_reader/src/shell/document_pages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_document.dart';
import '../support/fakes.dart';

void main() {
  /// The bar alone, 600 wide.
  Future<void> pumpBar(
    WidgetTester tester,
    FakeDocument document, {
    TextDirection textDirection = TextDirection.ltr,
  }) => tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => Directionality(
        textDirection: textDirection,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 600,
            child: MediaReaderDocumentBar(
              document: document,
              chrome: const MediaReaderChrome(),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  /// The search field, once the search is open.
  final field = find.byType(EditableText);

  group('MediaReaderDocumentBar', () {
    testWidgets('offers the pages and the search', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, FakeDocument());

      expect(find.bySemanticsLabel('Pages'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      expect(find.byType(MediaReaderDocumentPages), findsNothing);
      expect(field, findsNothing);
      semantics.dispose();
    });

    testWidgets('runs left to right in a right-to-left language', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, FakeDocument(), textDirection: TextDirection.rtl);

      expect(
        tester.getCenter(find.bySemanticsLabel('Pages')).dx,
        lessThan(tester.getCenter(find.bySemanticsLabel('Search')).dx),
      );
      semantics.dispose();
    });
  });

  group('the strip of pages', () {
    testWidgets('draws the pages small, and marks the one on screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, FakeDocument(pageNumber: 2));

      await tapButton(tester, 'Pages');

      expect(find.byKey(const ValueKey('thumbnail-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('thumbnail-2')), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Page 2')),
        isSemantics(label: 'Page 2', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Page 1')),
        isSemantics(
          label: 'Page 1',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
        ),
      );
      expect(find.text('2 of 12'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('builds only the pages in view, from the one on screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, FakeDocument(pageCount: 300, pageNumber: 150));

      await tapButton(tester, 'Pages');

      expect(find.byKey(const ValueKey('thumbnail-150')), findsOneWidget);
      expect(find.byKey(const ValueKey('thumbnail-1')), findsNothing);
      expect(find.byKey(const ValueKey('thumbnail-300')), findsNothing);
      semantics.dispose();
    });

    testWidgets('a tap on a page goes to it', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument();
      await pumpBar(tester, document);
      await tapButton(tester, 'Pages');

      await tapButton(tester, 'Page 4');

      expect(document.wentTo, [4]);
      expect(find.text('4 of 12'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a number typed goes to that page', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument();
      await pumpBar(tester, document);
      await tapButton(tester, 'Pages');

      await tester.enterText(field, '9');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(document.wentTo, [9]);
      // The field is empty again, for the next number.
      expect(tester.widget<EditableText>(field).controller.text, isEmpty);
      semantics.dispose();
    });

    testWidgets('takes digits only', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument();
      await pumpBar(tester, document);
      await tapButton(tester, 'Pages');

      await tester.enterText(field, 'p. 7x');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();

      expect(document.wentTo, [7]);
      semantics.dispose();
    });

    testWidgets('follows the page on screen', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument(pageCount: 300);
      await pumpBar(tester, document);
      await tapButton(tester, 'Pages');
      expect(find.byKey(const ValueKey('thumbnail-200')), findsNothing);

      document.scrolledTo(200);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('thumbnail-200')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('closes with its button', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, FakeDocument());
      await tapButton(tester, 'Pages');

      await tapButton(tester, 'Pages');

      expect(find.byType(MediaReaderDocumentPages), findsNothing);
      semantics.dispose();
    });
  });

  group('the search', () {
    testWidgets('searches as its field is typed into', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument(found: {'harvest': 3});
      await pumpBar(tester, document);

      await tapButton(tester, 'Search');
      expect(find.text('Search in this file'), findsOneWidget);
      await tester.enterText(field, 'harvest');
      await tester.pumpAndSettle();

      expect(document.searches, ['harvest']);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Search in this file'), findsNothing);
      semantics.dispose();
    });

    testWidgets('steps through the matches, round and round', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument(found: {'harvest': 3});
      await pumpBar(tester, document);
      await tapButton(tester, 'Search');
      await tester.enterText(field, 'harvest');
      await tester.pumpAndSettle();

      await tapButton(tester, 'Next match');
      expect(find.text('2 of 3'), findsOneWidget);

      await tapButton(tester, 'Previous match');
      await tapButton(tester, 'Previous match');
      expect(find.text('3 of 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('Enter goes to the next match', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument(found: {'harvest': 3});
      await pumpBar(tester, document);
      await tapButton(tester, 'Search');
      await tester.enterText(field, 'harvest');

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('2 of 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('says when nothing matches', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument();
      await pumpBar(tester, document);
      await tapButton(tester, 'Search');

      await tester.enterText(field, 'easter');
      await tester.pumpAndSettle();

      expect(find.text('No matches'), findsOneWidget);
      // Nothing to step through.
      await tapButton(tester, 'Next match');
      expect(find.text('No matches'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('ends with its close button', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument(found: {'harvest': 3});
      await pumpBar(tester, document);
      await tapButton(tester, 'Search');
      await tester.enterText(field, 'harvest');
      await tester.pumpAndSettle();

      await tapButton(tester, 'Close search');

      expect(document.searches, ['harvest', '']);
      expect(field, findsNothing);
      expect(find.bySemanticsLabel('Pages'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets("another document on screen ends the last one's search", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final first = FakeDocument(found: {'harvest': 3});
      await pumpBar(tester, first);
      await tapButton(tester, 'Search');
      await tester.enterText(field, 'harvest');
      await tester.pumpAndSettle();

      await pumpBar(tester, FakeDocument());
      await tester.pumpAndSettle();

      expect(first.searches.last, isEmpty);
      expect(field, findsNothing);
      semantics.dispose();
    });
  });

  group('in the reader', () {
    late FakeDocument document;
    late int dismissed;
    setUp(() {
      document = FakeDocument(found: {'harvest': 3});
      dismissed = 0;
    });

    Future<void> pumpDocuments(WidgetTester tester) => pumpReader(
      tester,
      items: [item('a.pdf'), item('b.pdf')],
      engines: MediaReaderEngines([DocumentEngine(document)]),
      onDismissed: () => dismissed++,
    );

    testWidgets('the bar is the default controls of a page with a document', (
      tester,
    ) async {
      await pumpDocuments(tester);
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderDocumentBar), findsOneWidget);
    });

    testWidgets("a host's controls are told the document", (tester) async {
      MediaReaderDocument? told;
      await pumpReader(
        tester,
        items: [item('a.pdf')],
        engines: MediaReaderEngines([DocumentEngine(document)]),
        chrome: MediaReaderChrome(
          controls: (context, state) {
            told = state.document;
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(told, same(document));
      expect(find.byType(MediaReaderDocumentBar), findsNothing);
    });

    testWidgets('Esc ends the search before it closes the reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpDocuments(tester);
      await tester.pumpAndSettle();
      await tapButton(tester, 'Search');
      await tester.enterText(field, 'harvest');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(dismissed, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dismissed, 1);
      semantics.dispose();
    });

    testWidgets(
      'on a Mac, the field hands up Esc as a dismiss: the search ends',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpDocuments(tester);
        await tester.pumpAndSettle();
        await tapButton(tester, 'Search');
        await tester.enterText(field, 'harvest');
        await tester.pumpAndSettle();

        // What the platform's cancelOperation: selector turns into.
        Actions.maybeInvoke(primaryFocus!.context!, const DismissIntent());
        await tester.pumpAndSettle();
        expect(field, findsNothing);
        expect(dismissed, 0);
        semantics.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('the arrows move in the field: they do not change the file', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpDocuments(tester);
      await tester.pumpAndSettle();
      await tapButton(tester, 'Search');
      await tester.enterText(field, 'harvest');
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('document:a.pdf'), findsOneWidget);
      semantics.dispose();
    });
  });
}
