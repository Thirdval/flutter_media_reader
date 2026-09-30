/// How Markdown is set in the reader (MEDIA_READER_PLAN.md R6): the
/// chrome's colours, plain type, and nothing of a design system.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../shell/media_reader_chrome.dart';

/// A style sheet in [chrome]'s colours. Links look like links only
/// while the host opens them ([links]).
MarkdownStyleSheet markdownStyleOf(
  MediaReaderChrome chrome, {
  required bool links,
}) {
  final colour = chrome.foreground;
  final faint = colour.withValues(alpha: 0.6);
  final line = colour.withValues(alpha: 0.25);
  final plate = colour.withValues(alpha: 0.08);
  const monospace = [
    'Menlo',
    'SF Mono',
    'Roboto Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Courier New',
  ];
  final body = TextStyle(color: colour, fontSize: 16, height: 1.5);
  TextStyle heading(double size) =>
      TextStyle(color: colour, fontSize: size, fontWeight: FontWeight.w700);
  final code = TextStyle(
    color: colour,
    fontSize: 14,
    fontFamily: 'monospace',
    fontFamilyFallback: monospace,
    backgroundColor: plate,
  );
  return MarkdownStyleSheet(
    p: body,
    a: links
        ? TextStyle(color: colour, decoration: TextDecoration.underline)
        : TextStyle(color: colour),
    h1: heading(28),
    h2: heading(24),
    h3: heading(20),
    h4: heading(18),
    h5: heading(16),
    h6: heading(16),
    em: const TextStyle(fontStyle: FontStyle.italic),
    strong: const TextStyle(fontWeight: FontWeight.w700),
    del: const TextStyle(decoration: TextDecoration.lineThrough),
    blockquote: body.copyWith(color: faint),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: line, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    code: code,
    codeblockDecoration: BoxDecoration(
      color: plate,
      borderRadius: BorderRadius.circular(6),
    ),
    codeblockPadding: const EdgeInsets.all(10),
    listBullet: body,
    checkbox: body,
    tableHead: body.copyWith(fontWeight: FontWeight.w700),
    tableBody: body,
    tableBorder: TableBorder.all(color: line),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: line)),
    ),
    blockSpacing: 12,
  );
}

/// Where an image would be: its words, in a plate. The image itself is
/// never fetched (MR12).
class const MediaReaderImageStandIn({
  required final String text,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: chrome.foreground.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: chrome.foreground.withValues(alpha: 0.25)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: chrome.foreground.withValues(alpha: 0.7),
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}
