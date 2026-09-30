import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_media_reader/src/engine/text/text_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The lines of [bytes], taken in all at once.
  MediaReaderTextLines linesOf(List<int> bytes, {int maxLineBytes = 8192}) {
    final buffer = Uint8List.fromList(bytes);
    return MediaReaderTextLines(buffer, maxLineBytes: maxLineBytes)
      ..extend(buffer.length, done: true);
  }

  List<String> all(MediaReaderTextLines lines) => [
    for (var i = 0; i < lines.count; i++) lines.line(i),
  ];

  List<int> utf16(String text, {required bool le}) => [
    ...(le ? [0xFF, 0xFE] : [0xFE, 0xFF]),
    for (final unit in text.codeUnits)
      ...(le ? [unit & 0xFF, unit >> 8] : [unit >> 8, unit & 0xFF]),
  ];

  group('MediaReaderTextLines', () {
    test('finds the lines, whatever ends them', () {
      expect(all(linesOf(utf8.encode('one\ntwo\r\nthree\rfour'))), [
        'one',
        'two',
        'three',
        'four',
      ]);
    });

    test('an ending at the end of the file ends the last line, and starts '
        'no other', () {
      expect(all(linesOf(utf8.encode('one\ntwo\n'))), ['one', 'two']);
      expect(all(linesOf(utf8.encode('one\r\n'))), ['one']);
      expect(all(linesOf(utf8.encode('one\r'))), ['one']);
    });

    test('keeps empty lines', () {
      expect(all(linesOf(utf8.encode('one\n\n\nfour'))), [
        'one',
        '',
        '',
        'four',
      ]);
    });

    test('an empty file is one empty line', () {
      expect(all(linesOf(const [])), ['']);
    });

    test('reads UTF-8, with or without its mark', () {
      const text = 'Grüße, 世界 — “peace” 🕊';
      final marked = linesOf([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);

      expect(all(linesOf(utf8.encode(text))), [text]);
      expect(all(marked), [text]);
      expect(marked.encoding, MediaReaderTextEncoding.utf8);
    });

    for (final le in [true, false]) {
      test('reads UTF-16 by its mark, ${le ? 'little' : 'big'} end first', () {
        final lines = linesOf(utf16('Grüße\r\n世界 🕊\nend', le: le));

        expect(all(lines), ['Grüße', '世界 🕊', 'end']);
        expect(
          lines.encoding,
          le
              ? MediaReaderTextEncoding.utf16le
              : MediaReaderTextEncoding.utf16be,
        );
      });
    }

    test('reads what is not UTF-8 as Windows-1252', () {
      // "café – 5 €" as a Windows editor of the nineties wrote it.
      final lines = linesOf([
        ...ascii.encode('caf'), 0xE9, 0x20, 0x96, 0x20, 0x35, 0x20, 0x80, //
        0x0A, ...ascii.encode('plain'),
      ]);

      expect(lines.encoding, MediaReaderTextEncoding.latin1);
      expect(all(lines), ['café – 5 €', 'plain']);
    });

    test('a file that ends inside a character is not UTF-8', () {
      final lines = linesOf([...ascii.encode('ab'), 0xE4]);

      expect(lines.encoding, MediaReaderTextEncoding.latin1);
      expect(all(lines), ['abä']);
    });

    test('gives the whole text, its endings as they are', () {
      expect(linesOf(utf8.encode('one\r\ntwo\n')).text, 'one\r\ntwo\n');
      expect(linesOf([0xEF, 0xBB, 0xBF, ...utf8.encode('one')]).text, 'one');
    });

    test('knows how long each line is as it is shown', () {
      final lines = linesOf(utf8.encode('one\r\n\tthree\nxy é 🕊\n世界'));

      expect(
        [for (var i = 0; i < lines.count; i++) lines.unitsOf(i)],
        // A tab is four columns; the dove is two units.
        [3, 9, 7, 2],
      );
      for (var i = 0; i < lines.count; i++) {
        expect(
          lines.unitsOf(i),
          lines.line(i).replaceAll('\t', '    ').length,
          reason: 'line $i',
        );
      }
      expect(
        [for (var i = 0; i < lines.count; i++) lines.wideOf(i)],
        [false, false, true, true],
      );
      // The widest: the dove's line, at two columns a character.
      expect(lines.longest, 14);
    });

    test('knows it for UTF-16 and for Windows-1252 too', () {
      final sixteen = linesOf(utf16('a\tb\n世界', le: true));
      expect([sixteen.unitsOf(0), sixteen.unitsOf(1)], [6, 2]);
      expect([sixteen.wideOf(0), sixteen.wideOf(1)], [false, true]);

      // "é" written in UTF-8 on the first line, then a byte that is not.
      final mixed = linesOf([0xC3, 0xA9, 0x0A, 0x61, 0xE9, 0x62, 0x0A]);
      expect(mixed.encoding, MediaReaderTextEncoding.latin1);
      expect([mixed.unitsOf(0), mixed.unitsOf(1)], [2, 3]);
      expect(mixed.line(0), 'Ã©');
    });

    test('shows a line without end as several', () {
      final lines = linesOf(utf8.encode('a' * 25), maxLineBytes: 10);

      expect(all(lines), ['a' * 10, 'a' * 10, 'a' * 5]);
    });

    test('never cuts a long line inside a character', () {
      // Each "é" is two bytes: a cut at ten bytes would fall inside one.
      final lines = linesOf(utf8.encode('aé' * 9), maxLineBytes: 10);

      expect(all(lines).join(), 'aé' * 9);
      expect(lines.encoding, MediaReaderTextEncoding.utf8);
    });
  });

  group('as the bytes come', () {
    final texts = {
      'UTF-8': utf8.encode('one\r\ntwo — 世界\n\nfour\rfive 🕊\r\n'),
      'UTF-8 with its mark': [0xEF, 0xBB, 0xBF, ...utf8.encode('é\r\nb\n')],
      'UTF-16': utf16('one\r\ntwo 世界\n\rend', le: true),
      'Windows-1252': [0x63, 0xE9, 0x0D, 0x0A, 0x80, 0x0A, 0x61],
    };

    for (final MapEntry(key: name, value: bytes) in texts.entries) {
      test('the lines of $name are the same however the file is cut', () {
        final whole = linesOf(bytes);
        for (var cut = 0; cut <= bytes.length; cut++) {
          for (var second = cut; second <= bytes.length; second += 3) {
            final buffer = Uint8List.fromList(bytes);
            final lines = MediaReaderTextLines(buffer)
              ..extend(cut, done: false)
              ..extend(second, done: false)
              ..extend(buffer.length, done: true);

            expect(all(lines), all(whole), reason: 'cut at $cut and $second');
            expect(lines.encoding, whole.encoding);
            expect(
              [for (var i = 0; i < lines.count; i++) lines.columnsOf(i)],
              [for (var i = 0; i < whole.count; i++) whole.columnsOf(i)],
              reason: 'cut at $cut and $second',
            );
          }
        }
      });
    }

    test('the lines read so far can be shown', () {
      final bytes = Uint8List.fromList(utf8.encode('one\ntwo\nthr'));
      final lines = MediaReaderTextLines(bytes)..extend(9, done: false);

      expect(all(lines), ['one', 'two']);

      lines.extend(bytes.length, done: true);
      expect(all(lines), ['one', 'two', 'thr']);
    });

    test('indexes a hundred thousand lines', () {
      final bytes = Uint8List.fromList(
        utf8.encode([for (var i = 0; i < 100000; i++) 'line $i'].join('\n')),
      );
      final lines = MediaReaderTextLines(bytes)
        ..extend(bytes.length, done: true);

      expect(lines.count, 100000);
      expect(lines.line(0), 'line 0');
      expect(lines.line(99999), 'line 99999');
      expect(lines.line(54321), 'line 54321');
    });
  });
}
