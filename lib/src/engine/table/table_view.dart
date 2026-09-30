/// A CSV or TSV file on its page (MEDIA_READER_PLAN.md R6): a table that
/// builds only the cells on screen, its header row pinned, with a search
/// and text that can be selected and copied.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import '../../io/media_reader_bytes.dart';
import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_selection.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/scroll_keys.dart';
import '../text/text_document.dart';
import '../text/text_lines.dart';
import '../text/text_search.dart';
import 'table_data.dart';
import 'table_engine.dart';

/// The table engine's widget.
class const MediaReaderTableView({
  required final MediaReaderTableEngine engine,

  /// The table shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderTableView> createState() => _MediaReaderTableViewState();
}

class _MediaReaderTableViewState() extends State<MediaReaderTableView> {
  static const _rowHeight = 32.0;
  static const _headerHeight = 36.0;

  // A break that takes no room: what is copied from several cells has
  // its tabs and its line breaks.
  static const _tab = TextSpan(
    text: '\t',
    style: TextStyle(fontSize: 0.01, height: 0.01),
  );
  static const _break = TextSpan(
    text: '\n',
    style: TextStyle(fontSize: 0.01, height: 0.01),
  );

  late final MediaReaderTextSearch _search = MediaReaderTextSearch(
    lineCount: () => _data?.rowCount ?? 0,
    lineAt: (index) => _data!.rowText(index),
    onChanged: _onSearch,
  );
  late final MediaReaderTextDocument _document = MediaReaderTextDocument(
    search: _search,
    reveal: _reveal,
  );
  final ScrollController _down = ScrollController();
  final ScrollController _across = ScrollController();
  final FocusNode _keys = FocusNode(debugLabel: 'MediaReaderTableView');

  MediaReaderByteLoader? _loader;
  MediaReaderTextLines? _lines;
  MediaReaderTableData? _data;
  bool _started = false;
  bool _loaded = false;
  bool _fits = true;
  String? _shownFirstFor;

  MediaReaderPage get _page => widget.page;

  @override
  void initState() {
    super.initState();
    _page.isCurrent.addListener(_onCurrent);
    if (_page.isCurrent.value) unawaited(_load());
  }

  void _onCurrent() {
    if (_page.isCurrent.value) {
      unawaited(_load());
      _takeKeyboard();
    } else if (_keys.hasFocus) {
      Focus.maybeOf(context)?.requestFocus();
    }
  }

  void _takeKeyboard() {
    if (!mounted || !_loaded) return;
    if (Focus.maybeOf(context)?.hasFocus ?? false) _keys.requestFocus();
  }

  Future<void> _load() async {
    if (_started) return;
    _started = true;
    final engine = widget.engine;
    final loader = _loader = MediaReaderByteLoader(
      item: widget.item,
      page: _page,
      limit: engine.maxBytes,
      fetcher: MediaReaderFetcher(engine.transport),
      blockSize: engine.blockSize,
    );
    try {
      final loaded = await loader.load(onPart: _onPart);
      if (!mounted) return;
      final lines = _lines ??= MediaReaderTextLines(loaded.bytes, quoted: true);
      lines.extend(loaded.bytes.length, done: true);
      setState(() {
        _loaded = true;
        _data?.invalidateRows();
      });
      _page
        ..document.value = _document
        ..holdsDismiss.value = true
        ..status.value = _page.chrome.strings.rows(lines.count);
      _document.update();
      if (_page.isCurrent.value) _takeKeyboard();
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// More of the file has come: its rows so far are shown.
  void _onPart(Uint8List buffer, int filled) {
    if (!mounted) return;
    setState(() {
      final lines = _lines ??= MediaReaderTextLines(buffer, quoted: true);
      lines.extend(filled, done: false);
      _data ??= MediaReaderTableData(lines);
      _data!.invalidateRows();
    });
  }

  void _fail(Object error) {
    if (!mounted || _page.failure.value != null) return;
    final strings = _page.chrome.strings;
    _page.fail(switch (error) {
      MediaReaderUnavailable(:final reason) => reason,
      MediaReaderFetchException() => strings.unreachable,
      FileSystemException() => strings.failed,
      _ => strings.failed,
    });
  }

  void _onSearch() {
    if (!mounted) return;
    _document.update();
    if (_search.query.isEmpty) {
      _shownFirstFor = null;
    } else if (_search.count > 0 && _shownFirstFor != _search.query) {
      _shownFirstFor = _search.query;
      _reveal();
    }
    setState(() {});
  }

  /// Brings the row of the match gone to on screen.
  void _reveal() {
    final at = _search.at;
    if (at == null || !_down.hasClients) return;
    setState(() {});
    final position = _down.position;
    _down.jumpTo(
      (at.line * _rowHeight - position.viewportDimension / 3).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
  }

  /// A cell: its text, with what the search found in it marked.
  TableViewCell _cell(BuildContext context, TableVicinity vicinity) {
    final data = _data!;
    final header = vicinity.row == 0;
    final cells = data.row(vicinity.row);
    final text = vicinity.column < cells.length ? cells[vicinity.column] : '';
    final chrome = _page.chrome;
    final style = TextStyle(
      color: chrome.foreground,
      fontSize: 14,
      fontWeight: header ? FontWeight.w700 : FontWeight.w400,
    );
    final active = _search.at?.line == vicinity.row;
    final pattern = _search.pattern;
    return TableViewCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(
              children: [
                if (pattern == null)
                  TextSpan(text: text)
                else
                  ..._marked(text, pattern, active),
                vicinity.column == data.columnCount - 1 ? _break : _tab,
              ],
            ),
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _marked(String text, RegExp pattern, bool active) {
    final spans = <InlineSpan>[];
    var from = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.end == match.start) continue;
      if (match.start > from) {
        spans.add(TextSpan(text: text.substring(from, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: const Color(0xFFFFC107)
                .withValues(alpha: active ? 0.9 : 0.4),
          ),
        ),
      );
      from = match.end;
    }
    if (from < text.length) spans.add(TextSpan(text: text.substring(from)));
    return spans;
  }

  @override
  void dispose() {
    _page.isCurrent.removeListener(_onCurrent);
    if (identical(_page.document.value, _document)) _page.document.value = null;
    _loader?.cancel();
    _document.dispose();
    _down.dispose();
    _across.dispose();
    _keys.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = _page.chrome;
    final data = _data;
    if (data == null || data.rowCount == 0) {
      final poster = widget.item.poster;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (poster != null) ExcludeSemantics(child: poster(context)),
          if (_page.isCurrent.value)
            Center(child: MediaReaderBusy(chrome: chrome)),
        ],
      );
    }
    // The delimiter the name says, where it does.
    final delimiter = data.delimiter(
      named: widget.item.format == 'tsv' ? '\t' : null,
    );
    assert(delimiter.isNotEmpty);
    final digit = TextPainter(
      text: const TextSpan(text: '0', style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final charWidth = digit.width;
    digit.dispose();
    final widths = [
      for (final chars in data.columnChars)
        (chars * charWidth + 20).clamp(64.0, 360.0),
    ];
    final safe = MediaQuery.paddingOf(context);
    final line = chrome.foreground.withValues(alpha: 0.15);
    final lines = _lines!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widths.fold(0.0, (sum, width) => sum + width);
        final fits = width <= constraints.maxWidth - safe.horizontal;
        if (fits != _fits) {
          _fits = fits;
          // A table wider than the screen takes sideways drags.
          SchedulerBindingCompat.afterFrame(() {
            if (mounted) _page.holdsPaging.value = !fits;
          });
        }
        return Focus(
          focusNode: _keys,
          onKeyEvent: (node, event) => scrollByKey(_down, event),
          child: MediaReaderSelectable(
            chrome: chrome,
            onTap: _page.toggleChrome,
            all: _loaded && lines.bytes.length <= 1024 * 1024
                ? () => lines.text
                : null,
            child: TableView.builder(
              verticalDetails: ScrollableDetails.vertical(controller: _down),
              horizontalDetails: ScrollableDetails.horizontal(
                controller: _across,
                // A table that fits leaves sideways drags to the pager.
                physics: fits ? const NeverScrollableScrollPhysics() : null,
              ),
              pinnedRowCount: 1,
              columnCount: data.columnCount,
              rowCount: data.rowCount,
              columnBuilder: (index) => TableSpan(
                extent: FixedTableSpanExtent(widths[index]),
                padding: index == 0
                    ? TableSpanPadding(leading: 8 + safe.left)
                    : null,
                foregroundDecoration: TableSpanDecoration(
                  border: TableSpanBorder(trailing: BorderSide(color: line)),
                ),
              ),
              rowBuilder: (index) => TableSpan(
                extent: FixedTableSpanExtent(
                  index == 0 ? _headerHeight : _rowHeight,
                ),
                padding: index == 0
                    ? TableSpanPadding(
                        leading: safe.top + chrome.contentInsets.top,
                      )
                    : index == data.rowCount - 1
                    ? TableSpanPadding(
                        trailing: safe.bottom + chrome.contentInsets.bottom,
                      )
                    : null,
                backgroundDecoration: index == 0
                    ? TableSpanDecoration(
                        color: chrome.background.withValues(alpha: 0.85),
                      )
                    : null,
                foregroundDecoration: TableSpanDecoration(
                  border: TableSpanBorder(trailing: BorderSide(color: line)),
                ),
              ),
              cellBuilder: _cell,
            ),
          ),
        );
      },
    );
  }
}

/// Runs a change after the frame: a layout may not set state.
abstract final class SchedulerBindingCompat() {
  static void afterFrame(VoidCallback change) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => change());
}
