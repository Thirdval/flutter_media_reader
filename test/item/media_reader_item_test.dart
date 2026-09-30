import 'dart:typed_data';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = MediaReaderSource.bytes(Uint8List(0));

  group('MediaReaderItem', () {
    test('the kind is read from the content type and the name', () {
      expect(
        MediaReaderItem(id: '1', name: 'Rota.pdf', source: bytes).kind,
        MediaKind.pdf,
      );
      expect(
        MediaReaderItem(
          id: '2',
          name: 'voice-1790.m4a',
          contentType: 'video/mp4',
          source: bytes,
        ).kind,
        MediaKind.audio,
      );
    });

    test("the host's own reading of the kind wins", () {
      expect(
        MediaReaderItem(
          id: '1',
          name: 'scan.bin',
          contentType: 'application/octet-stream',
          kind: MediaKind.picture,
          source: bytes,
        ).kind,
        MediaKind.picture,
      );
    });
  });

  group('MediaReaderPreview', () {
    test('the kind is its own, not the file\'s', () {
      final docx = MediaReaderItem(
        id: '1',
        name: 'Minutes.docx',
        source: bytes,
        preview: MediaReaderPreview(
          source: bytes,
          contentType: 'application/pdf',
        ),
      );

      expect(docx.kind, MediaKind.office);
      expect(docx.preview!.kind, MediaKind.pdf);
    });

    test('the kind can come from its name or from the host', () {
      expect(
        MediaReaderPreview(source: bytes, name: 'IMG_0042.jpg').kind,
        MediaKind.picture,
      );
      expect(
        MediaReaderPreview(source: bytes, kind: MediaKind.pdf).kind,
        MediaKind.pdf,
      );
    });
  });

  group('MediaReaderPolicy', () {
    test('by default export is allowed and engines keep to memory', () {
      const policy = MediaReaderPolicy();

      expect(policy.canExport, isTrue);
      expect(policy.cache, isA<MediaReaderMemoryCache>());
    });

    test('a directory the host owns is used while export is allowed', () {
      const policy = MediaReaderPolicy(
        cache: MediaReaderCache.directory('/accounts/7/reader'),
      );

      expect(
        policy.cache,
        isA<MediaReaderDirectoryCache>().having(
          (cache) => cache.path,
          'path',
          '/accounts/7/reader',
        ),
      );
    });

    test('with export off nothing is kept on disk', () {
      const policy = MediaReaderPolicy(
        canExport: false,
        cache: MediaReaderCache.directory('/accounts/7/reader'),
      );

      expect(policy.cache, isA<MediaReaderMemoryCache>());
    });

    test('no cache stays no cache, export or not', () {
      expect(
        const MediaReaderPolicy(cache: MediaReaderCache.none()).cache,
        isA<MediaReaderNoCache>(),
      );
      expect(
        const MediaReaderPolicy(
          canExport: false,
          cache: MediaReaderCache.none(),
        ).cache,
        isA<MediaReaderNoCache>(),
      );
    });
  });
}
