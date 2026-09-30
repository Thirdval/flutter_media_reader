/// The lines of a text file (MEDIA_READER_PLAN.md R6), found as its bytes
/// come and decoded only when they are shown: a log of 20 MB is a buffer
/// and a list of where its lines start, not a list of strings.
library;

import 'dart:convert';
import 'dart:typed_data';

/// How a text's bytes are read.
enum MediaReaderTextEncoding() {
  utf8,
  utf16le,
  utf16be,

  /// Windows-1252, the superset of Latin-1 that most files which are not
  /// Unicode are written in.
  latin1,
}

/// Finds the lines in [bytes] as they are filled in.
final class MediaReaderTextLines(
  /// The buffer the file is loaded into.
  final Uint8List bytes, {

  /// A line longer than this is shown as several: one line of megabytes
  /// would be one widget of megabytes.
  final int maxLineBytes = 8 * 1024,

  /// Whether a line ending between quotes is part of the line, as in a
  /// CSV file: a row is then one line however it is written. Such a line
  /// is never cut.
  final bool quoted = false,
}) {
  /// What Windows-1252 has where Latin-1 has control characters.
  static const _windows1252 = [
    0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, //
    0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x017D, 0x8F, 0x90, 0x2018, //
    0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, //
    0x0161, 0x203A, 0x0153, 0x9D, 0x017E, 0x0178,
  ];

  // Where each line starts, and how long it is as it is shown.
  Uint32List _starts = Uint32List(1024);
  Uint32List _widths = Uint32List(1024);
  int _count = 0;
  int _scanned = 0;
  int _lineStart = 0;
  int _longest = 0;

  // The line being read: its length as shown, and whether it has
  // characters that may be twice as wide as a letter.
  int _units = 0;
  bool _wide = false;
  bool _started = false;
  bool _done = false;

  // How many bytes of a UTF-8 sequence are still to come.
  int _pending = 0;
  bool _inQuotes = false;
  MediaReaderTextEncoding _encoding = MediaReaderTextEncoding.utf8;

  /// How the bytes are read: by their byte-order mark, else as UTF-8
  /// while they are valid UTF-8, else as Windows-1252.
  MediaReaderTextEncoding get encoding => _encoding;

  /// How many lines are known so far.
  int get count => _count;

  /// The longest line so far, in columns: see [columnsOf].
  int get longest => _longest;

  /// How long line [index] is as it is shown, in UTF-16 units, a tab
  /// counted as four.
  int unitsOf(int index) => _widths[index] & 0x7FFFFFFF;

  /// Whether line [index] has characters that may be twice as wide as a
  /// letter: those of East Asia, and emoji. Such a line is given two
  /// columns for each of its characters.
  bool wideOf(int index) => _widths[index] & 0x80000000 != 0;

  /// The columns line [index] takes at most, in a face of equal widths.
  int columnsOf(int index) => unitsOf(index) * (wideOf(index) ? 2 : 1);

  int get _unit => switch (_encoding) {
    MediaReaderTextEncoding.utf16le || MediaReaderTextEncoding.utf16be => 2,
    _ => 1,
  };

  /// Takes in the bytes up to [filled]. When [done], the file has no
  /// more: what follows the last line ending is a line too.
  void extend(int filled, {required bool done}) {
    if (_done) return;
    if (!_started && (filled >= 3 || done)) _start(filled);
    if (_started) _scan(filled);
    if (done) _finish(filled);
  }

  /// Line [index], without its ending.
  String line(int index) {
    final start = _starts[index];
    // The next line's start; for the last line so far, where the line
    // still being read starts.
    final end = index + 1 < _count ? _starts[index + 1] : _lineStart;
    return _decode(start, _trimmed(start, end));
  }

  /// All of the text read so far, line endings as they are.
  String get text => _decode(_first, _lineStart);

  // Where the text starts, after a byte-order mark.
  int _first = 0;

  /// Reads the byte-order mark, which says how the rest is written.
  void _start(int filled) {
    _started = true;
    final b = bytes;
    if (filled >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      _first = 3;
    } else if (filled >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
      _encoding = MediaReaderTextEncoding.utf16le;
      _first = 2;
    } else if (filled >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
      _encoding = MediaReaderTextEncoding.utf16be;
      _first = 2;
    }
    _scanned = _lineStart = _first;
  }

  void _scan(int filled) {
    final unit = _unit;
    final b = bytes;
    final le = _encoding != MediaReaderTextEncoding.utf16be;
    var at = _scanned;
    // A unit cut by the end of what is filled waits for the rest.
    final end = filled - (filled - at) % unit;
    while (at < end) {
      final code = unit == 1
          ? b[at]
          : le
          ? b[at] | b[at + 1] << 8
          : b[at] << 8 | b[at + 1];
      at += unit;
      _measure(code, unit);
      if (unit == 1 && _encoding == MediaReaderTextEncoding.utf8) {
        _validate(code, at);
      }
      if (quoted && code == 0x22) {
        _inQuotes = !_inQuotes;
      } else if (_inQuotes) {
        continue;
      }
      if (code == 0x0A) {
        _close(at);
      } else if (code == 0x0D) {
        // A carriage return alone ends a line; before a line feed the
        // two are one ending, closed at the line feed.
        final next = at + unit <= filled
            ? (unit == 1
                  ? b[at]
                  : le
                  ? b[at] | b[at + 1] << 8
                  : b[at] << 8 | b[at + 1])
            : -1;
        if (next == -1 && !_done) {
          // Not known yet: look again when more has come.
          at -= unit;
          _units -= 1;
          break;
        }
        if (next != 0x0A) _close(at);
      } else if (!quoted && at - _lineStart >= maxLineBytes && _boundary(at)) {
        _close(at);
      }
    }
    _scanned = at;
  }

  /// Whether a line may be cut before [at]: not inside a character.
  bool _boundary(int at) => switch (_encoding) {
    MediaReaderTextEncoding.utf8 =>
      _pending == 0 && (at >= bytes.length || bytes[at] & 0xC0 != 0x80),
    _ => true,
  };

  /// Follows UTF-8's rules byte by byte. A byte that breaks them says
  /// the file is not UTF-8.
  void _validate(int byte, int next) {
    if (_pending > 0) {
      if (byte & 0xC0 == 0x80) {
        _pending -= 1;
      } else {
        _notUtf8(next);
      }
    } else if (byte >= 0x80) {
      if (byte & 0xE0 == 0xC0 && byte >= 0xC2) {
        _pending = 1;
      } else if (byte & 0xF0 == 0xE0) {
        _pending = 2;
      } else if (byte & 0xF8 == 0xF0 && byte <= 0xF4) {
        _pending = 3;
      } else {
        _notUtf8(next);
      }
    }
  }

  /// The file is Windows-1252 after all: each of its bytes is a
  /// character, in the lines already read as well. The bytes before
  /// [next] are read.
  void _notUtf8(int next) {
    _encoding = MediaReaderTextEncoding.latin1;
    for (var i = 0; i < _count; i++) {
      final start = _starts[i];
      final end = i + 1 < _count ? _starts[i + 1] : _lineStart;
      _widths[i] = _trimmed(start, end) - start;
    }
    _units = next - _lineStart;
    _wide = false;
  }

  /// Adds one unit of the file to the length of the line being read.
  void _measure(int code, int unit) {
    if (code == 0x09) {
      _units += 4;
    } else if (unit == 2) {
      _units += 1;
      // From the Hangul letters on: not all are wide, none is lost.
      if (code >= 0x1100) _wide = true;
    } else if (code < 0x80 || _encoding != MediaReaderTextEncoding.utf8) {
      _units += 1;
    } else if (code & 0xC0 != 0x80) {
      // The first byte of a character: of two units when it has four
      // bytes, and maybe wide when it has three or four.
      _units += code >= 0xF0 ? 2 : 1;
      if (code >= 0xE1) _wide = true;
    }
  }

  /// The line that began at [_lineStart] ends before [next].
  void _close(int next) {
    if (_count == _starts.length) {
      _starts = Uint32List(_count * 2)..setAll(0, _starts);
      _widths = Uint32List(_count * 2)..setAll(0, _widths);
    }
    // Its ending is not shown.
    final ending = (next - _trimmed(_lineStart, next)) ~/ _unit;
    final units = _units - ending < 0 ? 0 : _units - ending;
    _starts[_count] = _lineStart;
    _widths[_count] = units | (_wide ? 0x80000000 : 0);
    _count++;
    final columns = units * (_wide ? 2 : 1);
    if (columns > _longest) _longest = columns;
    _lineStart = next;
    _units = 0;
    _wide = false;
  }

  void _finish(int filled) {
    _done = true;
    if (!_started) _start(filled);
    _scan(filled);
    if (_pending > 0) _notUtf8(filled);
    // What follows the last ending is a line, unless the file ends with
    // an ending; an empty file has one empty line.
    if (_lineStart < filled || _count == 0) _close(filled);
  }

  /// [end] without the line ending before it.
  int _trimmed(int start, int end) {
    final unit = _unit;
    var trimmed = end;
    for (var i = 0; i < 2 && trimmed - unit >= start; i++) {
      final code = unit == 1
          ? bytes[trimmed - 1]
          : _encoding == MediaReaderTextEncoding.utf16le
          ? bytes[trimmed - 2] | bytes[trimmed - 1] << 8
          : bytes[trimmed - 2] << 8 | bytes[trimmed - 1];
      // "\r\n", "\n" or "\r": at most one of each, in that order.
      if (code != (i == 0 ? 0x0A : 0x0D) && !(i == 0 && code == 0x0D)) break;
      trimmed -= unit;
      if (code == 0x0D) break;
    }
    return trimmed;
  }

  String _decode(int start, int end) {
    if (end <= start) return '';
    final part = Uint8List.sublistView(bytes, start, end);
    switch (_encoding) {
      case MediaReaderTextEncoding.utf8:
        return utf8.decode(part, allowMalformed: true);
      case MediaReaderTextEncoding.latin1:
        return String.fromCharCodes([
          for (final byte in part)
            byte >= 0x80 && byte < 0xA0 ? _windows1252[byte - 0x80] : byte,
        ]);
      case MediaReaderTextEncoding.utf16le || MediaReaderTextEncoding.utf16be:
        final le = _encoding == MediaReaderTextEncoding.utf16le;
        return String.fromCharCodes([
          for (var i = 0; i + 1 < part.length; i += 2)
            le ? part[i] | part[i + 1] << 8 : part[i] << 8 | part[i + 1],
        ]);
    }
  }
}
