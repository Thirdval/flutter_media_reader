import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/engine/media_reader_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_audio.dart';
import '../support/fake_video.dart';
import '../support/fakes.dart';

void main() {
  group('MediaReaderSound', () {
    test('what takes the sound quiets what had it', () {
      final quieted = <String>[];
      final first = Object();
      final second = Object();

      MediaReaderSound.take(first, quiet: () => quieted.add('first'));
      expect(quieted, isEmpty);

      MediaReaderSound.take(second, quiet: () => quieted.add('second'));
      expect(quieted, ['first']);

      // It has the sound already: nobody is told anything.
      MediaReaderSound.take(second, quiet: () => quieted.add('second'));
      expect(quieted, ['first']);
      MediaReaderSound.release(second);
    });

    test('what is gone is not told to be quiet', () {
      final quieted = <String>[];
      final first = Object();
      final second = Object();
      MediaReaderSound.take(first, quiet: () => quieted.add('first'));

      MediaReaderSound.release(first);
      MediaReaderSound.take(second, quiet: () => quieted.add('second'));

      expect(quieted, isEmpty);
      MediaReaderSound.release(second);
    });
  });

  group('a voice note and a video', () {
    late FakeVideoPlatform platform;
    late FakeAudioPlayers players;
    late MediaReaderAudioSession note;
    setUp(() {
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      players = FakeAudioPlayers();
      note = players.coordinator().attach(
        'note',
        source: MediaReaderSource.remote(FakeResolve().call),
      );
    });

    final video = MediaReaderItem(
      id: 'a.mp4',
      name: 'a.mp4',
      source: MediaReaderSource.remote(FakeResolve().call),
    );

    testWidgets('a video that starts in the reader stops the note that '
        'plays', (tester) async {
      await note.play();
      players.last.playedTo(const Duration(seconds: 9));
      expect(players.last.playing, isTrue);

      await pumpReader(tester, items: [video]);
      await tester.pumpAndSettle();

      expect(platform.last.playing, isTrue);
      expect(players.last.playing, isFalse);
      // The note keeps its place.
      expect(note.state.value.position, const Duration(seconds: 9));
    });

    testWidgets('a note that starts stops the video that plays', (
      tester,
    ) async {
      await pumpReader(tester, items: [video]);
      await tester.pumpAndSettle();
      expect(platform.last.playing, isTrue);

      await note.play();
      await tester.pumpAndSettle();

      expect(players.last.playing, isTrue);
      expect(platform.last.playing, isFalse);
    });

    testWidgets('a video that is closed is told nothing', (tester) async {
      await pumpReader(tester, items: [video]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(platform.alive, isEmpty);

      await note.play();

      expect(players.last.playing, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
