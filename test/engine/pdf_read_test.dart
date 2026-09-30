import 'package:flutter/gestures.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/text_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../support/fakes.dart';
import '../support/pdf.dart';

void main() {
  setUpAll(setUpPdfium);

  late WatchedEngine engine;
  setUp(() => engine = WatchedEngine(const MediaReaderPdfEngine()));

  /// Three pages; "harvest" is on the first and the third, twice there.
  final rota = pdfOf(
    3,
    link: Uri.parse('https://tendvine.example/rota'),
    lines: (page) => switch (page) {
      1 => ['The rota online', 'Harvest supper: Ruth'],
      2 => ['Welcome: Daniel', 'Sound: Miriam'],
      _ => ['Harvest festival', 'After the harvest: tea'],
    },
  );

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  /// The reader on the rota, open at its first page; the page the engine
  /// was handed.
  Future<MediaReaderPage> pumpRota(
    WidgetTester tester, {
    List<MediaReaderItem> after = const [],
    ValueChanged<Uri>? onLink,
    VoidCallback? onDismissed,
    MediaReaderPolicy policy = const MediaReaderPolicy(),
    MediaReaderChrome chrome = const MediaReaderChrome(),
  }) async {
    await pumpReader(
      tester,
      items: [
        MediaReaderItem(
          id: 'rota',
          name: 'Rota.pdf',
          source: MediaReaderSource.bytes(rota),
        ),
        ...after,
      ],
      engines: MediaReaderEngines([engine]),
      onLink: onLink,
      onDismissed: onDismissed,
      policy: policy,
      chrome: chrome,
    );
    await pumpPdf(tester, () => shows('1 of 3'));
    await settlePdf(tester);
    return engine.pages['rota']!;
  }

  PdfViewerController controller(WidgetTester tester) =>
      tester.widget<PdfViewer>(find.byType(PdfViewer)).controller!;

  group('the chrome', () {
    testWidgets('is told the document, and follows the page on screen', (
      tester,
    ) async {
      final page = await pumpRota(tester);
      final document = page.document.value!;
      expect(document.state.value.pageCount, 3);
      expect(document.state.value.pageNumber, 1);

      // Going to a page is animated: it ends as frames are drawn.
      unawaited(document.goToPage(3));
      await pumpPdf(tester, () => shows('3 of 3'));

      expect(document.state.value.pageNumber, 3);
      await settlePdf(tester);
    });

    testWidgets('goes no further than the last page', (tester) async {
      final page = await pumpRota(tester);

      unawaited(page.document.value!.goToPage(40));
      await pumpPdf(tester, () => shows('3 of 3'));
      await settlePdf(tester);
    });

    testWidgets('gets a page drawn small for its strip', (tester) async {
      final page = await pumpRota(tester);

      final thumbnail = page.document.value!.thumbnail(
        tester.element(find.byType(PdfViewer)),
        2,
      );

      expect(thumbnail, isA<PdfPageView>());
      expect((thumbnail as PdfPageView).pageNumber, 2);
    });

    testWidgets('shows its plain bar for the document', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpRota(tester);

      expect(find.bySemanticsLabel('Pages'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('clear of the chrome', () {
    /// How far down the view [page] (from 1) starts, in pixels, less the
    /// margin the viewer puts around every page.
    double topOf(WidgetTester tester, int page) {
      final view = controller(tester);
      final top = view.layout.pageLayouts[page - 1].top - view.params.margin;
      return (top - view.visibleRect.top) * view.currentZoom;
    }

    testWidgets('the first page starts below the top slots, and the last '
        'ends above the bottom ones', (tester) async {
      await pumpRota(tester);
      final view = controller(tester);

      // The plain chrome's row at the top, and its bars at the bottom.
      expect(topOf(tester, 1), closeTo(56, 0.5));
      final below =
          view.documentSize.height -
          view.layout.pageLayouts.last.bottom -
          view.params.margin;
      expect(below * view.currentZoom, closeTo(108, 0.5));
    });

    testWidgets('a page gone to starts below the top slots too', (
      tester,
    ) async {
      final page = await pumpRota(tester);

      unawaited(page.document.value!.goToPage(2));
      await pumpPdf(tester, () => shows('2 of 3'));
      await settlePdf(tester, 5);

      expect(topOf(tester, 2), closeTo(56, 1));
    });

    testWidgets("a host's taller slots, and the screen's own edges, are "
        'kept clear as well', (tester) async {
      // A notch of 40 pixels.
      tester.view.padding = FakeViewPadding(
        top: 40 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);

      await pumpRota(
        tester,
        chrome: const MediaReaderChrome(
          contentInsets: EdgeInsets.only(top: 100, bottom: 20),
        ),
      );

      expect(topOf(tester, 1), closeTo(140, 0.5));
    });
  });

  group('searching', () {
    testWidgets('finds the text, and goes from match to match', (tester) async {
      final page = await pumpRota(tester);
      final document = page.document.value!..search('harvest');

      await pumpPdf(
        tester,
        () =>
            document.state.value.matchCount == 3 &&
            !document.state.value.searching,
      );
      expect(document.state.value.query, 'harvest');
      expect(document.state.value.matchNumber, 1);

      unawaited(document.nextMatch());
      await pumpPdf(tester, () => document.state.value.matchNumber == 2);
      await pumpPdf(tester, () => shows('3 of 3'));

      unawaited(document.previousMatch());
      await pumpPdf(tester, () => document.state.value.matchNumber == 1);
      await pumpPdf(tester, () => shows('1 of 3'));
      await settlePdf(tester);
    });

    testWidgets('says when there is nothing to find, and ends', (tester) async {
      final page = await pumpRota(tester);
      final document = page.document.value!..search('easter');

      await pumpPdf(
        tester,
        () =>
            document.state.value.query == 'easter' &&
            !document.state.value.searching,
      );
      expect(document.state.value.matchCount, 0);
      expect(document.state.value.matchNumber, 0);

      document.search('');
      await settlePdf(tester, 3);
      expect(document.state.value.query, isEmpty);
      expect(document.state.value.searching, isFalse);
    });
  });

  group('gestures', () {
    testWidgets('a tap hides the chrome, and another brings it back', (
      tester,
    ) async {
      final page = await pumpRota(tester);

      await tester.tapAt(const Offset(400, 450));
      await settlePdf(tester, 5);
      expect(page.chromeVisible.value, isFalse);

      await tester.tapAt(const Offset(400, 450));
      await settlePdf(tester, 5);
      expect(page.chromeVisible.value, isTrue);
    });

    testWidgets('a double tap magnifies: the page then takes sideways '
        'drags; another fits it to its width again', (tester) async {
      final page = await pumpRota(tester);
      final fit = controller(tester).currentZoom;
      expect(page.holdsPaging.value, isFalse);

      Future<void> doubleTap() async {
        await tester.tapAt(const Offset(400, 300));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(const Offset(400, 300));
        await settlePdf(tester, 8);
      }

      await doubleTap();
      expect(controller(tester).currentZoom, closeTo(fit * 2.5, 0.01));
      expect(page.holdsPaging.value, isTrue);

      await doubleTap();
      expect(controller(tester).currentZoom, closeTo(fit, 0.01));
      expect(page.holdsPaging.value, isFalse);
    });

    testWidgets('a drag down scrolls the pages: it does not dismiss', (
      tester,
    ) async {
      var dismissed = 0;
      final page = await pumpRota(tester, onDismissed: () => dismissed++);
      expect(page.holdsDismiss.value, isTrue);

      await tester.drag(find.byType(PdfViewer), const Offset(0, 400));
      await settlePdf(tester, 5);

      expect(dismissed, 0);
    });

    testWidgets('a drag up scrolls to the next page', (tester) async {
      await pumpRota(tester);

      await tester.timedDrag(
        find.byType(PdfViewer),
        const Offset(0, -500),
        const Duration(milliseconds: 300),
      );
      await tester.timedDrag(
        find.byType(PdfViewer),
        const Offset(0, -500),
        const Duration(milliseconds: 300),
      );

      await pumpPdf(tester, () => shows('2 of 3') || shows('3 of 3'));
      await settlePdf(tester);
    });

    testWidgets('a drag sideways goes to the next file', (tester) async {
      await pumpRota(tester, after: [item('b.glb')]);

      await tester.timedDrag(
        find.byType(PdfViewer),
        const Offset(-500, 0),
        const Duration(milliseconds: 300),
      );
      await settlePdf(tester, 8);

      expect(find.text('2 of 2'), findsOneWidget);
    });
  });

  group('the keyboard', () {
    testWidgets('the sideways arrows go between files while the page fits '
        'its width', (tester) async {
      await pumpRota(tester, after: [item('b.glb')]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settlePdf(tester, 8);

      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('Page Down goes through the pages', (tester) async {
      await pumpRota(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);

      await pumpPdf(tester, () => shows('2 of 3'));
      await settlePdf(tester);
    });
  });

  group('links', () {
    /// Where the rota's first line, a link, is on screen.
    Offset linkOf(WidgetTester tester) {
      final view = controller(tester);
      // The link's middle on its page, in points from the page's top.
      const onPage = Offset(236, 792 - 707);
      final page = view.layout.pageLayouts.first;
      return tester.getTopLeft(find.byType(PdfViewer)) +
          (page.topLeft + onPage - view.visibleRect.topLeft) * view.currentZoom;
    }

    testWidgets('a link out of the document is handed to the host', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpRota(tester, onLink: opened.add);

      await tester.tapAt(linkOf(tester));
      await settlePdf(tester, 5);

      expect(opened, [Uri.parse('https://tendvine.example/rota')]);
    });

    testWidgets('without a host to hand it to, a link does nothing', (
      tester,
    ) async {
      final page = await pumpRota(tester);
      expect(page.opensLinks, isFalse);

      await tester.tapAt(linkOf(tester));
      await settlePdf(tester, 5);

      expect(tester.takeException(), isNull);
      expect(find.byType(PdfViewer), findsOneWidget);
    });
  });

  group('selected text', () {
    late List<String> copied;
    setUp(() {
      copied = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final data = call.arguments as Map<Object?, Object?>;
              copied.add(data['text']! as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
    });

    testWidgets('has a menu of Select all and Copy, and no more', (
      tester,
    ) async {
      await pumpRota(tester);
      final text = controller(tester).textSelectionDelegate;

      /// A secondary click on the bare page, and what the menu offers.
      Future<List<String>> menu() async {
        await tester.tapAt(
          const Offset(400, 450),
          buttons: kSecondaryButton,
          kind: PointerDeviceKind.mouse,
        );
        await pumpPdf(
          tester,
          () => find.byType(MediaReaderTextMenu).evaluate().isNotEmpty,
        );
        return [
          for (final action
              in tester
                  .widget<MediaReaderTextMenu>(find.byType(MediaReaderTextMenu))
                  .actions)
            action.label,
        ];
      }

      expect(await menu(), ['Select all']);

      await tester.tap(find.text('Select all'));
      await pumpPdf(tester, () => text.hasSelectedText);

      expect(await menu(), ['Copy']);
      await settlePdf(tester, 3);
    });

    testWidgets('is copied, with export off too: copying is not an export', (
      tester,
    ) async {
      await pumpRota(tester, policy: const MediaReaderPolicy(canExport: false));
      final text = controller(tester).textSelectionDelegate;

      unawaited(text.selectAllText());
      await pumpPdf(tester, () => text.hasSelectedText);
      await tester.tapAt(
        const Offset(400, 450),
        buttons: kSecondaryButton,
        kind: PointerDeviceKind.mouse,
      );
      await pumpPdf(tester, () => shows('Copy'));
      await tester.tap(find.text('Copy'));
      await pumpPdf(tester, () => copied.isNotEmpty);

      expect(copied.single, contains('Harvest supper: Ruth'));
      expect(copied.single, contains('After the harvest: tea'));
      // The menu goes once the text is copied.
      await settlePdf(tester, 3);
      expect(find.byType(MediaReaderTextMenu), findsNothing);
    });
  });
}
