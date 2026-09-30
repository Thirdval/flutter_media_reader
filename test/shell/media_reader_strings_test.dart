import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const strings = MediaReaderStrings();

  group('MediaReaderStrings', () {
    test('a size reads in the largest unit that fits', () {
      expect(strings.size(0), '0 B');
      expect(strings.size(512), '512 B');
      expect(strings.size(1024), '1 KB');
      expect(strings.size(1536), '1.5 KB');
      expect(strings.size(5 * 1024 * 1024), '5 MB');
      expect(strings.size(2562048), '2.4 MB');
      expect(strings.size(129394278), '123 MB');
      expect(strings.size(3 * 1024 * 1024 * 1024), '3 GB');
    });

    test('every kind has a name', () {
      expect({
        for (final kind in MediaKind.values) strings.kind(kind),
      }, hasLength(MediaKind.values.length));
      expect(strings.kind(MediaKind.pdf), 'PDF');
      expect(strings.kind(MediaKind.other), 'File');
    });

    test('a page says its name, and its place when there are several', () {
      expect(strings.page('Rota.pdf', 2, 5), 'Rota.pdf, 2 of 5');
      expect(strings.page('Rota.pdf', 1, 1), 'Rota.pdf');
    });

    test('a page of a document is called by its number', () {
      expect(strings.pageNumber(3), 'Page 3');
    });

    test('a host passes its own words', () {
      final french = MediaReaderStrings(
        close: 'Fermer',
        position: (position, count) => '$position sur $count',
      );

      expect(french.close, 'Fermer');
      expect(french.position(2, 5), '2 sur 5');
      expect(french.notShown, strings.notShown);
    });
  });
}
