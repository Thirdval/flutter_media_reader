import 'package:flutter/foundation.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const engine = MediaReaderVideoEngine();

  MediaReaderItem video(String name, {String? contentType}) => item(
    name,
    contentType: contentType,
    source: const MediaReaderSource.file('/videos/clip'),
  );

  group('MediaReaderVideoEngine.canShow', () {
    test('MP4, MOV and HLS play on every platform', () {
      for (final clip in [
        video('a.mp4'),
        video('a.m4v'),
        video('a.mov'),
        video('a.m3u8'),
        video('stream', contentType: 'application/vnd.apple.mpegurl'),
      ]) {
        for (final platform in [
          TargetPlatform.iOS,
          TargetPlatform.android,
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        ]) {
          expect(engine.canShow(clip, platform), isTrue, reason: clip.name);
        }
      }
    });

    test('WebM and Matroska play where the player plays them', () {
      for (final name in ['a.webm', 'a.mkv']) {
        expect(engine.canShow(video(name), TargetPlatform.android), isTrue);
        expect(engine.canShow(video(name), TargetPlatform.windows), isTrue);
        expect(engine.canShow(video(name), TargetPlatform.linux), isTrue);
        expect(engine.canShow(video(name), TargetPlatform.iOS), isFalse);
        expect(engine.canShow(video(name), TargetPlatform.macOS), isFalse);
      }
    });

    test('AVI and WMV play only through libmdk', () {
      for (final name in ['a.avi', 'a.wmv']) {
        expect(engine.canShow(video(name), TargetPlatform.windows), isTrue);
        expect(engine.canShow(video(name), TargetPlatform.linux), isTrue);
        expect(engine.canShow(video(name), TargetPlatform.android), isFalse);
        expect(engine.canShow(video(name), TargetPlatform.iOS), isFalse);
      }
    });

    test('a video in memory has no player', () {
      expect(engine.canShow(item('a.mp4'), TargetPlatform.android), isFalse);
    });

    test('other kinds are not videos', () {
      for (final name in ['a.jpg', 'a.m4a', 'a.pdf']) {
        expect(engine.canShow(video(name), TargetPlatform.android), isFalse);
      }
    });
  });

  group('the standard registry', () {
    test('plays a video with the video engine', () {
      expect(
        MediaReaderEngines.standard
            .select(video('a.mp4'), TargetPlatform.iOS)
            .engine
            .id,
        'video',
      );
    });

    test('plays a WebM through its MP4 preview where it must', () {
      final webm = item(
        'choir.webm',
        source: const MediaReaderSource.file('/videos/choir.webm'),
        preview: const MediaReaderPreview(
          source: MediaReaderSource.file('/videos/choir.mp4'),
          contentType: 'video/mp4',
        ),
      );

      final onPhone = MediaReaderEngines.standard.select(
        webm,
        TargetPlatform.iOS,
      );
      final onAndroid = MediaReaderEngines.standard.select(
        webm,
        TargetPlatform.android,
      );

      expect(onPhone.engine.id, 'video');
      expect(onPhone.item.format, 'mp4');
      expect(onAndroid.item, same(webm));
    });
  });

  group('MediaKind', () {
    test('an HLS playlist is a video', () {
      expect(MediaKind.of(fileName: 'master.m3u8'), MediaKind.video);
      expect(
        MediaKind.of(contentType: 'application/vnd.apple.mpegurl'),
        MediaKind.video,
      );
      expect(
        MediaKind.of(contentType: 'application/x-mpegURL'),
        MediaKind.video,
      );
    });
  });
}
