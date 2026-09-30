/// A CSV or TSV file as rows and cells (MEDIA_READER_PLAN.md R6): the
/// rows found as the bytes come, each parsed into its cells when it is
/// shown.
library;

import 'dart:math' as math;

import '../text/text_lines.dart';

/// The delimiters a table may be written with, the likeliest first.
const List<String> tableDelimiters = [',', ';', '\t', '|'];

/// The delimiter [rows] are written with: the one that cuts the first
/// rows into the same number of cells. A comma when none does.
String detectTableDelimiter(Iterable<String> rows) {
  var best = ',';
  var bestScore = 0;
  for (final delimiter in tableDelimiters) {
    int? first;
    var agreeing = 0;
    for (final row in rows) {
      final count = _countOutsideQuotes(row, delimiter);
      first ??= count;
      if (count == first && count > 0) agreeing++;
    }
    if (agreeing > bestScore) {
      best = delimiter;
      bestScore = agreeing;
    }
  }
  return best;
}

int _countOutsideQuotes(String row, String delimiter) {
  var count = 0;
  var quoted = false;
  for (var i = 0; i < row.length; i++) {
    final char = row[i];
    if (char == '"') {
      quoted = !quoted;
    } else if (!quoted && char == delimiter) {
      count++;
    }
  }
  return count;
}

/// The cells of [row], written with [delimiter]: a cell in quotes may
/// hold the delimiter, a line break, and a quote written twice.
List<String> parseTableRow(String row, String delimiter) {
  final cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < row.length; i++) {
    final char = row[i];
    if (quoted) {
      if (char != '"') {
        cell.write(char);
      } else if (i + 1 < row.length && row[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == delimiter) {
      cells.add(cell.toString());
      cell.clear();
    } else {
      cell.write(char);
    }
  }
  cells.add(cell.toString());
  return cells;
}

/// The rows of a table, over the lines of its file.
final class MediaReaderTableData(final MediaReaderTextLines lines) {
  /// How many rows are looked at to find the delimiter and the columns'
  /// widths.
  static const _sample = 200;

  /// How many characters a column is at most as wide as.
  static const maxColumnChars = 40;

  String? _delimiter;
  int? _columns;
  List<int>? _widths;

  // The rows last parsed, by their number.
  final Map<int, List<String>> _parsed = {};

  /// How many rows are known so far.
  int get rowCount => lines.count;

  /// The delimiter the file is written with, from its first rows, or
  /// the one the name says ([named]).
  String delimiter({String? named}) =>
      _delimiter ??= named ?? detectTableDelimiter(_first);

  Iterable<String> get _first sync* {
    for (var i = 0; i < math.min(_sample, lines.count); i++) {
      yield lines.line(i);
    }
  }

  /// How many columns the table has: as many as its first rows have at
  /// most.
  int get columnCount => _columns ??= _first.fold<int>(
    1,
    (most, row) => math.max(most, parseTableRow(row, delimiter()).length),
  );

  /// How many characters each column needs, from the first rows, up to
  /// [maxColumnChars].
  List<int> get columnChars {
    if (_widths case final widths?) return widths;
    final widths = List<int>.filled(columnCount, 4);
    for (final row in _first) {
      for (final (column, cell) in parseTableRow(row, delimiter()).indexed) {
        if (column >= widths.length) break;
        widths[column] = math.min(
          maxColumnChars,
          math.max(widths[column], cell.length),
        );
      }
    }
    return _widths = widths;
  }

  /// The cells of row [index]; empty cells where the row is short.
  List<String> row(int index) {
    final parsed = _parsed[index];
    if (parsed != null) return parsed;
    if (_parsed.length > 400) _parsed.clear();
    final cells = parseTableRow(lines.line(index), delimiter());
    final padded = cells.length >= columnCount
        ? cells
        : [...cells, for (var i = cells.length; i < columnCount; i++) ''];
    return _parsed[index] = padded;
  }

  /// A row as one line of text, for the search.
  String rowText(int index) => row(index).join('\t');

  /// The rows are more than they were: what was worked out from the
  /// first is kept, the rest is parsed again.
  void invalidateRows() => _parsed.clear();
}
