/// A search through a text's lines (MEDIA_READER_PLAN.md R6): a few
/// thousand lines at a time, so a long file is searched without holding
/// up its scrolling.
library;

import 'dart:async';

/// Looks for a query in lines that are read through [lineAt].
final class MediaReaderTextSearch({
  required final int Function() _lineCount,
  required final String Function(int index) _lineAt,

  /// Told whenever the matches, or the one gone to, change.
  required final void Function() _onChanged,
}) {
  /// How many lines are searched between two frames.
  static const _chunk = 2000;

  /// No more matches than this are counted: a letter searched for in a
  /// long file is on every line.
  static const maxMatches = 10000;

  // The line of each match, in order: a line is there once for each
  // place the query is found in it.
  final List<int> _lines = [];
  int _run = 0;

  /// What is searched for; empty while nothing is.
  String query = '';

  /// The query as it is looked for: any case.
  RegExp? pattern;

  /// The match gone to, from 0; -1 while there is none.
  int current = -1;

  /// Whether lines are still being gone through.
  bool searching = false;

  int get count => _lines.length;

  /// The line of the match gone to, and which of that line's matches it
  /// is, from 0.
  ({int line, int place})? get at {
    if (current < 0) return null;
    final line = _lines[current];
    var place = 0;
    while (current - place > 0 && _lines[current - place - 1] == line) {
      place++;
    }
    return (line: line, place: place);
  }

  /// Searches for [text]; an empty one ends the search.
  Future<void> start(String text) async {
    final run = ++_run;
    query = text;
    _lines.clear();
    current = -1;
    pattern = text.isEmpty
        ? null
        : RegExp(RegExp.escape(text), caseSensitive: false);
    searching = text.isNotEmpty;
    _onChanged();
    final pattern_ = pattern;
    if (pattern_ == null) return;
    for (var line = 0; line < _lineCount(); line++) {
      if (line > 0 && line % _chunk == 0) {
        _onChanged();
        await Future<void>.delayed(Duration.zero);
        // Another search has begun, or this one was ended.
        if (run != _run) return;
      }
      final found = pattern_.allMatches(_lineAt(line)).length;
      for (var i = 0; i < found && _lines.length < maxMatches; i++) {
        _lines.add(line);
      }
      if (current < 0 && _lines.isNotEmpty) current = 0;
      if (_lines.length >= maxMatches) break;
    }
    searching = false;
    _onChanged();
  }

  /// Goes [by] matches on, round to the other end.
  void step(int by) {
    if (_lines.isEmpty) return;
    current = (current + by) % _lines.length;
    _onChanged();
  }

  /// Ends whatever search is under way.
  void dispose() => _run++;
}
