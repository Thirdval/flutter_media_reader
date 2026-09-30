import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/plain_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_audio.dart';
import '../support/fake_document.dart';
import '../support/fake_video.dart';
import '../support/fakes.dart';

/// The host's icons in place of the reader's glyphs (1.1).
void main() {
  /// What the host's builder was asked for, in order.
  final asked = <(MediaReaderGlyph, Color, double)>[];
  setUp(asked.clear);

  /// A host that draws every glyph as a word.
  Widget? words(
    BuildContext context,
    MediaReaderGlyph glyph,
    Color colour,
    double size,
  ) {
    asked.add((glyph, colour, size));
    return Text('icon:${glyph.name}');
  }

  final chrome = MediaReaderChrome(glyph: words);

  Finder painted() => find.descendant(
    of: find.byType(MediaReaderGlyphButton),
    matching: find.byType(CustomPaint),
  );

  group("the host's glyphs", () {
    testWidgets('stand on the transport, at the size and colour asked', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final engine = FakeEngine('fake', kinds: {MediaKind.video});
      await pumpReader(
        tester,
        items: [item('a.mp4')],
        engines: MediaReaderEngines([engine]),
        chrome: chrome,
      );
      final playback = FakePlayback();
      engine.pages['a.mp4']!.playback.value = playback;
      await tester.pump();

      expect(find.text('icon:play'), findsOneWidget);
      expect(find.text('icon:sound'), findsOneWidget);
      expect(painted(), findsNothing);
      expect(asked, contains((MediaReaderGlyph.play, chrome.foreground, 24.0)));
      // The buttons keep their names and do their work.
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pump();
      expect(playback.state.value.playing, isTrue);
      expect(find.text('icon:pause'), findsOneWidget);
      // The icon itself is not read: the button's name is.
      expect(find.bySemanticsLabel('icon:pause'), findsNothing);
      semantics.dispose();
    });

    testWidgets('stand on the document bar and its search', (tester) async {
      final semantics = tester.ensureSemantics();
      final document = FakeDocument(found: const {'a': 2});
      await pumpReader(
        tester,
        items: [item('a.pdf')],
        engines: MediaReaderEngines([DocumentEngine(document)]),
        chrome: chrome,
      );
      await tester.pump();

      expect(find.text('icon:pages'), findsOneWidget);
      expect(find.text('icon:search'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Search'));
      await tester.pumpAndSettle();

      expect(find.text('icon:up'), findsOneWidget);
      expect(find.text('icon:down'), findsOneWidget);
      expect(find.text('icon:close'), findsOneWidget);
      expect(painted(), findsNothing);
      semantics.dispose();
    });

    testWidgets("stand on the reader's close button", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(
        tester,
        items: pictures(1),
        engines: MediaReaderEngines([
          FakeEngine('fake', kinds: {MediaKind.picture}),
        ]),
        chrome: chrome,
        onDismissed: () {},
      );

      expect(find.text('icon:close'), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      expect(asked.single, (MediaReaderGlyph.close, chrome.foreground, 24.0));
      semantics.dispose();
    });

    testWidgets('stand on the audio bar', (tester) async {
      final semantics = tester.ensureSemantics();
      final coordinator = FakeAudioPlayers().coordinator();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              child: MediaReaderAudioBar(
                item: MediaReaderItem(
                  id: 'voice',
                  name: 'voice.m4a',
                  source: MediaReaderSource.remote(FakeResolve().call),
                  duration: const Duration(seconds: 42),
                ),
                coordinator: coordinator,
                color: const Color(0xFF102030),
                glyph: words,
              ),
            ),
          ),
        ),
      );

      expect(find.text('icon:play'), findsOneWidget);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      expect(asked.single, (
        MediaReaderGlyph.play,
        const Color(0xFF102030),
        24.0,
      ));
      semantics.dispose();
    });

    testWidgets('a glyph the host leaves null is drawn by the reader', (
      tester,
    ) async {
      final engine = FakeEngine('fake', kinds: {MediaKind.video});
      await pumpReader(
        tester,
        items: [item('a.mp4')],
        engines: MediaReaderEngines([engine]),
        chrome: MediaReaderChrome(
          glyph: (context, glyph, colour, size) => switch (glyph) {
            MediaReaderGlyph.play => const Text('icon:play'),
            _ => null,
          },
        ),
      );
      engine.pages['a.mp4']!.playback.value = FakePlayback();
      await tester.pump();

      expect(find.text('icon:play'), findsOneWidget);
      expect(find.text('icon:sound'), findsNothing);
      // The mute button: the reader's own drawing.
      expect(painted(), findsOneWidget);
    });

    testWidgets('without a host builder, every glyph is drawn', (tester) async {
      final engine = FakeEngine('fake', kinds: {MediaKind.video});
      await pumpReader(
        tester,
        items: [item('a.mp4')],
        engines: MediaReaderEngines([engine]),
      );
      engine.pages['a.mp4']!.playback.value = FakePlayback();
      await tester.pump();

      expect(painted(), findsNWidgets(2));
    });
  });
}
