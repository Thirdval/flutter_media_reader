import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_media_reader/src/engine/text/text_lines.dart';
import 'package:flutter_media_reader/src/engine/text/text_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MediaReaderTextLines linesOf(String text) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    return MediaReaderTextLines(bytes)..extend(bytes.length, done: true);
  }

  /// Every row of [rows], as it is shown.
  List<String> shown(MediaReaderTextRows rows) => [
    for (var i = 0; i < rows.count; i++)
      () {
        final (:line, :part) = rows.at(i);
        final text = rows.lines.line(line);
        final range = rows.rangeOf(line, part, text);
        return text.substring(range.start, range.end);
      }(),
  ];

  group('MediaReaderTextRows', () {
    test('a line longer than the width goes on in the rows below', () {
      final rows = MediaReaderTextRows(
        linesOf('short\n${'a' * 25}\n\nend'),
        columns: 10,
      );

      expect(shown(rows), ['short', 'a' * 10, 'a' * 10, 'a' * 5, '', 'end']);
      expect(rows.rowsOf(1), 3);
      expect(rows.firstRowOf(3), 5);
    });

    test('a line as long as the width is one row', () {
      final rows = MediaReaderTextRows(linesOf('a' * 10), columns: 10);

      expect(shown(rows), ['a' * 10]);
    });

    test('lines that are not wrapped are one row each, however long', () {
      final rows = MediaReaderTextRows(linesOf('${'a' * 500}\nb'), columns: 0);

      expect(shown(rows), ['a' * 500, 'b']);
    });

    test('a line with wide characters gets half as many to a row', () {
      final rows = MediaReaderTextRows(linesOf('世' * 12), columns: 10);

      expect(shown(rows), ['世' * 5, '世' * 5, '世' * 2]);
    });

    test('a character of two units stays on one row', () {
      // Five units to a row: the third dove would be cut in two.
      final rows = MediaReaderTextRows(linesOf('🕊' * 6), columns: 10);

      expect(shown(rows).join(), '🕊' * 6);
      for (final row in shown(rows)) {
        expect(row.runes.every((rune) => rune == 0x1F54A), isTrue);
      }
    });

    test('finds the line of a row, and the row of a place in a line', () {
      final rows = MediaReaderTextRows(
        linesOf('one\n${'a' * 25}\nthree'),
        columns: 10,
      );

      expect(rows.at(0), (line: 0, part: 0));
      expect(rows.at(2), (line: 1, part: 1));
      expect(rows.at(3), (line: 1, part: 2));
      expect(rows.at(4), (line: 2, part: 0));
      expect(rows.rowOf(1, 0), 1);
      expect(rows.rowOf(1, 12), 2);
      expect(rows.rowOf(1, 24), 3);
      expect(rows.rowOf(2, 3), 4);
    });

    test('takes in the lines that come later', () {
      final bytes = Uint8List.fromList(utf8.encode('one\ntwo\nthree\n'));
      final lines = MediaReaderTextLines(bytes)..extend(4, done: false);
      final rows = MediaReaderTextRows(lines, columns: 10);
      expect(rows.count, 1);

      lines.extend(bytes.length, done: true);

      expect(rows.count, 3);
      expect(rows.at(2), (line: 2, part: 0));
    });

    test('counts the rows of a hundred thousand lines, and finds one', () {
      final rows = MediaReaderTextRows(
        linesOf([for (var i = 0; i < 100000; i++) 'x' * (i % 30)].join('\n')),
        columns: 10,
      );

      expect(rows.count, greaterThan(100000));
      final (:line, :part) = rows.at(rows.firstRowOf(77777) + 1);
      expect(line, 77777);
      expect(part, 1);
    });
  });
}
