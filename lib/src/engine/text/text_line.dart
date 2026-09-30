/// One line of a text on screen (MEDIA_READER_PLAN.md R6), or one row of
/// a long line, with what the search found in it marked.
library;

import 'package:flutter/widgets.dart';

/// A line as it is shown. A tab is four columns: Flutter gives it no
/// width of its own.
String displayedLine(String line) => line.replaceAll('\t', '    ');

/// The lines that are built now, by their number: how the view finds a
/// line to bring it on screen.
typedef MediaReaderBuiltLines = Map<int, BuildContext>;

/// Line [index] of the text, or the part of it one row shows.
class const MediaReaderTextLine({
  required final int index,

  /// The whole line, as it is displayed.
  required final String text,

  /// The part of [text] this row shows; all of it when null.
  final ({int start, int end})? range,
  required final TextStyle style,

  /// Whether a long line goes on below in this same widget. A row of a
  /// line laid out in rows does not: it is one row high.
  required final bool wrap,

  /// Whether the line ends with this row. What is copied from several
  /// lines then has its line breaks.
  final bool endsLine = true,

  /// What the search looks for, and which of this line's matches is the
  /// one gone to: null when it is none of them.
  final RegExp? pattern,
  final int? active,

  /// What a match is marked with: the one gone to, more strongly.
  required final Color mark,

  /// Where the line says it is built, when the view needs to find it.
  final MediaReaderBuiltLines? built,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderTextLine> createState() => _MediaReaderTextLineState();
}

class _MediaReaderTextLineState() extends State<MediaReaderTextLine> {
  // A line break that takes no room: it is there to be copied.
  static const _break = TextSpan(
    text: '\n',
    style: TextStyle(fontSize: 0.01, height: 0.01),
  );

  @override
  void initState() {
    super.initState();
    widget.built?[widget.index] = context;
  }

  @override
  void didUpdateWidget(MediaReaderTextLine old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    final built = old.built;
    if (built != null && identical(built[old.index], context)) {
      built.remove(old.index);
    }
    widget.built?[widget.index] = context;
  }

  @override
  void dispose() {
    final built = widget.built;
    if (built != null && identical(built[widget.index], context)) {
      built.remove(widget.index);
    }
    super.dispose();
  }

  /// The part of the text from [start] to [end], the matches in it
  /// marked.
  List<InlineSpan> _spans(int start, int end) {
    final text = widget.text;
    final pattern = widget.pattern;
    if (pattern == null) return [TextSpan(text: text.substring(start, end))];
    final spans = <InlineSpan>[];
    var from = start;
    for (final (place, match) in pattern.allMatches(text).indexed) {
      if (match.end <= from || match.end == match.start) continue;
      if (match.start >= end) break;
      final first = match.start < from ? from : match.start;
      final last = match.end > end ? end : match.end;
      if (first > from) spans.add(TextSpan(text: text.substring(from, first)));
      spans.add(
        TextSpan(
          text: text.substring(first, last),
          style: TextStyle(
            backgroundColor: widget.mark.withValues(
              alpha: place == widget.active ? 0.9 : 0.4,
            ),
          ),
        ),
      );
      from = last;
    }
    if (from < end) spans.add(TextSpan(text: text.substring(from, end)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    return Text.rich(
      TextSpan(
        children: [
          ..._spans(range?.start ?? 0, range?.end ?? widget.text.length),
          if (widget.endsLine) _break,
        ],
      ),
      style: widget.style,
      softWrap: widget.wrap,
      maxLines: widget.wrap ? null : 1,
      overflow: TextOverflow.clip,
    );
  }
}
