import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaKind.of', () {
    test('a specific content type decides', () {
      expect(MediaKind.of(contentType: 'image/png'), MediaKind.picture);
      expect(MediaKind.of(contentType: 'video/quicktime'), MediaKind.video);
      expect(
        MediaKind.of(contentType: 'audio/ogg; codecs=opus'),
        MediaKind.audio,
      );
      expect(MediaKind.of(contentType: 'application/pdf'), MediaKind.pdf);
      expect(
        MediaKind.of(
          contentType:
              'application/vnd.openxmlformats-officedocument'
              '.wordprocessingml.document',
        ),
        MediaKind.office,
      );
      expect(
        MediaKind.of(contentType: 'application/vnd.oasis.opendocument.text'),
        MediaKind.office,
      );
      expect(MediaKind.of(contentType: 'text/markdown'), MediaKind.markdown);
      expect(MediaKind.of(contentType: 'text/csv'), MediaKind.table);
      expect(MediaKind.of(contentType: 'application/json'), MediaKind.text);
      expect(MediaKind.of(contentType: 'application/zip'), MediaKind.archive);
      expect(
        MediaKind.of(contentType: 'video/mp2t', fileName: 'clip.ts'),
        MediaKind.video,
      );
    });

    test('a specific content type wins over a misleading name', () {
      expect(
        MediaKind.of(contentType: 'application/pdf', fileName: 'scan.jpg'),
        MediaKind.pdf,
      );
    });

    test('a generic or missing content type defers to the extension', () {
      expect(
        MediaKind.of(
          contentType: 'application/octet-stream',
          fileName: 'Budget 2026.XLSX',
        ),
        MediaKind.office,
      );
      expect(MediaKind.of(fileName: 'notes.md'), MediaKind.markdown);
      expect(MediaKind.of(fileName: 'rows.tsv'), MediaKind.table);
      expect(MediaKind.of(fileName: 'main.ts'), MediaKind.text);
      expect(MediaKind.of(fileName: 'photos.tar.gz'), MediaKind.archive);
      expect(MediaKind.of(fileName: 'IMG_0042.HEIC'), MediaKind.picture);
    });

    test('an MPEG-4 container type defers to an audio-only extension', () {
      expect(
        MediaKind.of(contentType: 'video/mp4', fileName: 'voice-1790.m4a'),
        MediaKind.audio,
      );
      expect(
        MediaKind.of(contentType: 'video/mp4', fileName: 'baptism.mp4'),
        MediaKind.video,
      );
    });

    test('an unknown type falls back to its family, then to other', () {
      expect(
        MediaKind.of(contentType: 'image/x-new-format'),
        MediaKind.picture,
      );
      expect(MediaKind.of(contentType: 'text/x-anything'), MediaKind.text);
      expect(MediaKind.of(contentType: 'application/x-thing'), MediaKind.other);
      expect(MediaKind.of(fileName: 'README'), MediaKind.other);
      expect(MediaKind.of(fileName: 'trailing.'), MediaKind.other);
      expect(MediaKind.of(), MediaKind.other);
    });
  });
}
