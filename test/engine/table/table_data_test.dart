import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_media_reader/src/engine/table/table_data.dart';
import 'package:flutter_media_reader/src/engine/text/text_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MediaReaderTableData tableOf(String text) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    return MediaReaderTableData(
      MediaReaderTextLines(bytes, quoted: true)
        ..extend(bytes.length, done: true),
    );
  }

  group('detectTableDelimiter', () {
    test('finds the delimiter the rows agree on', () {
      expect(detectTableDelimiter(['a,b,c', '1,2,3', '4,5,6']), ',');
      expect(detectTableDelimiter(['a;b;c', '1;2;3']), ';');
      expect(detectTableDelimiter(['a\tb', '1\t2']), '\t');
      expect(detectTableDelimiter(['a|b', '1|2']), '|');
    });

    test('is not misled by a delimiter inside quotes', () {
      expect(
        detectTableDelimiter(['name;note', '"Ruth, Ann";"a, b, c"', 'x;y']),
        ';',
      );
    });

    test('is a comma when nothing says otherwise', () {
      expect(detectTableDelimiter(['just one cell', 'and another']), ',');
    });
  });

  group('parseTableRow', () {
    test('cuts a row at its delimiter', () {
      expect(parseTableRow('a,b,,d', ','), ['a', 'b', '', 'd']);
    });

    test('keeps what is in quotes together, and a quote written twice', () {
      expect(parseTableRow('"Ruth, Ann","She said ""hi""",plain', ','), [
        'Ruth, Ann',
        'She said "hi"',
        'plain',
      ]);
    });

    test('keeps a line break in quotes', () {
      expect(parseTableRow('"two\nlines",b', ','), ['two\nlines', 'b']);
    });
  });

  group('MediaReaderTableData', () {
    test('has as many columns as its widest first rows, and pads short '
        'ones', () {
      final table = tableOf('name,role\nRuth,Welcome,extra\nDaniel\n');

      expect(table.columnCount, 3);
      expect(table.row(2), ['Daniel', '', '']);
      expect(table.rowCount, 3);
    });

    test('a row broken inside quotes is one row', () {
      final table = tableOf('name,note\nRuth,"line one\nline two"\nDaniel,x\n');

      expect(table.rowCount, 3);
      expect(table.row(1), ['Ruth', 'line one\nline two']);
    });

    test('measures its columns from the first rows, up to a limit', () {
      final table = tableOf('a,b\n${'x' * 100},yy\n');

      expect(table.columnChars, [MediaReaderTableData.maxColumnChars, 4]);
    });

    test('takes the delimiter the name says over its own guess', () {
      final table = tableOf('a\tb,c\n1\t2,3\n');

      expect(table.delimiter(named: '\t'), '\t');
      expect(table.columnCount, 2);
    });
  });
}
