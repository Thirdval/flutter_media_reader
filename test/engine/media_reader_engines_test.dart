import 'package:flutter/foundation.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const anywhere = TargetPlatform.android;

  group('MediaReaderEngines.select', () {
    test('the first engine that can show the file wins', () {
      final first = FakeEngine('first', kinds: {MediaKind.picture});
      final second = FakeEngine(
        'second',
        kinds: {MediaKind.picture, MediaKind.video},
      );
      final engines = MediaReaderEngines([first, second]);

      expect(engines.select(item('a.jpg'), anywhere).engine, first);
      expect(engines.select(item('b.mp4'), anywhere).engine, second);
    });

    test('an engine is chosen for the platform', () {
      final native = FakeEngine(
        'native',
        kinds: {MediaKind.video},
        platforms: {TargetPlatform.iOS, TargetPlatform.android},
      );
      final desktop = FakeEngine('desktop', kinds: {MediaKind.video});
      final engines = MediaReaderEngines([native, desktop]);

      expect(engines.select(item('a.mp4'), TargetPlatform.iOS).engine, native);
      expect(
        engines.select(item('a.mp4'), TargetPlatform.windows).engine,
        desktop,
      );
    });

    test('a file no engine shows falls back to its card', () {
      final engines = MediaReaderEngines([
        FakeEngine('pictures', kinds: {MediaKind.picture}),
      ]);
      final glb = item('model.glb', contentType: 'model/gltf-binary');

      final showing = engines.select(glb, anywhere);

      expect(showing.engine, MediaReaderEngines.card);
      expect(showing.engine.id, 'card');
      expect(showing.item, same(glb));
    });

    test('before R2 the standard registry shows every file as its card', () {
      for (final name in ['a.jpg', 'b.mp4', 'c.pdf', 'd.txt', 'e.zip']) {
        expect(
          MediaReaderEngines.standard.select(item(name), anywhere).engine,
          MediaReaderEngines.card,
        );
      }
    });

    test('a preview is shown by its own kind\'s engine', () {
      final pdf = FakeEngine('pdf', kinds: {MediaKind.pdf});
      final previewSource = MediaReaderSource.bytes(Uint8List(1));
      final docx = item(
        'Minutes.docx',
        id: 'file-7',
        data: 'the host\'s',
        preview: MediaReaderPreview(
          source: previewSource,
          contentType: 'application/pdf',
        ),
      );

      final showing = MediaReaderEngines([pdf]).select(docx, anywhere);

      expect(showing.engine, pdf);
      expect(showing.item.kind, MediaKind.pdf);
      expect(showing.item.source, same(previewSource));
      expect(showing.item.id, 'file-7');
      expect(showing.item.name, 'Minutes.docx');
      expect(showing.item.data, 'the host\'s');
    });

    test('the file itself is preferred to its preview', () {
      final pictures = FakeEngine(
        'pictures',
        kinds: {MediaKind.picture},
        platforms: {TargetPlatform.iOS},
      );
      final heic = item(
        'IMG_0042.heic',
        preview: MediaReaderPreview(
          source: MediaReaderSource.bytes(Uint8List(1)),
          name: 'IMG_0042.jpg',
        ),
      );
      final engines = MediaReaderEngines([pictures]);

      expect(engines.select(heic, TargetPlatform.iOS).item, same(heic));
    });

    test('a file with a preview no engine shows is its card', () {
      final docx = item(
        'Minutes.docx',
        preview: MediaReaderPreview(
          source: MediaReaderSource.bytes(Uint8List(1)),
          contentType: 'application/pdf',
        ),
      );

      final showing = MediaReaderEngines.standard.select(docx, anywhere);

      expect(showing.engine, MediaReaderEngines.card);
      expect(showing.item, same(docx));
    });
  });

  group('MediaReaderEngines.withFirst', () {
    test("a host's engines are asked before the registry's", () {
      final ours = FakeEngine('ours', kinds: {MediaKind.picture});
      final theirs = FakeEngine('theirs', kinds: {MediaKind.picture});

      final engines = MediaReaderEngines([ours]).withFirst([theirs]);

      expect(engines.select(item('a.jpg'), anywhere).engine, theirs);
    });

    test('a host can put its own engine in place of the card', () {
      final everything = FakeEngine(
        'host-card',
        kinds: MediaKind.values.toSet(),
      );

      final engines = MediaReaderEngines.standard.withFirst([everything]);

      expect(engines.select(item('model.glb'), anywhere).engine, everything);
    });
  });
}
