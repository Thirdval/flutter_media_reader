/// Runs the example on a device, for the platform matrix of
/// MEDIA_READER_PLAN.md §5:
///
///     cd example && fvm flutter test integration_test -d <device>
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader_example/main.dart';
import 'package:flutter_media_reader_example/samples.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SampleFiles files;
  setUpAll(() async => files = await SampleFiles.load());
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    files.server
      ..served.clear()
      ..signed.clear()
      ..expireNext.clear()
      ..validFor = const Duration(minutes: 15);
  });

  Future<void> pumpExample(WidgetTester tester) async {
    await tester.pumpWidget(ExampleApp(files: files));
    await tester.pumpAndSettle();
  }

  /// Frames until [done], for up to fifteen seconds: a file is on its way.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var tries = 0; tries < 300 && !done(); tries++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: 'Still waiting after fifteen seconds');
  }

  /// Opens the sample named [name], scrolling the list to it first. The
  /// reader may still be loading when this returns.
  Future<void> open(WidgetTester tester, String name) async {
    await tester.scrollUntilVisible(
      find.text(name),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The scroll lands in the next frame; the tap is aimed after it.
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await pumpUntil(
      tester,
      () => find.byType(MediaReaderView).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The decoded picture on screen; null while it is on the way.
  ui.Image? picture(WidgetTester tester) => tester
      .widgetList<RawImage>(
        find.descendant(
          of: find.byType(MediaReaderView),
          matching: find.byType(RawImage),
        ),
      )
      .map((raw) => raw.image)
      .nonNulls
      .firstOrNull;

  double zoom(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  /// The screen's size in pixels, which a decoded picture stays within
  /// while it is not zoomed.
  Size pixels(WidgetTester tester) =>
      tester.view.physicalSize +
      // A pixel of slack for rounding.
      const Offset(1, 1);

  Future<void> swipeToNext(WidgetTester tester) async {
    // Most of a page's width, whatever the device's.
    final width = tester.getSize(find.byType(PageView)).width;
    await tester.drag(find.byType(PageView), Offset(-width * 0.6, 0));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> doubleTap(WidgetTester tester) async {
    final centre = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('pictures', () {
    testWidgets('a picture opens from a signed URL, zooms, and pages to a '
        'picture of 48 megapixels', (tester) async {
      await pumpExample(tester);

      await open(tester, 'harvest_supper.jpg');
      await pumpUntil(tester, () => picture(tester) != null);

      expect(
        files.server.served,
        contains((name: 'harvest_supper.jpg', status: 200, range: null)),
      );
      final small = picture(tester)!;
      expect(small.width, lessThanOrEqualTo(pixels(tester).width));
      expect(small.height, lessThanOrEqualTo(pixels(tester).height));

      await doubleTap(tester);
      expect(zoom(tester), greaterThan(2));
      await doubleTap(tester);
      expect(zoom(tester), closeTo(1, 0.01));

      await swipeToNext(tester);
      await pumpUntil(
        tester,
        () => files.server.served.any(
          (file) => file.name == 'hall_48_megapixels.jpg',
        ),
      );
      await pumpUntil(
        tester,
        () => picture(tester) != null && picture(tester) != small,
      );

      // Eight thousand pixels wide in the file; the screen's on screen.
      final large = picture(tester)!;
      expect(large.width, lessThanOrEqualTo(pixels(tester).width));
      expect(large.height, lessThanOrEqualTo(pixels(tester).height));
    });

    testWidgets('pictures come from bytes and from a file', (tester) async {
      await pumpExample(tester);

      await open(tester, 'candle.gif');
      await pumpUntil(tester, () => picture(tester) != null);
      expect(picture(tester)!.width, 240);

      await swipeToNext(tester);
      await pumpUntil(tester, () => picture(tester)?.width == 640);

      // Neither was asked of the server: only their neighbours were.
      expect(
        files.server.served.map((file) => file.name),
        isNot(anyOf(contains('candle.gif'), contains('banner.png'))),
      );
    });

    testWidgets('a HEIC shows: as it is where the system decodes it, '
        'through its JPEG elsewhere', (tester) async {
      await pumpExample(tester);

      await open(tester, 'IMG_0042.heic');
      await pumpUntil(tester, () => picture(tester) != null);

      final apple =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      expect(
        files.server.served.map((file) => file.name),
        contains(apple ? 'IMG_0042.heic' : 'IMG_0042.jpg'),
      );
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a URL that has expired is resolved again', (tester) async {
      await pumpExample(tester);
      files.server.expireNext.add('harvest_supper.jpg');
      final signedBefore = files.server.signed['harvest_supper.jpg'] ?? 0;

      await open(tester, 'harvest_supper.jpg');
      await pumpUntil(tester, () => picture(tester) != null);

      expect(
        files.server.served
            .where((file) => file.name == 'harvest_supper.jpg')
            .map((file) => file.status),
        [410, 200],
      );
      expect(files.server.signed['harvest_supper.jpg'], signedBefore + 2);
    });
  });

  group('video', () {
    /// The time the transport shows as played, in seconds; null while
    /// there is no transport.
    int? played(WidgetTester tester) {
      final texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(MediaReaderView),
          matching: find.byType(Text),
        ),
      );
      for (final text in texts) {
        final time = RegExp(r'^(\d+):(\d\d)$').firstMatch(text.data ?? '');
        if (time != null) {
          return int.parse(time.group(1)!) * 60 + int.parse(time.group(2)!);
        }
      }
      return null;
    }

    bool shows(String label) =>
        find.bySemanticsLabel(label).evaluate().isNotEmpty;

    testWidgets('a video plays from a signed URL, pauses, seeks and goes '
        'on', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await open(tester, 'baptism.mp4');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 1);
      expect(shows('Pause'), isTrue);

      await tester.tap(find.bySemanticsLabel('Pause'));
      await pumpUntil(tester, () => shows('Play'));
      final pausedAt = played(tester)!;
      await tester.pump(const Duration(seconds: 1));
      expect(played(tester), pausedAt);

      // Three quarters along a video of eight seconds.
      final track = tester.getRect(find.bySemanticsLabel('Position'));
      await tester.tapAt(track.centerLeft + Offset(track.width * 0.75, 0));
      await pumpUntil(tester, () => played(tester) == 6);

      await tester.tap(find.bySemanticsLabel('Play'));
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 7);

      // The platform's player fetched the file from the server. AVPlayer
      // asks by ranges from the start; ExoPlayer takes a file this small
      // in one request.
      final requests = files.server.served.where(
        (file) => file.name == 'baptism.mp4',
      );
      expect(requests, isNotEmpty);
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        expect(requests.where((file) => file.range != null), isNotEmpty);
      }
      // The video after it was not asked for: it is a neighbour.
      expect(files.server.signed['choir.webm'], isNull);
      expect(files.server.signed['choir.mp4'], isNull);
      semantics.dispose();
    });

    testWidgets('a URL that runs out while the video is paused is renewed, '
        'and the video goes on where it was', (tester) async {
      final semantics = tester.ensureSemantics();
      // Thirty seconds before it expires a URL is no longer used: this
      // one is stale three seconds after it is signed.
      files.server.validFor = const Duration(seconds: 33);
      await pumpExample(tester);

      await open(tester, 'baptism.mp4');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 4);
      await tester.tap(find.bySemanticsLabel('Pause'));
      await pumpUntil(tester, () => shows('Play'));
      final pausedAt = played(tester)!;
      expect(files.server.signed['baptism.mp4'], 1);

      await tester.tap(find.bySemanticsLabel('Play'));
      await pumpUntil(tester, () => files.server.signed['baptism.mp4'] == 2);
      await pumpUntil(
        tester,
        () => shows('Pause') && (played(tester) ?? 0) > pausedAt,
      );

      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });

    testWidgets('the next video plays when it is paged to: a WebM as it is '
        'where the player plays it, through its MP4 elsewhere', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await open(tester, 'baptism.mp4');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 1);
      await swipeToNext(tester);

      final apple =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      final expected = apple ? 'choir.mp4' : 'choir.webm';
      await pumpUntil(
        tester,
        () => files.server.served.any((file) => file.name == expected),
      );
      await pumpUntil(
        tester,
        () => shows('Pause') && (played(tester) ?? 0) >= 1,
      );

      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });
  });

  group('the shell', () {
    testWidgets('a file without an engine opens as its card, pages, and '
        'closes', (tester) async {
      await pumpExample(tester);

      await open(tester, 'Rota_October.pdf');

      expect(find.text('PDF · 258 KB'), findsOneWidget);
      expect(find.text('Save to device'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      await swipeToNext(tester);
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
      await open(tester, 'Rota_October.pdf');
      final position =
          samples.indexWhere((sample) => sample.name == 'Rota_October.pdf') + 1;
      expect(find.text('$position of ${samples.length}'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsNothing);
      semantics.dispose();
    });

    testWidgets('a drag down closes the reader', (tester) async {
      await pumpExample(tester);
      await open(tester, 'Budget 2026.xlsx');

      final height = tester.getSize(find.byType(PageView)).height;
      await tester.drag(find.byType(PageView), Offset(0, height * 0.5));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsNothing);
    });
  });
}
