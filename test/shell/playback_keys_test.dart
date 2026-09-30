import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/playback_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_video.dart';
import '../support/fakes.dart';

void main() {
  late FakeEngine engine;

  /// A reader over one video whose page plays [playback].
  Future<FakePlayback> pumpPlaying(
    WidgetTester tester, {
    MediaReaderPlaybackState state = const MediaReaderPlaybackState(
      position: Duration(seconds: 30),
      duration: Duration(minutes: 1),
    ),
  }) async {
    engine = FakeEngine('fake', kinds: {MediaKind.video});
    await pumpReader(
      tester,
      items: [item('a.mp4')],
      engines: MediaReaderEngines([engine]),
    );
    final playback = FakePlayback(state);
    engine.pages['a.mp4']!.playback.value = playback;
    await tester.pump();
    return playback;
  }

  Future<void> shifted(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }

  group('the playback keys', () {
    testWidgets('the space bar plays and pauses', (tester) async {
      final playback = await pumpPlaying(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(playback.state.value.playing, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(playback.state.value.playing, isFalse);
    });

    testWidgets('M mutes and unmutes', (tester) async {
      final playback = await pumpPlaying(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      expect(playback.state.value.muted, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      expect(playback.state.value.muted, isFalse);
    });

    testWidgets('Shift with an arrow seeks ten seconds', (tester) async {
      final playback = await pumpPlaying(tester);

      await shifted(tester, LogicalKeyboardKey.arrowRight);
      await shifted(tester, LogicalKeyboardKey.arrowLeft);
      await shifted(tester, LogicalKeyboardKey.arrowLeft);

      expect(playback.seeks, const [
        Duration(seconds: 40),
        Duration(seconds: 30),
        Duration(seconds: 20),
      ]);
    });

    testWidgets('a seek stays within the file', (tester) async {
      final playback = await pumpPlaying(
        tester,
        state: const MediaReaderPlaybackState(
          position: Duration(seconds: 55),
          duration: Duration(minutes: 1),
        ),
      );

      await shifted(tester, LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < 7; i++) {
        await shifted(tester, LogicalKeyboardKey.arrowLeft);
      }

      expect(playback.seeks.first, const Duration(minutes: 1));
      expect(playback.seeks.last, Duration.zero);
    });

    testWidgets('an arrow without Shift still pages', (tester) async {
      engine = FakeEngine('fake', kinds: {MediaKind.video});
      await pumpReader(
        tester,
        items: [item('a.mp4'), item('b.mp4')],
        engines: MediaReaderEngines([engine]),
      );
      final playback = FakePlayback();
      engine.pages['a.mp4']!.playback.value = playback;
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(playback.seeks, isEmpty);
      expect(find.text('fake:b.mp4'), findsOneWidget);
    });

    testWidgets('a page that plays nothing leaves the keys', (tester) async {
      engine = FakeEngine('fake', kinds: {MediaKind.video});
      await pumpReader(
        tester,
        items: [item('a.mp4')],
        engines: MediaReaderEngines([engine]),
      );

      final handled = await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(handled, isFalse);
    });

    testWidgets('a key typed into a field is left to the field', (
      tester,
    ) async {
      final playback = await pumpPlaying(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          builder: (context, _) => Focus(
            onKeyEvent: (node, event) => playbackKeys(playback, event),
            child: EditableText(
              controller: controller,
              focusNode: focus,
              style: const TextStyle(),
              cursorColor: const Color(0xFFFFFFFF),
              backgroundCursorColor: const Color(0xFF000000),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

      expect(playback.state.value.playing, isFalse);
      expect(playback.state.value.muted, isFalse);
    });
  });
}
