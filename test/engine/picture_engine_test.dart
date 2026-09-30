import 'package:flutter/foundation.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const engine = MediaReaderPictureEngine();

  group('MediaReaderPictureEngine.canShow', () {
    test('the formats Flutter decodes are shown on every platform', () {
      for (final name in [
        'a.jpg',
        'a.jpeg',
        'a.png',
        'a.gif',
        'a.webp',
        'a.bmp',
        'a.ico',
      ]) {
        for (final platform in TargetPlatform.values) {
          expect(engine.canShow(item(name), platform), isTrue, reason: name);
        }
      }
    });

    test('HEIC and TIFF are shown where the system decodes them', () {
      for (final name in ['IMG_0042.heic', 'IMG_0042.heif', 'scan.tiff']) {
        expect(engine.canShow(item(name), TargetPlatform.iOS), isTrue);
        expect(engine.canShow(item(name), TargetPlatform.macOS), isTrue);
        expect(engine.canShow(item(name), TargetPlatform.android), isFalse);
        expect(engine.canShow(item(name), TargetPlatform.windows), isFalse);
        expect(engine.canShow(item(name), TargetPlatform.linux), isFalse);
      }
    });

    test('SVG, AVIF and unknown pictures are left to the card', () {
      for (final picture in [
        item('logo.svg'),
        item('photo.avif'),
        item('scan', contentType: 'image/x-new-format'),
      ]) {
        expect(picture.kind, MediaKind.picture);
        for (final platform in TargetPlatform.values) {
          expect(engine.canShow(picture, platform), isFalse);
        }
      }
    });

    test('the content type decides over a misleading name', () {
      expect(
        engine.canShow(
          item('IMG_0042.heic', contentType: 'image/jpeg'),
          TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('other kinds are not pictures', () {
      for (final name in ['a.mp4', 'a.pdf', 'a.txt', 'a.zip']) {
        expect(engine.canShow(item(name), TargetPlatform.android), isFalse);
      }
    });
  });

  group('the standard registry', () {
    test('shows a picture with the picture engine', () {
      final showing = MediaReaderEngines.standard.select(
        item('a.jpg'),
        TargetPlatform.android,
      );

      expect(showing.engine.id, 'picture');
    });

    test('shows a HEIC through its JPEG preview where it must', () {
      final heic = item(
        'IMG_0042.heic',
        preview: MediaReaderPreview(
          source: MediaReaderSource.bytes(Uint8List(1)),
          contentType: 'image/jpeg',
        ),
      );

      final onPhone = MediaReaderEngines.standard.select(
        heic,
        TargetPlatform.android,
      );
      final onMac = MediaReaderEngines.standard.select(
        heic,
        TargetPlatform.macOS,
      );

      expect(onPhone.engine.id, 'picture');
      expect(onPhone.item.format, 'jpeg');
      expect(onMac.item, same(heic));
    });
  });
}
