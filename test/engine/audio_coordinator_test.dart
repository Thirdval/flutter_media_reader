import 'dart:typed_data';

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

  /// A session for a remote file the fake host resolves.
  MediaReaderAudioSession attach(
    String id,
    FakeResolve host, {
    Duration? duration,
  }) => coordinator.attach(
    id,
    source: MediaReaderSource.remote(host.call),
    duration: duration,
  );

  group('a session', () {
    test('opens its file where the host says, and plays', () async {
      final host = FakeResolve();
      final session = attach('note', host);
      expect(host.calls, 0);

      await session.play();

      expect(host.calls, 1);
      expect(players.last.location!.uri, Uri.parse('https://files.test/1'));
      expect(session.state.value.playing, isTrue);
      expect(coordinator.active.value, same(session));
    });

    test('opens a file on the device from its path', () async {
      final session = coordinator.attach(
        'note',
        source: const MediaReaderSource.file('/notes/a.m4a'),
      );

      await session.play();

      expect(players.last.path, '/notes/a.m4a');
      expect(players.last.location, isNull);
    });

    test("shows the host's length until the player knows its own", () async {
      final session = attach(
        'note',
        FakeResolve(),
        duration: const Duration(seconds: 42),
      );
      expect(session.state.value.duration, const Duration(seconds: 42));

      await session.play();

      expect(session.state.value.duration, const Duration(minutes: 1));
    });

    test('pauses, and plays on with the same player', () async {
      final session = attach('note', FakeResolve());
      await session.play();

      await session.pause();
      expect(session.state.value.playing, isFalse);
      await session.play();

      expect(players.made, hasLength(1));
      expect(session.state.value.playing, isTrue);
    });

    test('seeks, keeps its speed, and mutes', () async {
      final session = attach('note', FakeResolve());
      await session.setSpeed(1.5);
      await session.play();

      await session.seekTo(const Duration(seconds: 30));
      await session.setMuted(true);

      expect(players.last.seeks, [const Duration(seconds: 30)]);
      expect(session.state.value.speed, 1.5);
      expect(session.state.value.muted, isTrue);
    });

    test(
      'that has not played yet is moved by a seek, and opens there',
      () async {
        final session = attach('note', FakeResolve());

        await session.seekTo(const Duration(seconds: 20));
        expect(players.made, isEmpty);
        expect(session.state.value.position, const Duration(seconds: 20));

        await session.play();
        expect(players.last.openedAt, const Duration(seconds: 20));
      },
    );

    test('two plays while the file opens make one player', () async {
      final host = FakeResolve();
      final session = attach('note', host);

      await Future.wait([session.play(), session.play()]);

      expect(players.made, hasLength(1));
      expect(host.calls, 1);
      expect(session.state.value.playing, isTrue);
    });

    test('that has ended plays again from the start', () async {
      final session = attach('note', FakeResolve());
      await session.play();
      players.last.end();
      expect(session.state.value.ended, isTrue);

      await session.play();

      expect(players.last.seeks, [Duration.zero]);
      expect(session.state.value.playing, isTrue);
    });
  });

  group('one player at a time', () {
    test('starting a file stops the one that plays', () async {
      final first = attach('a', FakeResolve());
      final second = attach('b', FakeResolve());
      await first.play();
      players.last.playedTo(const Duration(seconds: 12));

      await second.play();

      expect(players.alive, hasLength(1));
      expect(first.state.value.playing, isFalse);
      expect(second.state.value.playing, isTrue);
      expect(coordinator.active.value, same(second));
      // The first keeps its place.
      expect(first.state.value.position, const Duration(seconds: 12));
    });

    test('a file that was stopped goes on from where it was', () async {
      final first = attach('a', FakeResolve());
      final second = attach('b', FakeResolve());
      await first.play();
      players.last.playedTo(const Duration(seconds: 12));
      await second.play();

      await first.play();

      expect(players.last.openedAt, const Duration(seconds: 12));
      expect(players.alive, hasLength(1));
      expect(second.state.value.playing, isFalse);
    });

    test('the same file attached twice is one session', () {
      final bar = attach('note', FakeResolve());
      final page = attach('note', FakeResolve());

      expect(page, same(bar));
    });

    test('its holders ask the host once between them', () async {
      final host = FakeResolve();
      final bar = attach('note', host);
      await bar.play();

      final page = attach('note', host);
      await page.play();
      await page.seekTo(const Duration(seconds: 10));

      expect(host.calls, 1);
      expect(players.made, hasLength(1));
    });

    test('audio in memory has no session', () {
      expect(
        () => coordinator.attach(
          'note',
          source: MediaReaderSource.bytes(Uint8List(4)),
        ),
        throwsArgumentError,
      );
    });

    test('stop stops whatever plays', () async {
      final session = attach('note', FakeResolve());
      await session.play();

      await coordinator.stop();

      expect(players.alive, isEmpty);
      expect(session.state.value.playing, isFalse);
      expect(coordinator.active.value, isNull);
      // Its holder has it still, where it was.
      expect(attach('note', FakeResolve()), same(session));
    });

    test('stop forgets a file that played on with nobody showing it', () async {
      final session = attach('note', FakeResolve());
      await session.play();
      coordinator.detach(session, stop: false);
      await pumpEventQueue();

      await coordinator.stop();

      expect(players.alive, isEmpty);
      expect(attach('note', FakeResolve()), isNot(same(session)));
    });
  });

  group('letting go', () {
    test('the file stops when its last holder lets go', () async {
      final bar = attach('note', FakeResolve());
      final page = attach('note', FakeResolve());
      await page.play();

      coordinator.detach(page);
      await pumpEventQueue();
      expect(players.alive, hasLength(1));
      expect(bar.state.value.playing, isTrue);

      coordinator.detach(bar);
      await pumpEventQueue();
      expect(players.alive, isEmpty);
    });

    test('a file let go of with stop: false plays on to its end', () async {
      final session = attach('note', FakeResolve());
      await session.play();

      coordinator.detach(session, stop: false);
      await pumpEventQueue();
      expect(players.alive, hasLength(1));
      expect(session.state.value.playing, isTrue);

      players.last.end();
      expect(players.alive, isEmpty);
      // It is forgotten: the next to attach starts afresh.
      expect(attach('note', FakeResolve()), isNot(same(session)));
    });

    test('a paused file let go of with stop: false is let go of all the '
        'same', () async {
      final session = attach('note', FakeResolve());
      await session.play();
      await session.pause();

      coordinator.detach(session, stop: false);
      await pumpEventQueue();

      expect(players.alive, isEmpty);
    });

    test('a file that has ended is let go of with stop: false all the '
        'same', () async {
      final session = attach('note', FakeResolve());
      await session.play();
      players.last.end();

      coordinator.detach(session, stop: false);
      await pumpEventQueue();

      expect(players.alive, isEmpty);
      expect(coordinator.active.value, isNull);
    });

    test('a holder that lets go and takes hold again at once keeps the file '
        'playing', () async {
      final host = FakeResolve();
      final session = attach('note', host);
      await session.play();

      // A rebuild: the old widget lets go, the new one attaches.
      coordinator.detach(session);
      final again = attach('note', host);
      await pumpEventQueue();

      expect(again, same(session));
      expect(players.alive, hasLength(1));
      expect(session.state.value.playing, isTrue);
    });
  });

  group('a location that runs out', () {
    late DateTime now;
    setUp(() {
      now = DateTime(2026, 9, 30, 12);
      coordinator = players.coordinator(now: () => now);
    });

    /// A session whose location is kept on the test's clock.
    MediaReaderAudioSession attachTimed(FakeResolve host) =>
        coordinator.attach('note', source: MediaReaderSource.remote(host.call));

    test('is renewed before the file is played again', () async {
      final host = FakeResolve(
        validFor: const Duration(minutes: 15),
        now: () => now,
      );
      final session = attachTimed(host);
      await session.play();
      players.last.playedTo(const Duration(seconds: 25));
      await session.pause();

      now = now.add(const Duration(minutes: 20));
      await session.play();

      expect(host.calls, 2);
      expect(players.made, hasLength(2));
      expect(players.last.location!.uri, Uri.parse('https://files.test/2'));
      expect(players.last.openedAt, const Duration(seconds: 25));
      expect(players.last.playing, isTrue);
      expect(players.alive, hasLength(1));
    });

    test('is renewed before a seek', () async {
      final host = FakeResolve(
        validFor: const Duration(minutes: 15),
        now: () => now,
      );
      final session = attachTimed(host);
      await session.play();

      now = now.add(const Duration(minutes: 20));
      await session.seekTo(const Duration(seconds: 40));

      expect(host.calls, 2);
      expect(players.last.openedAt, const Duration(seconds: 40));
    });

    test('is renewed once when the player gives up under way', () async {
      final host = FakeResolve();
      final session = attach('note', host);
      await session.play();
      players.last.playedTo(const Duration(seconds: 33));

      players.last.giveUp('HTTP 410');
      await pumpEventQueue();

      expect(host.calls, 2);
      expect(players.last.openedAt, const Duration(seconds: 33));
      expect(players.last.playing, isTrue);
      expect(session.failure.value, isNull);
    });

    test(
      'a player that gives up again at the same place fails the file',
      () async {
        final host = FakeResolve();
        final session = attach('note', host);
        await session.play();

        players.last.giveUp('decoder error');
        await pumpEventQueue();
        players.last.giveUp('decoder error');
        await pumpEventQueue();

        expect(host.calls, 2);
        expect(session.failure.value, 'decoder error');
        expect(session.state.value.playing, isFalse);
        expect(players.alive, isEmpty);
      },
    );
  });

  group('failing', () {
    test(
      'a file the player cannot open fails, and a new play tries again',
      () async {
        players.openError = StateError('unsupported');
        final session = attach('note', FakeResolve());

        await session.play();
        expect(session.failure.value, isStateError);
        expect(session.state.value.playing, isFalse);

        players.openError = null;
        await session.play();

        expect(session.failure.value, isNull);
        expect(session.state.value.playing, isTrue);
      },
    );

    test("the host's own failure is the session's", () async {
      final host = FakeResolve()
        ..failure = const MediaReaderUnavailable('Removed.');
      final session = attach('note', host);

      await session.play();

      expect(session.failure.value, isA<MediaReaderUnavailable>());
      expect(players.alive, isEmpty);
    });
  });
}
