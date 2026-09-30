import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/transport_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_video.dart';

void main() {
  Future<FakePlayback> pumpBar(
    WidgetTester tester, {
    MediaReaderPlaybackState state = const MediaReaderPlaybackState(
      position: Duration(seconds: 30),
      duration: Duration(minutes: 2),
    ),
    TextDirection textDirection = TextDirection.ltr,
    MediaReaderChrome chrome = const MediaReaderChrome(),
  }) async {
    final playback = FakePlayback(state);
    await tester.pumpWidget(
      Directionality(
        textDirection: textDirection,
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 14),
          child: Center(
            child: MediaReaderTransportBar(playback: playback, chrome: chrome),
          ),
        ),
      ),
    );
    return playback;
  }

  group('formatPlaybackTime', () {
    test('reads as a player shows it', () {
      expect(formatPlaybackTime(Duration.zero), '0:00');
      expect(formatPlaybackTime(const Duration(seconds: 7)), '0:07');
      expect(
        formatPlaybackTime(const Duration(minutes: 12, seconds: 34)),
        '12:34',
      );
      expect(
        formatPlaybackTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });

  group('MediaReaderPlaybackState', () {
    test('says how far through the file it is', () {
      const state = MediaReaderPlaybackState(
        position: Duration(seconds: 30),
        duration: Duration(minutes: 2),
        buffered: Duration(seconds: 90),
      );

      expect(state.progress, 0.25);
      expect(state.bufferedProgress, 0.75);
      expect(state.remaining, const Duration(seconds: 90));
    });

    test('is at the start while the length is not known', () {
      const state = MediaReaderPlaybackState(position: Duration(seconds: 30));

      expect(state.progress, 0);
      expect(state.remaining, isNull);
    });
  });

  group('MediaReaderTransportBar', () {
    testWidgets('shows the time played and the time left', (tester) async {
      await pumpBar(tester);

      expect(find.text('0:30'), findsOneWidget);
      expect(find.text('-1:30'), findsOneWidget);
    });

    testWidgets('shows no time left while the length is not known', (
      tester,
    ) async {
      await pumpBar(
        tester,
        state: const MediaReaderPlaybackState(position: Duration(seconds: 30)),
      );

      expect(find.text('0:30'), findsOneWidget);
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('its buttons say what they do', (tester) async {
      final semantics = tester.ensureSemantics();
      final playback = await pumpBar(tester);

      expect(
        tester.getSemantics(find.bySemanticsLabel('Play')),
        isSemantics(label: 'Play', isButton: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel('Mute'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.tap(find.bySemanticsLabel('Mute'));
      await tester.pump();

      expect(playback.state.value.playing, isTrue);
      expect(playback.state.value.muted, isTrue);
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.bySemanticsLabel('Unmute'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('its scrubber is a slider a screen reader can move', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final playback = await pumpBar(tester);
      final scrubber = tester.getSemantics(find.byType(MediaReaderScrubber));

      expect(
        scrubber,
        isSemantics(
          label: 'Position',
          value: '0:30',
          increasedValue: '0:35',
          decreasedValue: '0:25',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      tester.semantics.performAction(
        find.semantics.byLabel('Position'),
        SemanticsAction.increase,
      );
      await tester.pump();
      expect(playback.seeks, [const Duration(seconds: 35)]);

      tester.semantics.performAction(
        find.semantics.byLabel('Position'),
        SemanticsAction.decrease,
      );
      await tester.pump();
      expect(playback.seeks.last, const Duration(seconds: 30));
      semantics.dispose();
    });

    testWidgets('a step never leaves the file', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(
        tester,
        state: const MediaReaderPlaybackState(
          position: Duration(seconds: 118),
          duration: Duration(minutes: 2),
        ),
      );

      expect(
        tester.getSemantics(find.byType(MediaReaderScrubber)),
        isSemantics(
          label: 'Position',
          value: '1:58',
          increasedValue: '2:00',
          decreasedValue: '1:53',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the thumb follows a drag, and the seek comes at its end', (
      tester,
    ) async {
      final playback = await pumpBar(tester);
      final track = tester.getRect(find.byType(MediaReaderScrubber));

      final gesture = await tester.startGesture(
        track.centerLeft + Offset(track.width * 0.25, 0),
      );
      await gesture.moveBy(Offset(track.width * 0.25, 0));
      await tester.pump();
      expect(playback.seeks, isEmpty);

      await gesture.up();
      await tester.pump();

      expect(playback.seeks.single.inSeconds, 60);
    });

    testWidgets('runs left to right in a right-to-left language', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, textDirection: TextDirection.rtl);

      final play = tester.getCenter(find.bySemanticsLabel('Play'));
      final mute = tester.getCenter(find.bySemanticsLabel('Mute'));

      expect(play.dx, lessThan(mute.dx));
      semantics.dispose();
    });

    testWidgets("says its labels in the host's words", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(
        tester,
        chrome: MediaReaderChrome(
          strings: MediaReaderStrings(
            play: 'Lire',
            speed: (speed) => 'x$speed',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Lire'), findsOneWidget);
      expect(find.text('x1.0'), findsOneWidget);
      semantics.dispose();
    });
  });
}
