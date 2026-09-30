/// The rows a text's lines take in a face of equal widths
/// (MEDIA_READER_PLAN.md R6). A line longer than the width goes on in the
/// rows below it, cut at the column as a terminal cuts it. Every row is
/// as high as every other, so a text of a million rows scrolls, and
/// jumps to a place, as a short one does.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'text_lines.dart';

/// Which rows each line of [lines] takes, [columns] to a row.
final class MediaReaderTextRows(
  final MediaReaderTextLines lines, {

  /// How many letters fit the width; 0 when lines are not wrapped, and
  /// each is one row however long.
  required final int columns,
}) {
  // The first row of each line counted so far.
  Uint32List _first = Uint32List(1024);
  int _counted = 0;
  int _rows = 0;

  /// How many rows the lines read so far take.
  int get count {
    _extend();
    return _rows;
  }

  /// Takes in the lines that have come since the last count.
  void _extend() {
    while (_counted < lines.count) {
      if (_counted == _first.length) {
        _first = Uint32List(_counted * 2)..setAll(0, _first);
      }
      _first[_counted] = _rows;
      _rows += rowsOf(_counted);
      _counted++;
    }
  }

  /// How many units of a line's text one row shows: half as many for a
  /// line with characters that may be twice as wide.
  int _per(int line) => columns <= 0
      ? 0
      : lines.wideOf(line)
      ? math.max(1, columns ~/ 2)
      : columns;

  /// How many rows line [line] takes.
  int rowsOf(int line) {
    final per = _per(line);
    final units = lines.unitsOf(line);
    return per == 0 || units <= per ? 1 : (units + per - 1) ~/ per;
  }

  /// The first row of line [line].
  int firstRowOf(int line) {
    _extend();
    return _first[line];
  }

  /// The row of line [line] that shows the unit at [offset] of its text.
  int rowOf(int line, int offset) {
    final per = _per(line);
    final part = per == 0 ? 0 : math.min(offset ~/ per, rowsOf(line) - 1);
    return firstRowOf(line) + part;
  }

  /// The line row [index] is part of, and which of the line's rows it
  /// is, from 0.
  ({int line, int part}) at(int index) {
    _extend();
    var low = 0;
    var high = _counted - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_first[middle] <= index) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return (line: low, part: index - _first[low]);
  }

  /// What row [part] of line [line] shows of the line's [text], as it is
  /// displayed: from `start` up to `end`.
  ({int start, int end}) rangeOf(int line, int part, String text) {
    final per = _per(line);
    if (per == 0) return (start: 0, end: text.length);
    var start = math.min(part * per, text.length);
    // The line's last row takes what is left, should the text be longer
    // than it was measured.
    var end = part == rowsOf(line) - 1
        ? text.length
        : math.min(start + per, text.length);
    // Two units that are one character stay on one row.
    if (_splits(text, start)) start++;
    if (_splits(text, end)) end++;
    return (start: start, end: end);
  }

  /// Whether [offset] falls between the two units of one character.
  static bool _splits(String text, int offset) =>
      offset > 0 &&
      offset < text.length &&
      text.codeUnitAt(offset) & 0xFC00 == 0xDC00 &&
      text.codeUnitAt(offset - 1) & 0xFC00 == 0xD800;
}
