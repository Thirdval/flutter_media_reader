/// A text's lines as a list (MEDIA_READER_PLAN.md R6): only those on
/// screen are built, however long the text.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'text_line.dart';
import 'text_lines.dart';
import 'text_rows.dart';

/// How the lines are laid out, for the view to bring one on screen.
typedef MediaReaderTextLayout = ({
  /// The rows of the lines; null for prose, whose lines are as high as
  /// their words make them.
  MediaReaderTextRows? rows,
  double rowHeight,
});

/// The lines of a text.
///
/// Prose is set in the reader's own face, a line to a paragraph, wrapped
/// at its words. Everything else is set in a face of equal widths and
/// laid out in rows of one height: wrapped at the column, or not wrapped
/// and scrolled sideways.
class const MediaReaderTextList({
  required final MediaReaderTextLines lines,
  required final bool prose,
  required final bool wrap,
  required final TextStyle style,
  required final EdgeInsets padding,
  required final ScrollController down,
  required final ScrollController across,
  required final MediaReaderBuiltLines built,
  required final ValueChanged<MediaReaderTextLayout> onLayout,

  /// What the search looks for, and where the match gone to is.
  final RegExp? pattern,
  final ({int line, int place})? active,
  required final Color mark,

  /// Said under the last line: that the text was cut short.
  final String? foot,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderTextList> createState() => _MediaReaderTextListState();
}

class _MediaReaderTextListState() extends State<MediaReaderTextList> {
  MediaReaderTextRows? _rows;

  // The line last decoded: the rows of a long line are built one after
  // the other.
  int _decoded = -1;
  String _text = '';

  String _display(int line) {
    if (line != _decoded) {
      _decoded = line;
      _text = displayedLine(widget.lines.line(line));
    }
    return _text;
  }

  Widget _foot(String foot) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      foot,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style.copyWith(
        color: widget.style.color?.withValues(alpha: 0.7),
      ),
    ),
  );

  /// Line [line], or the part of it in [range]. The text's last line has
  /// no break after it.
  Widget _line(int line, {({int start, int end})? range, bool last = false}) =>
      MediaReaderTextLine(
        index: line,
        text: _display(line),
        range: range,
        style: widget.style,
        wrap: widget.prose,
        endsLine: !last && line < widget.lines.count - 1,
        pattern: widget.pattern,
        active: widget.active?.line == line ? widget.active?.place : null,
        mark: widget.mark,
        built: widget.prose ? widget.built : null,
      );

  @override
  Widget build(BuildContext context) {
    // A line that has just been extended is decoded afresh.
    _decoded = -1;
    final lines = widget.lines;
    final foot = widget.foot;
    final extra = foot == null ? 0 : 1;
    if (widget.prose) {
      widget.onLayout((rows: null, rowHeight: 0));
      return ListView.builder(
        controller: widget.down,
        padding: widget.padding,
        itemCount: lines.count + extra,
        itemBuilder: (context, index) =>
            index < lines.count ? _line(index) : _foot(foot!),
      );
    }
    final letter = TextPainter(
      text: TextSpan(text: 'M', style: widget.style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final (width, height) = (letter.width, letter.height);
    letter.dispose();
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - widget.padding.horizontal;
        final columns = widget.wrap ? math.max(8, (room / width).floor()) : 0;
        var rows = _rows;
        if (rows == null ||
            !identical(rows.lines, lines) ||
            rows.columns != columns) {
          rows = _rows = MediaReaderTextRows(lines, columns: columns);
        }
        final count = rows.count;
        widget.onLayout((rows: rows, rowHeight: height));
        final list = ListView.builder(
          controller: widget.down,
          padding: widget.padding,
          itemExtent: height,
          itemCount: count + extra,
          itemBuilder: (context, index) {
            if (index >= count) return _foot(foot!);
            final (:line, :part) = rows!.at(index);
            return _line(
              line,
              range: rows.rangeOf(line, part, _display(line)),
              last: part < rows.rowsOf(line) - 1,
            );
          },
        );
        if (widget.wrap) return list;
        // Not wrapped: as wide as the longest line, and scrolled
        // sideways.
        return SingleChildScrollView(
          controller: widget.across,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(
              constraints.maxWidth,
              lines.longest * width + widget.padding.horizontal,
            ),
            child: list,
          ),
        );
      },
    );
  }
}

/// Brings line [line] on screen: about a third of the way down.
///
/// With rows of one height the place is known. Prose is as high as its
/// words make it, so the place is sought: a jump to where the line
/// should be, a look at which lines are built there, and again.
Future<void> revealTextLine({
  required int line,

  /// Where in the line's text the place to show is.
  required int offset,
  required int lineCount,
  required ScrollController scroll,
  required MediaReaderBuiltLines built,
  required MediaReaderTextLayout layout,
}) async {
  if (!scroll.hasClients) return;
  final position = scroll.position;
  if (layout.rows case final rows?) {
    final top = rows.rowOf(line, offset) * layout.rowHeight;
    return position.jumpTo(
      (top - position.viewportDimension / 3).clamp(0, position.maxScrollExtent),
    );
  }
  for (var tries = 0; tries < 12; tries++) {
    final context = built[line];
    if (context != null && context.mounted) {
      return await position.ensureVisible(
        context.findRenderObject()!,
        alignment: 0.3,
      );
    }
    if (built.isEmpty || lineCount == 0) return;
    // The list's own guess at a line's height, from those it has built.
    final each =
        (position.maxScrollExtent + position.viewportDimension) / lineCount;
    final first = built.keys.reduce(math.min);
    final last = built.keys.reduce(math.max);
    final from = line < first ? first : last;
    position.jumpTo(
      (position.pixels + (line - from) * each).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!scroll.hasClients) return;
  }
}
