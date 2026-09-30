import 'dart:typed_data';

import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String formatOf(String name, [String? contentType]) => MediaReaderItem(
    id: name,
    name: name,
    contentType: contentType,
    source: MediaReaderSource.bytes(Uint8List(0)),
  ).format;

  group('MediaReaderItem.format', () {
    test('a specific content type says the format', () {
      expect(formatOf('scan', 'image/jpeg'), 'jpeg');
      expect(formatOf('scan.bin', 'image/heif'), 'heic');
      expect(formatOf('clip', 'video/quicktime'), 'mov');
      expect(formatOf('clip', 'application/vnd.apple.mpegurl'), 'm3u8');
      expect(formatOf('note', 'audio/ogg; codecs=opus'), 'ogg');
      expect(formatOf('Rota', 'application/pdf'), 'pdf');
    });

    test('a generic or missing content type defers to the extension', () {
      expect(formatOf('IMG_0042.HEIC'), 'heic');
      expect(formatOf('photo.JPG', 'application/octet-stream'), 'jpeg');
      expect(formatOf('scan.tif'), 'tiff');
      expect(formatOf('voice.oga'), 'ogg');
      expect(formatOf('model.glb', 'model/gltf-binary'), 'glb');
    });

    test('an MPEG-4 container type defers to an audio-only extension', () {
      expect(formatOf('voice-1790.m4a', 'video/mp4'), 'm4a');
      expect(formatOf('baptism.mp4', 'video/mp4'), 'mp4');
    });

    test('a file that says nothing has no format', () {
      expect(formatOf('README'), '');
      expect(formatOf('trailing.'), '');
    });
  });
}
