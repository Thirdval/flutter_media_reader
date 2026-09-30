import 'package:flutter/foundation.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const engine = MediaReaderPdfEngine();

  group('MediaReaderPdfEngine.canShow', () {
    test('shows a PDF on every platform of the package', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(engine.canShow(item('Rota.pdf'), platform), isTrue);
      }
    });

    test('knows a PDF by its type, whatever its name', () {
      expect(
        engine.canShow(
          item('download', contentType: 'application/pdf'),
          TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('shows a PDF from any source', () {
      for (final source in [
        MediaReaderSource.remote(FakeResolve().call),
        const MediaReaderSource.file('/files/rota.pdf'),
        MediaReaderSource.bytes(Uint8List(4)),
      ]) {
        expect(
          engine.canShow(item('Rota.pdf', source: source), TargetPlatform.iOS),
          isTrue,
        );
      }
    });

    test('leaves the other kinds alone', () {
      for (final name in ['a.jpg', 'a.mp4', 'a.m4a', 'a.docx', 'a.txt']) {
        expect(engine.canShow(item(name), TargetPlatform.iOS), isFalse);
      }
    });

    test('is in the standard registry', () {
      final showing = MediaReaderEngines.standard.select(
        item('Rota.pdf'),
        TargetPlatform.android,
      );

      expect(showing.engine.id, 'pdf');
    });
  });
}
