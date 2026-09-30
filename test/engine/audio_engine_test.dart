import 'package:flutter/foundation.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/engine/audio/audio_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../support/fake_video.dart';
import '../support/fakes.dart';

void main() {
  const engine = MediaReaderAudioEngine();

  MediaReaderItem audio(String name, {String? contentType}) => item(
    name,
    contentType: contentType,
    source: const MediaReaderSource.file('/audio/file'),
  );

  group('MediaReaderAudioEngine.canShow', () {
    test('MP3, M4A, AAC, WAV and FLAC play on every platform', () {
      for (final file in [
        audio('a.mp3'),
        audio('a.m4a'),
        audio('voice-1790.m4a', contentType: 'video/mp4'),
        audio('a.aac'),
        audio('a.wav'),
        audio('a.flac'),
      ]) {
        for (final platform in [
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        ]) {
          expect(engine.canShow(file, platform), isTrue, reason: file.name);
        }
      }
    });

    test('Ogg and Opus play where the player plays them', () {
      for (final name in ['a.ogg', 'a.opus', 'a.oga']) {
        expect(engine.canShow(audio(name), TargetPlatform.android), isTrue);
        expect(engine.canShow(audio(name), TargetPlatform.windows), isTrue);
        expect(engine.canShow(audio(name), TargetPlatform.linux), isTrue);
        expect(engine.canShow(audio(name), TargetPlatform.iOS), isFalse);
        expect(engine.canShow(audio(name), TargetPlatform.macOS), isFalse);
      }
    });

    test('audio in memory has no player', () {
      expect(engine.canShow(item('a.mp3'), TargetPlatform.android), isFalse);
    });

    test('other kinds are not audio', () {
      for (final name in ['a.mp4', 'a.jpg', 'a.pdf']) {
        expect(engine.canShow(audio(name), TargetPlatform.android), isFalse);
      }
    });
  });

  group('MediaReaderAudioEngine.playable', () {
    final ogg = item(
      'voice.ogg',
      source: const MediaReaderSource.file('/audio/voice.ogg'),
      preview: const MediaReaderPreview(
        source: MediaReaderSource.file('/audio/voice.mp3'),
        contentType: 'audio/mpeg',
      ),
    );

    test('is the file itself where the player plays it', () {
      expect(
        MediaReaderAudioEngine.playable(ogg, TargetPlatform.android),
        same(ogg),
      );
    });

    test('is its preview where the player does not', () {
      final played = MediaReaderAudioEngine.playable(ogg, TargetPlatform.iOS)!;

      expect(played.format, 'mp3');
      expect(played.id, ogg.id);
    });

    test('is nothing when neither plays', () {
      expect(
        MediaReaderAudioEngine.playable(audio('voice.ogg'), TargetPlatform.iOS),
        isNull,
      );
    });
  });

  group('the standard registry', () {
    test('plays audio with the audio engine', () {
      expect(
        MediaReaderEngines.standard
            .select(audio('a.mp3'), TargetPlatform.iOS)
            .engine
            .id,
        'audio',
      );
    });
  });

  group('createMediaReaderAudioPlayer', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is video_player, which fvp implements, on Windows and Linux', () {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          createMediaReaderAudioPlayer(),
          isA<MediaReaderVideoAudioPlayer>(),
        );
      }
    });
  });

  group('MediaReaderVideoAudioPlayer', () {
    late FakeVideoPlatform platform;
    setUp(() {
      platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
    });

    testWidgets('opens, plays, seeks and reports through video_player', (
      tester,
    ) async {
      final player = MediaReaderVideoAudioPlayer();

      await player.open(
        location: MediaReaderLocation(
          Uri.parse('https://files.test/voice.ogg'),
          headers: const {'x-token': 'abc'},
        ),
        at: const Duration(seconds: 5),
      );
      await player.play();
      await player.setSpeed(1.5);
      await player.setMuted(true);
      await player.seek(const Duration(seconds: 20));
      await tester.pump(const Duration(milliseconds: 200));

      expect(platform.last.source.uri, 'https://files.test/voice.ogg');
      expect(platform.last.source.httpHeaders, {'x-token': 'abc'});
      expect(platform.last.seeks, [
        const Duration(seconds: 5),
        const Duration(seconds: 20),
      ]);
      expect(platform.last.playing, isTrue);
      expect(platform.last.speed, 1.5);
      expect(platform.last.volume, 0);
      expect(player.state.value.playing, isTrue);
      expect(player.state.value.duration, const Duration(minutes: 1));
      expect(player.state.value.muted, isTrue);
      // Disposed of inside the test: the controller awaits futures of
      // the test's own clock while it goes.
      await player.dispose();
    });

    testWidgets('says when the player gives up', (tester) async {
      final player = MediaReaderVideoAudioPlayer();
      final errors = <Object>[];
      player.onError = errors.add;
      await player.open(path: '/audio/voice.ogg');

      platform.last.fail('decoder error');
      await tester.pump();

      expect(errors, ['decoder error']);
      await player.dispose();
    });

    testWidgets('throws when it cannot open the file', (tester) async {
      platform.openError = 'unsupported';
      final player = MediaReaderVideoAudioPlayer();

      await expectLater(
        player.open(path: '/audio/voice.xyz'),
        throwsA(anything),
      );
      await player.dispose();
    });
  });
}
