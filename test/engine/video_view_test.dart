import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/shell/plain_widgets.dart';
import 'package:flutter_media_reader/src/shell/transport_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_video.dart';
import '../support/fakes.dart';

void main() {
  late FakeVideoPlatform platform;
  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  MediaReaderItem video(
    String name,
    FakeResolve host, {
    Map<String, String> headers = const {},
    WidgetBuilder? poster,
  }) => MediaReaderItem(
    id: name,
    name: name,
    source: MediaReaderSource.remote(() async {
      final location = await host.call();
      return MediaReaderLocation(
        location.uri,
        headers: headers,
        expiresAt: location.expiresAt,
      );
    }),
    poster: poster,
  );

  /// The players that are playing now.
  List<int> playing() => [
    for (final player in platform.players)
      if (player.playing) player.id,
  ];

  Future<void> tapControl(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  group('opening', () {
    testWidgets('on screen, the video is resolved, opened and played', (
      tester,
    ) async {
      final host = FakeResolve();
      await pumpReader(
        tester,
        items: [
          video('a.mp4', host, headers: {'x-token': 'abc'}),
        ],
      );
      await tester.pumpAndSettle();

      expect(host.calls, 1);
      expect(platform.last.source.sourceType, DataSourceType.network);
      expect(platform.last.source.uri, 'https://files.test/1');
      expect(platform.last.source.httpHeaders, {'x-token': 'abc'});
      expect(platform.last.playing, isTrue);
      expect(find.byType(MediaReaderTransportBar), findsOneWidget);
    });

    testWidgets('a neighbour asks for nothing: it shows its poster', (
      tester,
    ) async {
      final first = FakeResolve();
      final second = FakeResolve();
      await pumpReader(
        tester,
        items: [
          video('a.mp4', first),
          video(
            'b.mp4',
            second,
            poster: (context) => const Text('poster of b'),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(second.calls, 0);
      expect(platform.players, hasLength(1));
      expect(find.text('poster of b', skipOffstage: false), findsOneWidget);
    });

    testWidgets('the poster and a ring show until the player is there', (
      tester,
    ) async {
      platform.initializes = false;
      await pumpReader(
        tester,
        items: [
          video(
            'a.mp4',
            FakeResolve(),
            poster: (context) => const Text('poster of a'),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('poster of a'), findsOneWidget);
      expect(find.byType(MediaReaderBusy), findsOneWidget);
      expect(find.byType(MediaReaderTransportBar), findsNothing);

      platform.last.initialize();
      await tester.pumpAndSettle();

      expect(find.text('poster of a'), findsNothing);
      expect(find.byType(MediaReaderBusy), findsNothing);
      expect(find.byKey(const ValueKey('video-1')), findsOneWidget);
    });

    testWidgets('a video in a file is opened from the file', (tester) async {
      await pumpReader(
        tester,
        items: [
          item('a.mp4', source: const MediaReaderSource.file('/videos/a.mp4')),
        ],
      );
      await tester.pumpAndSettle();

      expect(platform.last.source.sourceType, DataSourceType.file);
      expect(platform.last.source.uri, endsWith('/videos/a.mp4'));
      expect(platform.last.playing, isTrue);
    });

    testWidgets('a ring shows while the player waits for data', (tester) async {
      await pumpReader(tester, items: [video('a.mp4', FakeResolve())]);
      await tester.pumpAndSettle();

      platform.last.buffering(true);
      await tester.pump();
      await tester.pump();
      expect(find.byType(MediaReaderBusy), findsOneWidget);

      platform.last.buffering(false);
      await tester.pump();
      await tester.pump();
      expect(find.byType(MediaReaderBusy), findsNothing);
    });
  });

  group('paging', () {
    Future<void> pumpTwo(WidgetTester tester) async {
      await pumpReader(
        tester,
        items: [
          video('a.mp4', FakeResolve()),
          video('b.mp4', FakeResolve()),
          item('c.glb'),
          item('d.glb'),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('two videos in a row never play at once', (tester) async {
      await pumpTwo(tester);
      expect(playing(), [1]);

      await swipeToNext(tester);
      expect(playing(), [2]);

      await swipeToPrevious(tester);
      expect(playing(), [1]);
    });

    testWidgets('a video the person paused stays paused when its page comes '
        'back', (tester) async {
      await pumpTwo(tester);
      await tapControl(tester, 'Pause');

      await swipeToNext(tester);
      await swipeToPrevious(tester);

      expect(playing(), isEmpty);
    });

    testWidgets('the player is released with its page', (tester) async {
      await pumpTwo(tester);

      await swipeToNext(tester);
      await swipeToNext(tester);
      await swipeToNext(tester);

      expect(platform.alive, isEmpty);
    });

    testWidgets('the transport is there for the video on screen only', (
      tester,
    ) async {
      await pumpTwo(tester);
      await swipeToNext(tester);
      await swipeToNext(tester);

      expect(find.byType(MediaReaderTransportBar), findsNothing);
    });
  });

  group('the transport', () {
    Future<FakePlayer> pumpPlaying(WidgetTester tester) async {
      await pumpReader(tester, items: [video('a.mp4', FakeResolve())]);
      await tester.pumpAndSettle();
      return platform.last;
    }

    testWidgets('pauses and plays', (tester) async {
      final semantics = tester.ensureSemantics();
      final player = await pumpPlaying(tester);

      await tapControl(tester, 'Pause');
      expect(player.playing, isFalse);

      await tapControl(tester, 'Play');
      expect(player.playing, isTrue);
      semantics.dispose();
    });

    testWidgets('shows the time played and the time left', (tester) async {
      final player = await pumpPlaying(tester);

      player.position = const Duration(seconds: 5);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('0:05'), findsOneWidget);
      expect(find.text('-0:55'), findsOneWidget);
    });

    testWidgets('seeks where the scrubber is tapped or dragged to', (
      tester,
    ) async {
      final player = await pumpPlaying(tester);
      final track = tester.getRect(find.byType(MediaReaderWaveform));

      await tester.tapAt(track.centerLeft + Offset(track.width * 0.5, 0));
      await tester.pumpAndSettle();
      expect(player.seeks.last.inSeconds, 30);

      await tester.dragFrom(
        track.centerLeft + Offset(track.width * 0.5, 0),
        Offset(track.width * 0.25, 0),
      );
      await tester.pumpAndSettle();
      expect(player.seeks.last.inSeconds, 45);
      // Scrubbing is not paging.
      expect(find.byKey(const ValueKey('video-1')), findsOneWidget);
    });

    testWidgets('goes round the speeds', (tester) async {
      final player = await pumpPlaying(tester);

      await tester.tap(find.text('1×'));
      await tester.pumpAndSettle();
      expect(player.speed, 1.5);

      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(player.speed, 2);

      await tester.tap(find.text('2×'));
      await tester.pumpAndSettle();
      expect(player.speed, 1);
    });

    testWidgets('mutes and unmutes', (tester) async {
      final semantics = tester.ensureSemantics();
      final player = await pumpPlaying(tester);

      await tapControl(tester, 'Mute');
      expect(player.volume, 0);

      await tapControl(tester, 'Unmute');
      expect(player.volume, 1);
      semantics.dispose();
    });

    testWidgets('plays an ended video from the start', (tester) async {
      final semantics = tester.ensureSemantics();
      final player = await pumpPlaying(tester);

      player.complete();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Play'), findsOneWidget);

      await tapControl(tester, 'Play');

      expect(player.seeks.last, Duration.zero);
      expect(player.playing, isTrue);
      semantics.dispose();
    });

    testWidgets('hides with the chrome', (tester) async {
      await pumpPlaying(tester);
      final play = tester.getCenter(find.byType(MediaReaderTransportBar));

      await tester.tapAt(const Offset(400, 200));
      await tester.pumpAndSettle();
      // Hidden, it takes no taps: this one reaches the canvas instead.
      await tester.tapAt(play);
      await tester.pumpAndSettle();

      expect(platform.last.playing, isTrue);
    });

    testWidgets("gives way to the host's controls", (tester) async {
      await pumpReader(
        tester,
        items: [video('a.mp4', FakeResolve())],
        chrome: MediaReaderChrome(
          controls: (context, state) => Text(
            state.playback == null ? 'nothing plays' : 'the glass transport',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('the glass transport'), findsOneWidget);
      expect(find.byType(MediaReaderTransportBar), findsNothing);
    });
  });

  group('a location that runs out', () {
    /// A host whose URLs are good for a moment longer than the margin the
    /// reader keeps, so that they are stale a moment after they are
    /// given.
    FakeResolve shortLived() =>
        FakeResolve(validFor: const Duration(seconds: 30, milliseconds: 300));

    Future<void> letItRunOut(WidgetTester tester) => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );

    testWidgets('is renewed before the video is played again, and the video '
        'goes on where it was', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = shortLived();
      await pumpReader(tester, items: [video('a.mp4', host)]);
      await tester.pumpAndSettle();
      platform.last.position = const Duration(seconds: 20);
      await tester.pump(const Duration(milliseconds: 200));
      await tapControl(tester, 'Pause');

      await letItRunOut(tester);
      await tapControl(tester, 'Play');

      expect(host.calls, 2);
      expect(platform.players, hasLength(2));
      expect(platform.last.source.uri, 'https://files.test/2');
      expect(platform.last.seeks, [const Duration(seconds: 20)]);
      expect(platform.last.playing, isTrue);
      expect(platform.players.first.disposed, isTrue);
      semantics.dispose();
    });

    testWidgets('is renewed before a seek', (tester) async {
      final host = shortLived();
      await pumpReader(tester, items: [video('a.mp4', host)]);
      await tester.pumpAndSettle();
      final track = tester.getRect(find.byType(MediaReaderWaveform));

      await letItRunOut(tester);
      await tester.tapAt(track.center);
      await tester.pumpAndSettle();

      expect(host.calls, 2);
      expect(platform.last.source.uri, 'https://files.test/2');
      expect(platform.last.seeks.last.inSeconds, 30);
      expect(platform.last.playing, isTrue);
    });

    testWidgets('is renewed when the player gives up under way', (
      tester,
    ) async {
      final host = FakeResolve();
      await pumpReader(tester, items: [video('a.mp4', host)]);
      await tester.pumpAndSettle();
      platform.last.position = const Duration(seconds: 40);
      await tester.pump(const Duration(milliseconds: 200));

      platform.last.fail('Response code: 410');
      await tester.pumpAndSettle();

      expect(host.calls, 2);
      expect(platform.last.source.uri, 'https://files.test/2');
      expect(platform.last.seeks, [const Duration(seconds: 40)]);
      expect(platform.last.playing, isTrue);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a player that gives up again at the same place goes to the '
        'card', (tester) async {
      final host = FakeResolve();
      await pumpReader(tester, items: [video('a.mp4', host)]);
      await tester.pumpAndSettle();

      platform.last.fail('decoder error');
      await tester.pumpAndSettle();
      platform.last.fail('decoder error');
      await tester.pumpAndSettle();

      expect(host.calls, 2);
      expect(find.text('This file could not be opened.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(platform.alive, isEmpty);
      expect(find.byType(MediaReaderTransportBar), findsNothing);
    });
  });

  group('failing', () {
    testWidgets('a video the player cannot open goes to the card, and a '
        'retry opens it again', (tester) async {
      platform.openError = 'unsupported codec';
      await pumpReader(tester, items: [video('a.mp4', FakeResolve())]);
      await tester.pumpAndSettle();

      expect(find.text('This file could not be opened.'), findsOneWidget);
      expect(platform.alive, isEmpty);

      platform.openError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('This file could not be opened.'), findsNothing);
      expect(platform.last.playing, isTrue);
    });

    testWidgets("a video the host says is unavailable shows the host's "
        'words', (tester) async {
      final host = FakeResolve()
        ..failure = const MediaReaderUnavailable('Still being processed.');
      await pumpReader(tester, items: [video('a.mp4', host)]);
      await tester.pumpAndSettle();

      expect(find.text('Still being processed.'), findsOneWidget);
      expect(platform.players, isEmpty);
    });

    testWidgets('a host that cannot be reached is said so', (tester) async {
      final host = FakeResolve()..failure = StateError('offline');
      await pumpReader(tester, items: [video('a.mp4', host)]);
      await tester.pumpAndSettle();

      expect(
        find.text('This file could not be reached. Check the connection.'),
        findsOneWidget,
      );
    });
  });
}
