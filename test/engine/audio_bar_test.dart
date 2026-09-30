import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_audio.dart';
import '../support/fakes.dart';

void main() {
  late FakeAudioPlayers players;
  late MediaReaderAudioCoordinator coordinator;
  setUp(() {
    players = FakeAudioPlayers();
    coordinator = players.coordinator();
  });

  MediaReaderItem note(
    String id,
    FakeResolve host, {
    String name = 'voice.m4a',
    Duration? duration = const Duration(seconds: 42),
    MediaReaderPreview? preview,
  }) => MediaReaderItem(
    id: id,
    name: name,
    source: MediaReaderSource.remote(host.call),
    duration: duration,
    peaks: [for (var i = 0; i < 100; i++) (i % 7) / 7],
    preview: preview,
  );

  /// A chat's bubbles, one bar for each note.
  Future<void> pumpBars(
    WidgetTester tester,
    List<MediaReaderItem> notes, {
    bool stopsWhenRemoved = false,
    ValueChanged<Object>? onFailure,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 14),
        child: Center(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final note in notes)
                  MediaReaderAudioBar(
                    key: ValueKey(note.id),
                    item: note,
                    coordinator: coordinator,
                    color: const Color(0xFF102030),
                    stopsWhenRemoved: stopsWhenRemoved,
                    onFailure: onFailure,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  group('MediaReaderAudioBar', () {
    testWidgets("shows the host's length and asks for nothing until it is "
        'played', (tester) async {
      final host = FakeResolve();
      await pumpBars(tester, [note('a', host)]);

      expect(find.text('0:42'), findsOneWidget);
      expect(host.calls, 0);
      expect(players.made, isEmpty);
    });

    testWidgets('plays and pauses the note', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = FakeResolve();
      await pumpBars(tester, [note('a', host)]);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      expect(host.calls, 1);
      expect(players.last.playing, isTrue);

      await tester.tap(find.bySemanticsLabel('Pause'));
      await tester.pumpAndSettle();
      expect(players.last.playing, isFalse);
      semantics.dispose();
    });

    testWidgets('a note that cannot be played goes back to its play button, '
        'and the host is told why', (tester) async {
      final semantics = tester.ensureSemantics();
      final failures = <Object>[];
      final host = FakeResolve()
        ..failure = const MediaReaderUnavailable('Removed.');
      await pumpBars(tester, [note('a', host)], onFailure: failures.add);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();

      expect(
        failures.single,
        isA<MediaReaderUnavailable>().having(
          (e) => e.reason,
          'reason',
          'Removed.',
        ),
      );
      expect(find.bySemanticsLabel('Play'), findsOneWidget);

      // A second try, once the host has the file again.
      host.failure = null;
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      expect(players.last.playing, isTrue);
      expect(failures, hasLength(1));
      semantics.dispose();
    });

    testWidgets('a tap while the note is on its way stops it from playing', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final asked = Completer<MediaReaderLocation>();
      await pumpBars(tester, [
        MediaReaderItem(
          id: 'a',
          name: 'voice.m4a',
          source: MediaReaderSource.remote(() => asked.future),
        ),
      ]);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pump();
      // On its way: the button stops it.
      await tester.tap(find.bySemanticsLabel('Pause'));
      await tester.pump();
      asked.complete(MediaReaderLocation(Uri.parse('https://files.test/a')));
      await tester.pumpAndSettle();

      expect(players.last.playing, isFalse);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('shows the time played once it has started, and the speed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBars(tester, [note('a', FakeResolve())]);
      expect(find.text('1×'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      players.last.playedTo(const Duration(seconds: 9));
      await tester.pump();

      expect(find.text('0:09'), findsOneWidget);

      await tester.tap(find.text('1×'));
      await tester.pumpAndSettle();
      expect(players.last.state.value.speed, 1.5);
      semantics.dispose();
    });

    testWidgets('draws the peaks, and a tap along them seeks', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBars(tester, [note('a', FakeResolve())]);
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();

      final waveform = tester.widget<MediaReaderWaveform>(
        find.byType(MediaReaderWaveform),
      );
      expect(waveform.peaks, hasLength(100));

      final track = tester.getRect(find.byType(MediaReaderWaveform));
      await tester.tapAt(track.centerLeft + Offset(track.width * 0.5, 0));
      await tester.pumpAndSettle();

      // Halfway through the minute the player reports.
      expect(players.last.seeks.single.inSeconds, 30);
      semantics.dispose();
    });

    testWidgets('starting another note stops the one that plays', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBars(tester, [
        note('a', FakeResolve()),
        note('b', FakeResolve()),
      ]);

      await tester.tap(find.bySemanticsLabel('Play').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();

      expect(players.alive, hasLength(1));
      expect(players.made.first.disposed, isTrue);
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a note that is playing plays on when its bubble goes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBars(tester, [note('a', FakeResolve())]);
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();

      // The bubble scrolls out of sight.
      await pumpBars(tester, []);
      await tester.pump();

      expect(players.alive, hasLength(1));
      expect(players.last.playing, isTrue);

      // The host leaves the conversation.
      await coordinator.stop();
      expect(players.alive, isEmpty);
      semantics.dispose();
    });

    testWidgets('a bar told to stop with its bubble stops the note', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBars(tester, [
        note('a', FakeResolve()),
      ], stopsWhenRemoved: true);
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();

      await pumpBars(tester, [], stopsWhenRemoved: true);
      await tester.pump();

      expect(players.alive, isEmpty);
      semantics.dispose();
    });

    testWidgets('a rebuild keeps the note playing', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = FakeResolve();
      await pumpBars(tester, [note('a', host)]);
      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();

      // The chat rebuilds: a new item for the same file, a new closure.
      await pumpBars(tester, [note('a', host)]);
      await tester.pumpAndSettle();

      expect(players.made, hasLength(1));
      expect(players.last.playing, isTrue);
      expect(host.calls, 1);
      semantics.dispose();
    });

    testWidgets('an Ogg plays through its MP3 where the player needs it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final file = FakeResolve();
      final mp3 = FakeResolve();
      await pumpBars(tester, [
        note(
          'a',
          file,
          name: 'voice.ogg',
          preview: MediaReaderPreview(
            source: MediaReaderSource.remote(mp3.call),
            contentType: 'audio/mpeg',
          ),
        ),
      ]);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(mp3.calls, 1);
      expect(file.calls, 0);
      expect(players.last.playing, isTrue);
      semantics.dispose();
    });

    testWidgets('a note the platform cannot play is there, and does nothing', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final host = FakeResolve();
      await pumpBars(tester, [note('a', host, name: 'voice.ogg')]);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(host.calls, 0);
      expect(players.made, isEmpty);
      expect(find.text('0:42'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('runs left to right in a right-to-left language', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 320,
              child: MediaReaderAudioBar(
                item: note('a', FakeResolve()),
                coordinator: coordinator,
                color: const Color(0xFF102030),
              ),
            ),
          ),
        ),
      );

      final play = tester.getCenter(find.bySemanticsLabel('Play'));
      final time = tester.getCenter(find.text('0:42'));

      expect(play.dx, lessThan(time.dx));
      semantics.dispose();
    });
  });
}
