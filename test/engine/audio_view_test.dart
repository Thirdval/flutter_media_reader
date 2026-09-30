import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/transport_bar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_audio.dart';
import '../support/fakes.dart';

void main() {
  late FakeAudioPlayers players;
  late MediaReaderAudioCoordinator coordinator;
  late MediaReaderEngines engines;
  setUp(() {
    players = FakeAudioPlayers();
    coordinator = players.coordinator();
    engines = MediaReaderEngines([
      MediaReaderAudioEngine(coordinator: coordinator),
    ]);
  });

  MediaReaderItem audio(
    String name,
    FakeResolve host, {
    List<double>? peaks,
    Duration? duration,
  }) => MediaReaderItem(
    id: name,
    name: name,
    source: MediaReaderSource.remote(host.call),
    peaks: peaks,
    duration: duration,
  );

  Future<void> tapControl(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  group('in the reader', () {
    testWidgets('a file plays when its page comes on screen', (tester) async {
      final host = FakeResolve();
      await pumpReader(tester, items: [audio('a.mp3', host)], engines: engines);
      await tester.pumpAndSettle();

      expect(host.calls, 1);
      expect(players.last.playing, isTrue);
      expect(find.byType(MediaReaderTransportBar), findsOneWidget);
      expect(find.text('a.mp3'), findsWidgets);
    });

    testWidgets('a neighbour asks for nothing', (tester) async {
      final second = FakeResolve();
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve()), audio('b.mp3', second)],
        engines: engines,
      );
      await tester.pumpAndSettle();

      expect(second.calls, 0);
      expect(players.made, hasLength(1));
    });

    testWidgets('the transport scrubs along the waveform the host gave', (
      tester,
    ) async {
      final peaks = [for (var i = 0; i < 100; i++) (i % 10) / 10];
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve(), peaks: peaks)],
        engines: engines,
      );
      await tester.pumpAndSettle();

      final waveform = tester.widget<MediaReaderWaveform>(
        find.byType(MediaReaderWaveform),
      );
      expect(waveform.peaks, peaks);

      final track = tester.getRect(find.byType(MediaReaderWaveform));
      await tester.tapAt(track.center);
      await tester.pumpAndSettle();

      expect(players.last.seeks.single.inSeconds, 30);
    });

    testWidgets('the transport pauses, plays and changes the speed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve())],
        engines: engines,
      );
      await tester.pumpAndSettle();

      await tapControl(tester, 'Pause');
      expect(players.last.playing, isFalse);

      await tapControl(tester, 'Play');
      expect(players.last.playing, isTrue);

      await tester.tap(find.text('1×'));
      await tester.pumpAndSettle();
      expect(players.last.state.value.speed, 1.5);
      semantics.dispose();
    });

    testWidgets('paged away, it stops; back, it goes on', (tester) async {
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve()), item('b.glb')],
        engines: engines,
      );
      await tester.pumpAndSettle();
      final player = players.last;

      await swipeToNext(tester);
      expect(player.playing, isFalse);

      await swipeToPrevious(tester);
      expect(player.playing, isTrue);
      expect(players.made, hasLength(1));
    });

    testWidgets('two audio files in a row never play at once', (tester) async {
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve()), audio('b.mp3', FakeResolve())],
        engines: engines,
      );
      await tester.pumpAndSettle();

      await swipeToNext(tester);

      expect(players.alive, hasLength(1));
      expect(players.alive.single.location!.uri.path, '/1');
      expect(players.made.first.disposed, isTrue);
      expect(players.last.playing, isTrue);
    });

    testWidgets('the file stops when the reader is closed', (tester) async {
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve())],
        engines: engines,
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(players.alive, isEmpty);
    });

    testWidgets('a file the host describes again is asked for where the '
        'host says now', (tester) async {
      final before = FakeResolve();
      final after = FakeResolve();
      await pumpReader(
        tester,
        items: [audio('a.mp3', before)],
        engines: engines,
      );
      await tester.pumpAndSettle();

      // The host rebuilds with a new item for the same file.
      await pumpReader(
        tester,
        items: [audio('a.mp3', after)],
        engines: engines,
      );
      await tester.pumpAndSettle();
      expect(players.made, hasLength(1));
      expect(players.last.playing, isTrue);

      // The player loses the file: the fresh location is the new host's.
      players.last.giveUp('HTTP 410');
      await tester.pumpAndSettle();

      expect(before.calls, 1);
      expect(after.calls, 1);
      expect(players.last.playing, isTrue);
    });

    testWidgets('a file the player cannot open goes to the card, and a '
        'retry opens it again', (tester) async {
      players.openError = 'unsupported';
      await pumpReader(
        tester,
        items: [audio('a.mp3', FakeResolve())],
        engines: engines,
      );
      await tester.pumpAndSettle();

      expect(find.text('This file could not be opened.'), findsOneWidget);
      expect(find.byType(MediaReaderTransportBar), findsNothing);

      players.openError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('This file could not be opened.'), findsNothing);
      expect(players.last.playing, isTrue);
    });

    testWidgets("a file the host says is unavailable shows the host's "
        'words', (tester) async {
      final host = FakeResolve()
        ..failure = const MediaReaderUnavailable('Still being processed.');
      await pumpReader(tester, items: [audio('a.mp3', host)], engines: engines);
      await tester.pumpAndSettle();

      expect(find.text('Still being processed.'), findsOneWidget);
    });

    testWidgets('an Ogg plays through its MP3 where the player needs it', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final file = FakeResolve();
      final mp3 = FakeResolve();
      await pumpReader(
        tester,
        items: [
          MediaReaderItem(
            id: 'voice',
            name: 'voice.ogg',
            source: MediaReaderSource.remote(file.call),
            preview: MediaReaderPreview(
              source: MediaReaderSource.remote(mp3.call),
              contentType: 'audio/mpeg',
            ),
          ),
        ],
        engines: engines,
      );
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;

      expect(mp3.calls, 1);
      expect(file.calls, 0);
      expect(players.last.playing, isTrue);
    });
  });

  group('a voice note in a chat and in the reader', () {
    /// A chat with one voice note, and a way to open the reader over it.
    Future<BuildContext> pumpChat(
      WidgetTester tester,
      MediaReaderItem note,
    ) async {
      late BuildContext chat;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
          home: Builder(
            builder: (context) {
              chat = context;
              return Center(
                child: SizedBox(
                  width: 300,
                  child: MediaReaderAudioBar(
                    item: note,
                    coordinator: coordinator,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              );
            },
          ),
        ),
      );
      return chat;
    }

    testWidgets('share one player: the note goes on playing when it is '
        'opened, and when the reader is closed', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = FakeResolve();
      final note = audio('voice.m4a', host);
      final chat = await pumpChat(tester, note);

      await tester.tap(find.bySemanticsLabel('Play'));
      await tester.pumpAndSettle();
      players.last.playedTo(const Duration(seconds: 7));
      expect(players.last.playing, isTrue);

      final closed = showMediaReader(chat, items: [note], engines: engines);
      await tester.pumpAndSettle();

      // The same player, where it was, still playing.
      expect(players.made, hasLength(1));
      expect(players.last.playing, isTrue);
      expect(find.byType(MediaReaderTransportBar), findsOneWidget);
      expect(find.text('0:07'), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await closed;

      expect(players.alive, hasLength(1));
      expect(players.last.playing, isTrue);
      semantics.dispose();
    });

    testWidgets("the reader's transport and the bar drive the same note", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final note = audio('voice.m4a', FakeResolve());
      final chat = await pumpChat(tester, note);
      final closed = showMediaReader(chat, items: [note], engines: engines);
      await tester.pumpAndSettle();
      expect(players.last.playing, isTrue);

      // Paused in the reader: the bar behind it shows the note paused.
      await tester.tap(find.bySemanticsLabel('Pause').last);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await closed;

      expect(players.last.playing, isFalse);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
      semantics.dispose();
    });
  });
}
