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
import 'package:flutter_media_reader_example/host_chrome.dart';
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
  // A voice note that plays on in its bubble does not play into the next
  // test.
  tearDown(MediaReaderAudioCoordinator.shared.stop);

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

  /// What [matching] finds in the reader, and not in the page under it.
  Finder inReader(Finder matching) =>
      find.descendant(of: find.byType(MediaReaderView), matching: matching);

  /// Whether the reader's transport shows the control called [label].
  bool shows(String label) =>
      inReader(find.bySemanticsLabel(label)).evaluate().isNotEmpty;

  /// How far the reader's transport shows the file has played; null while
  /// there is no transport.
  Duration? position(WidgetTester tester) => tester
      .widgetList<MediaReaderWaveform>(
        inReader(find.byType(MediaReaderWaveform)),
      )
      .firstOrNull
      ?.position;

  /// The same in whole seconds, as the transport writes it.
  int? played(WidgetTester tester) => position(tester)?.inSeconds;

  Future<void> tapControl(WidgetTester tester, String label) =>
      tester.tap(inReader(find.bySemanticsLabel(label)));

  /// Taps the transport's track at [fraction] of its length.
  Future<void> seekTo(WidgetTester tester, double fraction) async {
    final track = tester.getRect(inReader(find.byType(MediaReaderWaveform)));
    await tester.tapAt(track.centerLeft + Offset(track.width * fraction, 0));
  }

  final apple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

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
    testWidgets('a video plays from a signed URL, pauses, seeks and goes '
        'on', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await open(tester, 'baptism.mp4');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 1);
      expect(shows('Pause'), isTrue);

      await tapControl(tester, 'Pause');
      await pumpUntil(tester, () => shows('Play'));
      final pausedAt = played(tester)!;
      await tester.pump(const Duration(seconds: 1));
      expect(played(tester), pausedAt);

      // Three quarters along a video of eight seconds.
      await seekTo(tester, 0.75);
      await pumpUntil(tester, () => played(tester) == 6);

      await tapControl(tester, 'Play');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 7);

      // The platform's player fetched the file from the server. AVPlayer
      // asks by ranges from the start; ExoPlayer takes a file this small
      // in one request.
      final requests = files.server.served.where(
        (file) => file.name == 'baptism.mp4',
      );
      expect(requests, isNotEmpty);
      if (apple) {
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
      await tapControl(tester, 'Pause');
      await pumpUntil(tester, () => shows('Play'));
      final pausedAt = played(tester)!;
      expect(files.server.signed['baptism.mp4'], 1);

      await tapControl(tester, 'Play');
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

  group('audio', () {
    /// What [matching] finds in the voice note's bubble.
    Finder inBubble(Finder matching) => find.descendant(
      of: find.byType(MediaReaderAudioBar),
      matching: matching,
    );

    /// How far the bubble shows the voice note has played.
    Duration bubbleAt(WidgetTester tester) => tester
        .widget<MediaReaderWaveform>(inBubble(find.byType(MediaReaderWaveform)))
        .position;

    testWidgets('a voice note plays from a signed URL, pauses, seeks along '
        'its waveform and goes on', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await open(tester, voiceNote);
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 1);
      expect(shows('Pause'), isTrue);
      // The transport draws the peaks the host gave.
      expect(
        tester
            .widget<MediaReaderWaveform>(
              inReader(find.byType(MediaReaderWaveform)),
            )
            .peaks,
        hasLength(100),
      );

      await tapControl(tester, 'Pause');
      await pumpUntil(tester, () => shows('Play'));
      final pausedAt = position(tester)!;
      await tester.pump(const Duration(seconds: 1));
      expect(position(tester), pausedAt);

      // Seven tenths along a note of six seconds.
      await seekTo(tester, 0.7);
      await pumpUntil(tester, () => played(tester) == 4);

      await tapControl(tester, 'Play');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 5);

      // One signature for all of it, and none for the file after it.
      expect(files.server.signed[voiceNote], 1);
      expect(files.server.signed['hymn.mp3'], isNull);
      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });

    testWidgets('an MP3 plays from a signed URL, and a WAV from a file', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await open(tester, 'hymn.mp3');
      await pumpUntil(
        tester,
        () => shows('Pause') && (played(tester) ?? 0) >= 1,
      );
      expect(
        files.server.served.map((file) => file.name),
        contains('hymn.mp3'),
      );

      await swipeToNext(tester);
      await pumpUntil(
        tester,
        () => shows('Pause') && position(tester)! > Duration.zero,
      );

      // The hymn stopped when its page was left, and the bell came from
      // the device: the server was not asked for it.
      expect(find.text('bell.wav'), findsWidgets);
      expect(
        files.server.served.map((file) => file.name),
        isNot(contains('bell.wav')),
      );
      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });

    testWidgets('an Ogg plays as it is where the player plays it, through '
        'its MP3 elsewhere', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await open(tester, 'psalm.ogg');
      final expected = apple ? 'psalm.mp3' : 'psalm.ogg';
      await pumpUntil(
        tester,
        () => files.server.served.any((file) => file.name == expected),
      );
      await pumpUntil(
        tester,
        () => shows('Pause') && (played(tester) ?? 0) >= 1,
      );

      expect(files.server.signed[apple ? 'psalm.ogg' : 'psalm.mp3'], isNull);
      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a voice note in its bubble and in the reader share one '
        'player', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      // Played and paused where it stands in the chat.
      await tester.tap(inBubble(find.bySemanticsLabel('Play')));
      await pumpUntil(
        tester,
        () => bubbleAt(tester) >= const Duration(seconds: 1),
      );
      await tester.tap(inBubble(find.bySemanticsLabel('Pause')));
      await pumpUntil(
        tester,
        () => inBubble(find.bySemanticsLabel('Play')).evaluate().isNotEmpty,
      );
      final inChat = bubbleAt(tester);
      expect(files.server.signed[voiceNote], 1);

      // Opened in the reader, it goes on from there, and the host is not
      // asked again.
      await open(tester, voiceNote);
      await pumpUntil(tester, () => shows('Pause'));
      expect(position(tester), greaterThanOrEqualTo(inChat));
      expect(files.server.signed[voiceNote], 1);

      await tapControl(tester, 'Pause');
      await pumpUntil(tester, () => shows('Play'));
      final inTheReader = position(tester)!;

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MediaReaderView), findsNothing);

      // The bubble shows the note where the reader left it, and plays it
      // on.
      expect(bubbleAt(tester), inTheReader);
      await tester.tap(inBubble(find.bySemanticsLabel('Play')));
      await pumpUntil(tester, () => bubbleAt(tester) > inTheReader);

      expect(files.server.signed[voiceNote], 1);
      semantics.dispose();
    });

    testWidgets('a URL that runs out while the file is paused is renewed, '
        'and the file goes on where it was', (tester) async {
      final semantics = tester.ensureSemantics();
      // Stale three seconds after it is signed, as for the video.
      files.server.validFor = const Duration(seconds: 33);
      await pumpExample(tester);

      await open(tester, 'hymn.mp3');
      await pumpUntil(tester, () => (played(tester) ?? 0) >= 4);
      await tapControl(tester, 'Pause');
      await pumpUntil(tester, () => shows('Play'));
      final pausedAt = position(tester)!;
      expect(files.server.signed['hymn.mp3'], 1);

      await tapControl(tester, 'Play');
      await pumpUntil(tester, () => files.server.signed['hymn.mp3'] == 2);
      await pumpUntil(
        tester,
        () => shows('Pause') && position(tester)! > pausedAt,
      );

      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a video that starts stops the voice note that plays', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpExample(tester);

      await tester.tap(inBubble(find.bySemanticsLabel('Play')));
      await pumpUntil(
        tester,
        () => bubbleAt(tester) >= const Duration(seconds: 1),
      );

      await open(tester, 'baptism.mp4');
      await pumpUntil(
        tester,
        () => shows('Pause') && (played(tester) ?? 0) >= 1,
      );

      // The note stopped where it was, short of its end. The bubble is
      // under the reader, where a screen reader does not look: the note
      // is asked of the coordinator.
      final note = MediaReaderAudioCoordinator.shared.active.value!.state.value;
      expect(note.playing, isFalse);
      expect(note.ended, isFalse);
      expect(note.position, bubbleAt(tester));
      expect(note.position, lessThan(const Duration(seconds: 6)));
      semantics.dispose();
    });
  });

  group('PDF', () {
    const rota = 'Rota_October.pdf';

    bool shows(String text) => find.text(text).evaluate().isNotEmpty;

    /// Opens the rota and waits for its first page.
    Future<void> openRota(WidgetTester tester) async {
      await pumpExample(tester);
      await open(tester, rota);
      await pumpUntil(tester, () => shows('1 of 300'));
    }

    testWidgets('a PDF of 300 pages opens from a signed URL, by ranges, and '
        'goes to a page by its number', (tester) async {
      final semantics = tester.ensureSemantics();
      await openRota(tester);

      // Never the whole file in one answer, and one signature for all of
      // the ranges.
      final requests = files.server.served.where((file) => file.name == rota);
      expect(requests, isNotEmpty);
      for (final request in requests) {
        expect(request.status, 206);
        expect(request.range, isNotNull);
      }
      expect(files.server.signed[rota], 1);

      await tester.tap(inReader(find.bySemanticsLabel('Pages')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(inReader(find.byType(EditableText)), '300');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await pumpUntil(tester, () => shows('300 of 300'));

      expect(find.text('Try again'), findsNothing);
      semantics.dispose();
    });

    testWidgets('search reads through every page, and goes from match to '
        'match', (tester) async {
      final semantics = tester.ensureSemantics();
      await openRota(tester);

      await tester.tap(inReader(find.bySemanticsLabel('Search')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        inReader(find.byType(EditableText)),
        'Harvest supper',
      );
      // It is on three of the three hundred pages, the first the twelfth.
      await pumpUntil(tester, () => shows('1 of 3'));
      await pumpUntil(tester, () => !shows('1 of 300'));

      await tester.tap(inReader(find.bySemanticsLabel('Next match')));
      await pumpUntil(tester, () => shows('2 of 3'));
      semantics.dispose();
    });

    testWidgets('a drag up scrolls the pages; a drag sideways goes to the '
        'next file, a protected PDF the host is asked about', (tester) async {
      await openRota(tester);
      final reader = tester.getRect(find.byType(MediaReaderView));

      // Fingers, not jumps: a real drag goes a little at a time. A page
      // is taller than a desktop's window, so it takes a few.
      for (var i = 0; i < 10 && shows('1 of 300'); i++) {
        await tester.timedDragFrom(
          reader.center,
          Offset(0, -reader.height * 0.4),
          const Duration(milliseconds: 300),
        );
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(shows('1 of 300'), isFalse);

      // A finger starts from rest: the pager has the drag before the
      // page's own panning could take it.
      await tester.timedDragFrom(
        reader.center,
        Offset(-reader.width * 0.7, 0),
        const Duration(milliseconds: 800),
      );
      await pumpUntil(tester, () => shows('Password'));

      // The wrong one is asked about again; the right one opens it.
      await tester.enterText(find.byType(TextField), 'supper');
      await tester.tap(find.text('Open'));
      await pumpUntil(tester, () => shows('That password did not open it.'));
      // The first dialog is on its way out as the second comes in.
      await pumpUntil(
        tester,
        () => find.byType(TextField).evaluate().length == 1,
      );
      await tester.enterText(find.byType(TextField), 'harvest');
      await tester.tap(find.text('Open'));
      await pumpUntil(tester, () => shows('1 of 2'));
    });

    testWidgets('a protected PDF the host gives up on shows its card', (
      tester,
    ) async {
      await pumpExample(tester);
      await open(tester, 'Accounts_2025.pdf');
      await pumpUntil(tester, () => shows('Password'));

      await tester.tap(find.text('Cancel'));

      await pumpUntil(
        tester,
        () => shows('This file is protected by a password.'),
      );
    });

    testWidgets('a link in a PDF is handed to the host', (tester) async {
      await openRota(tester);
      final context = tester.element(find.byType(MediaReaderView));
      final reader = tester.getRect(find.byType(MediaReaderView));
      // The page fits the reader's width, with a margin of 8 points each
      // side. Its first line, a link, is 44 points down the page; the
      // page starts below the screen's edge and the chrome's top row.
      final perPoint = reader.width / (612 + 16);
      final link =
          reader.topLeft +
          Offset(
            (8 + 153) * perPoint,
            MediaQuery.paddingOf(context).top +
                hostChrome.contentInsets.top +
                (8 + 44.5) * perPoint,
          );

      // The page's links are read once the page is drawn: a tap before
      // that is a tap on the bare page.
      await tester.pump(const Duration(seconds: 1));
      await tester.tapAt(link);

      await pumpUntil(
        tester,
        () => find
            .textContaining('https://tendvine.example/rota')
            .evaluate()
            .isNotEmpty,
      );
      // The reader is still there, under the host's dialog.
      expect(find.byType(MediaReaderView), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('the shell', () {
    testWidgets('a file without an engine opens as its card, pages, and '
        'closes', (tester) async {
      await pumpExample(tester);

      await open(tester, 'Budget 2026.xlsx');

      // The card after it has the same actions, and a phone's width puts
      // that page a hair's breadth on screen for a finder: only what can
      // be tapped is counted.
      expect(find.text('Document · 57 KB'), findsOneWidget);
      expect(find.text('Save to device').hitTestable(), findsOneWidget);
      expect(find.text('Share').hitTestable(), findsOneWidget);

      await swipeToNext(tester);
      expect(find.text('Text · 4 KB'), findsOneWidget);

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
      await open(tester, 'Budget 2026.xlsx');
      final position =
          samples.indexWhere((sample) => sample.name == 'Budget 2026.xlsx') + 1;
      expect(find.text('$position of ${samples.length}'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsNothing);
      semantics.dispose();
    });

    testWidgets('a drag down closes the reader', (tester) async {
      await pumpExample(tester);
      await open(tester, 'model.glb');

      final height = tester.getSize(find.byType(PageView)).height;
      await tester.drag(find.byType(PageView), Offset(0, height * 0.5));
      await tester.pumpAndSettle();

      expect(find.byType(MediaReaderView), findsNothing);
    });
  });
}
