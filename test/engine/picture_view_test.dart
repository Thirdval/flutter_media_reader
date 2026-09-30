import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/plain_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const centre = Offset(400, 300);

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  /// The decoded picture on screen; null while it is on the way.
  ui.Image? shown(WidgetTester tester) => tester
      .widgetList<RawImage>(find.byType(RawImage))
      .map((raw) => raw.image)
      .nonNulls
      .firstOrNull;

  Matrix4 transformOf(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value;

  double scaleOf(WidgetTester tester) =>
      transformOf(tester).getMaxScaleOnAxis();

  /// Three pictures in memory, and the reader open on the first.
  Future<List<MediaReaderItem>> pumpPictures(
    WidgetTester tester, {
    VoidCallback? onDismissed,
    ValueChanged<MediaReaderItem>? onItemShown,
    double? touchSlop,
  }) async {
    final png = await pngOf(tester, 40, 30);
    final items = [
      for (final name in ['a.png', 'b.png', 'c.png'])
        item(name, source: MediaReaderSource.bytes(png)),
    ];
    await pumpReader(
      tester,
      items: items,
      onDismissed: onDismissed,
      onItemShown: onItemShown,
      touchSlop: touchSlop,
    );
    await pumpUntil(tester, () => shown(tester) != null);
    return items;
  }

  Future<void> doubleTap(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(at);
    await tester.pumpAndSettle();
  }

  MediaReaderPage pageOf(WidgetTester tester) {
    late MediaReaderPage page;
    // The engine's widget carries its page.
    tester.element(find.byType(InteractiveViewer)).visitAncestorElements((
      element,
    ) {
      final widget = element.widget;
      if (widget.runtimeType.toString() != 'MediaReaderPictureView') {
        return true;
      }
      page = (widget as dynamic).page as MediaReaderPage;
      return false;
    });
    return page;
  }

  group('loading', () {
    testWidgets('a picture in memory is shown', (tester) async {
      await pumpPictures(tester);

      expect(shown(tester), isNotNull);
      expect(find.byType(MediaReaderBusy), findsNothing);
    });

    testWidgets('a picture in a file is shown', (tester) async {
      final png = await pngOf(tester, 40, 30);
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('media_reader_test'),
      );
      addTearDown(() => directory!.deleteSync(recursive: true));
      final file = File('${directory!.path}/a.png')..writeAsBytesSync(png);

      await pumpReader(
        tester,
        items: [item('a.png', source: MediaReaderSource.file(file.path))],
      );
      await pumpUntil(tester, () => shown(tester) != null);

      expect(shown(tester), isNotNull);
    });

    testWidgets('the poster shows until the first frame', (tester) async {
      final png = await pngOf(tester, 40, 30);
      await pumpReader(
        tester,
        items: [
          MediaReaderItem(
            id: 'a',
            name: 'a.png',
            source: MediaReaderSource.bytes(png),
            poster: (context) => const Text('a blurred poster'),
          ),
        ],
      );

      expect(find.text('a blurred poster'), findsOneWidget);
      expect(find.byType(MediaReaderBusy), findsOneWidget);

      await pumpUntil(tester, () => shown(tester) != null);

      expect(find.text('a blurred poster'), findsNothing);
      expect(find.byType(MediaReaderBusy), findsNothing);
    });

    testWidgets('a large picture is decoded at the size of the screen', (
      tester,
    ) async {
      // 12 megapixels on a screen of 800 by 600 at three pixels a point.
      final png = await pngOf(tester, 4000, 3000);
      await pumpReader(
        tester,
        items: [item('a.png', source: MediaReaderSource.bytes(png))],
      );
      await pumpUntil(tester, () => shown(tester) != null);

      final image = shown(tester)!;
      expect(image.width, 2400);
      expect(image.height, 1800);
    });

    testWidgets('a picture is never decoded past the cap, however far it is '
        'zoomed', (tester) async {
      final png = await pngOf(tester, 4000, 3000);
      await pumpReader(
        tester,
        items: [item('a.png', source: MediaReaderSource.bytes(png))],
        engines: const MediaReaderEngines([
          MediaReaderPictureEngine(maxDecodeSide: 3000),
        ]),
      );
      await pumpUntil(tester, () => shown(tester) != null);

      await doubleTap(tester, centre);
      await pumpUntil(tester, () => shown(tester)!.width > 2400);

      // More detail than at rest, and no more than the cap.
      expect(shown(tester)!.width, 3000);
      expect(shown(tester)!.height, 2250);
    });

    testWidgets('a small picture is not decoded larger than it is', (
      tester,
    ) async {
      await pumpPictures(tester);

      expect(shown(tester)!.width, 40);
      expect(shown(tester)!.height, 30);
    });
  });

  group('zooming', () {
    testWidgets('a double tap zooms in, and the engine takes the drags', (
      tester,
    ) async {
      await pumpPictures(tester);
      final page = pageOf(tester);
      expect(scaleOf(tester), 1);
      expect(page.holdsPaging.value, isFalse);

      await doubleTap(tester, centre);

      expect(scaleOf(tester), closeTo(2.5, 0.01));
      expect(page.holdsPaging.value, isTrue);
      expect(page.holdsDismiss.value, isTrue);
      // A double tap is not a tap: the chrome stays.
      expect(page.chromeVisible.value, isTrue);
    });

    testWidgets('the point tapped stays where it is', (tester) async {
      await pumpPictures(tester);
      const tapped = Offset(200, 150);

      await doubleTap(tester, tapped);

      final after = MatrixUtils.transformPoint(transformOf(tester), tapped);
      expect(after.dx, closeTo(tapped.dx, 0.5));
      expect(after.dy, closeTo(tapped.dy, 0.5));
    });

    testWidgets('another double tap zooms back out, and lets the drags go', (
      tester,
    ) async {
      await pumpPictures(tester);
      final page = pageOf(tester);

      await doubleTap(tester, centre);
      await doubleTap(tester, centre);

      expect(scaleOf(tester), closeTo(1, 0.001));
      expect(page.holdsPaging.value, isFalse);
      expect(page.holdsDismiss.value, isFalse);
    });

    for (final touchSlop in [null, 8.0]) {
      testWidgets('a pinch zooms, and does not page '
          '(touch slop: ${touchSlop ?? "Flutter's own"})', (tester) async {
        final shownItems = <String>[];
        await pumpPictures(
          tester,
          touchSlop: touchSlop,
          onItemShown: (item) => shownItems.add(item.name),
        );
        await tester.pump();

        final left = await tester.startGesture(centre - const Offset(30, 0));
        final right = await tester.startGesture(centre + const Offset(30, 0));
        await tester.pump();
        for (var step = 0; step < 6; step++) {
          await left.moveBy(const Offset(-20, 0));
          await right.moveBy(const Offset(20, 0));
          await tester.pump();
        }
        await left.up();
        await right.up();
        await tester.pumpAndSettle();

        expect(scaleOf(tester), greaterThan(1.5));
        expect(shownItems, ['a.png']);
      });
    }

    testWidgets('the wheel zooms', (tester) async {
      await pumpPictures(tester);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(mouse.hover(centre));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
      await tester.pump();

      expect(scaleOf(tester), greaterThan(1.5));
      expect(pageOf(tester).holdsPaging.value, isTrue);
    });

    testWidgets('zoomed, a drag pans the picture and does not page', (
      tester,
    ) async {
      final shownItems = <String>[];
      await pumpPictures(
        tester,
        onItemShown: (item) => shownItems.add(item.name),
      );
      await tester.pump();
      await doubleTap(tester, centre);
      final before = transformOf(tester).getTranslation().x;

      await tester.drag(find.byType(InteractiveViewer), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(transformOf(tester).getTranslation().x, lessThan(before - 100));
      expect(shownItems, ['a.png']);
    });

    testWidgets('zoomed, a drag down does not dismiss', (tester) async {
      var dismissed = 0;
      await pumpPictures(tester, onDismissed: () => dismissed++);
      await doubleTap(tester, centre);

      await tester.drag(find.byType(InteractiveViewer), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(dismissed, 0);
    });

    testWidgets('the picture cannot be panned past its edges', (tester) async {
      await pumpPictures(tester);
      await doubleTap(tester, centre);

      await tester.drag(find.byType(InteractiveViewer), const Offset(5000, 0));
      await tester.pumpAndSettle();

      expect(transformOf(tester).getTranslation().x, closeTo(0, 0.5));
    });

    testWidgets('the zoom does not outlive the page being on screen', (
      tester,
    ) async {
      await pumpPictures(tester);
      await tester.pump();
      await doubleTap(tester, centre);
      expect(scaleOf(tester), greaterThan(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(scaleOf(tester), 1);
      expect(pageOf(tester).holdsPaging.value, isFalse);
    });
  });

  group('at rest', () {
    testWidgets('a drag sideways pages', (tester) async {
      final shownItems = <String>[];
      await pumpPictures(
        tester,
        onItemShown: (item) => shownItems.add(item.name),
      );
      await tester.pump();

      await swipeToNext(tester);

      expect(shownItems, ['a.png', 'b.png']);
    });

    testWidgets('a drag down dismisses', (tester) async {
      var dismissed = 0;
      await pumpPictures(tester, onDismissed: () => dismissed++);

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      // Long enough for the gesture's own timers to run out.
      await tester.pump(const Duration(milliseconds: 500));

      expect(dismissed, 1);
    });

    // A phone reports a touch slop of about 8, so a pan is a movement of
    // 16: a quick flick goes further than that between two events, and
    // the picture's own recognizer, being the deeper one, would have it.
    testWidgets('a quick flick sideways pages on a phone', (tester) async {
      final shownItems = <String>[];
      await pumpPictures(
        tester,
        touchSlop: 8,
        onItemShown: (item) => shownItems.add(item.name),
      );
      await tester.pump();

      await swipeToNext(tester);

      expect(shownItems, ['a.png', 'b.png']);
    });

    testWidgets('a quick flick down dismisses on a phone', (tester) async {
      var dismissed = 0;
      await pumpPictures(tester, touchSlop: 8, onDismissed: () => dismissed++);

      await tester.drag(find.byType(PageView), const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(dismissed, 1);
    });

    testWidgets('zoomed on a phone, a drag still pans the picture', (
      tester,
    ) async {
      await pumpPictures(tester, touchSlop: 8);
      await doubleTap(tester, centre);
      final before = transformOf(tester).getTranslation().x;

      await tester.drag(find.byType(InteractiveViewer), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(transformOf(tester).getTranslation().x, lessThan(before - 100));
    });

    testWidgets('a tap hides the chrome', (tester) async {
      await pumpPictures(tester);
      final page = pageOf(tester);

      await tester.tapAt(centre);
      // A tap waits to see that it is not the first of two.
      await tester.pump(const Duration(milliseconds: 400));

      expect(page.chromeVisible.value, isFalse);
    });
  });

  group('failing', () {
    testWidgets('a file that does not decode gives way to the card', (
      tester,
    ) async {
      await pumpReader(
        tester,
        items: [
          item(
            'a.png',
            source: MediaReaderSource.bytes(Uint8List.fromList([1, 2, 3, 4])),
          ),
        ],
      );
      await pumpUntil(
        tester,
        () => find.text('This file could not be opened.').evaluate().isNotEmpty,
      );

      expect(find.text('This file could not be opened.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });

  group('a remote picture', () {
    late FakeResolve host;
    late FakeTransport transport;
    late MediaReaderEngines engines;

    Future<void> pumpRemote(
      WidgetTester tester, {
      MediaReaderPolicy policy = const MediaReaderPolicy(),
      MediaReaderImageProviderBuilder? imageProvider,
      int maxBytes = 1 << 20,

      /// Sets the fakes up before the first fetch goes out.
      VoidCallback? before,
    }) async {
      final png = await pngOf(tester, 40, 30);
      host = FakeResolve();
      transport = FakeTransport({'/1': png, '/2': png});
      before?.call();
      engines = MediaReaderEngines([
        MediaReaderPictureEngine(
          transport: transport,
          imageProvider: imageProvider,
          maxBytes: maxBytes,
        ),
      ]);
      await pumpReader(
        tester,
        items: [item('a.png', source: MediaReaderSource.remote(host.call))],
        engines: engines,
        policy: policy,
      );
    }

    testWidgets('is fetched at the location the host gives', (tester) async {
      await pumpRemote(tester);
      await pumpUntil(tester, () => shown(tester) != null);

      expect(shown(tester), isNotNull);
      expect(host.calls, 1);
      expect(transport.requests.single.uri, Uri.parse('https://files.test/1'));
    });

    testWidgets('is fetched again at a fresh location when the first is '
        'refused', (tester) async {
      await pumpRemote(
        tester,
        before: () => transport.status = (uri) => uri.path == '/1' ? 410 : null,
      );
      await pumpUntil(tester, () => shown(tester) != null);

      expect(shown(tester), isNotNull);
      expect(host.calls, 2);
      expect(transport.requests.last.uri, Uri.parse('https://files.test/2'));
    });

    testWidgets('that cannot be reached gives way to the card, and a retry '
        'fetches again', (tester) async {
      await pumpRemote(
        tester,
        before: () => transport.failure = const SocketException('offline'),
      );
      await pumpUntil(
        tester,
        () => find.text('Try again').evaluate().isNotEmpty,
      );
      expect(
        find.text('This file could not be reached. Check the connection.'),
        findsOneWidget,
      );

      transport.failure = null;
      await tester.tap(find.text('Try again'));
      await pumpUntil(tester, () => shown(tester) != null);

      expect(shown(tester), isNotNull);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('larger than the engine takes gives way to the card', (
      tester,
    ) async {
      await pumpRemote(tester, maxBytes: 10);
      await pumpUntil(
        tester,
        () => find.text('Try again').evaluate().isNotEmpty,
      );

      expect(find.text('This file is too large to show here.'), findsOneWidget);
    });

    testWidgets("the host says is unavailable shows the card, in the host's "
        'words', (tester) async {
      await pumpRemote(
        tester,
        before: () => host.failure = const MediaReaderUnavailable(
          'Removed by a moderator.',
        ),
      );
      await pumpUntil(
        tester,
        () => find.text('Removed by a moderator.').evaluate().isNotEmpty,
      );

      expect(find.text('Removed by a moderator.'), findsOneWidget);
    });

    testWidgets("comes from the host's provider where export is allowed", (
      tester,
    ) async {
      final png = await pngOf(tester, 20, 10);
      var asked = 0;
      await pumpRemote(
        tester,
        imageProvider: (item, page) {
          asked++;
          return MemoryImage(png);
        },
      );
      await pumpUntil(tester, () => shown(tester) != null);

      expect(asked, 1);
      expect(shown(tester)!.width, 20);
      expect(transport.requests, isEmpty);
    });

    testWidgets("does not come from the host's provider with export off", (
      tester,
    ) async {
      final png = await pngOf(tester, 20, 10);
      var asked = 0;
      await pumpRemote(
        tester,
        policy: const MediaReaderPolicy(canExport: false),
        imageProvider: (item, page) {
          asked++;
          return MemoryImage(png);
        },
      );
      await pumpUntil(tester, () => shown(tester) != null);

      // A host's cache is usually on disk: the engine loads it in memory.
      expect(asked, 0);
      expect(shown(tester)!.width, 40);
      expect(transport.requests, hasLength(1));
    });

    /// Two remote pictures, each with its own host to count its resolves.
    Future<(FakeResolve, FakeResolve)> pumpTwo(
      WidgetTester tester, {
      required bool prepareNeighbours,
    }) async {
      final png = await pngOf(tester, 40, 30);
      final first = FakeResolve();
      final second = FakeResolve();
      await pumpReader(
        tester,
        items: [
          item('a.png', source: MediaReaderSource.remote(first.call)),
          item('b.png', source: MediaReaderSource.remote(second.call)),
        ],
        engines: MediaReaderEngines([
          MediaReaderPictureEngine(
            transport: FakeTransport({'/1': png}),
            prepareNeighbours: prepareNeighbours,
          ),
        ]),
      );
      await pumpUntil(tester, () => shown(tester) != null);
      return (first, second);
    }

    testWidgets("a neighbour's picture is fetched before it is paged to", (
      tester,
    ) async {
      final (first, second) = await pumpTwo(tester, prepareNeighbours: true);

      expect(first.calls, 1);
      expect(second.calls, 1);
    });

    testWidgets('a neighbour is left alone where the host would rather it '
        'were', (tester) async {
      final (first, second) = await pumpTwo(tester, prepareNeighbours: false);
      expect(first.calls, 1);
      expect(second.calls, 0);

      // The neighbour's ring turns until it is asked for: no settling.
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(seconds: 1));
      await pumpUntil(tester, () => second.calls == 1);
      await pumpUntil(tester, () => shown(tester) != null);

      expect(second.calls, 1);
      expect(shown(tester), isNotNull);
    });

    testWidgets('is the same picture to the cache after its location '
        'changes', (tester) async {
      await pumpRemote(tester);
      await pumpUntil(tester, () => shown(tester) != null);

      // The reader is closed and opened again: a new page, a new URL.
      await tester.pumpWidget(const SizedBox());
      await pumpReader(
        tester,
        items: [item('a.png', source: MediaReaderSource.remote(host.call))],
        engines: engines,
      );
      await pumpUntil(tester, () => shown(tester) != null);

      expect(shown(tester), isNotNull);
      expect(transport.requests, hasLength(1));
    });

    testWidgets('is not kept once its page is gone, where no cache is '
        'allowed', (tester) async {
      await pumpRemote(
        tester,
        policy: const MediaReaderPolicy(cache: MediaReaderCache.none()),
      );
      await pumpUntil(tester, () => shown(tester) != null);

      await tester.pumpWidget(const SizedBox());
      await pumpReader(
        tester,
        items: [item('a.png', source: MediaReaderSource.remote(host.call))],
        engines: engines,
        policy: const MediaReaderPolicy(cache: MediaReaderCache.none()),
      );
      await pumpUntil(tester, () => shown(tester) != null);

      expect(transport.requests, hasLength(2));
    });
  });
}
