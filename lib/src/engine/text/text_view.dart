/// A text file on its page (MEDIA_READER_PLAN.md R6): its start as soon
/// as it has come, the lines on screen and no others built, a search,
/// and text that can be selected and copied.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../io/media_reader_bytes.dart';
import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_document.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_selection.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/scroll_keys.dart';
import 'text_document.dart';
import 'text_engine.dart';
import 'text_format.dart';
import 'text_line.dart';
import 'text_lines.dart';
import 'text_list.dart';
import 'text_search.dart';

/// The text engine's widget.
class const MediaReaderTextView({
  required final MediaReaderTextEngine engine,

  /// The text shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,

  /// Whether this view is the page's own. Another engine that shows a
  /// file as text (Markdown, as it is written) keeps the page's document
  /// and choices to itself.
  final bool standalone = true,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderTextView> createState() => _MediaReaderTextViewState();
}

class _MediaReaderTextViewState() extends State<MediaReaderTextView> {
  static const _faces = [
    'Menlo',
    'SF Mono',
    'Roboto Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Courier New',
  ];

  late final MediaReaderTextFlavour _flavour = MediaReaderTextEngine.flavourOf(
    widget.item,
  );
  late final MediaReaderTextSearch _search = MediaReaderTextSearch(
    lineCount: () => _lines?.count ?? 0,
    lineAt: (index) => displayedLine(_lines!.line(index)),
    onChanged: _onSearch,
  );
  late final MediaReaderTextDocument _document = MediaReaderTextDocument(
    search: _search,
    reveal: _reveal,
  );
  final ScrollController _down = ScrollController();
  final ScrollController _across = ScrollController();
  final FocusNode _keys = FocusNode(debugLabel: 'MediaReaderTextView');
  final MediaReaderBuiltLines _built = {};

  MediaReaderByteLoader? _loader;

  /// The text as it is written, and laid out to be read where it can be.
  MediaReaderTextLines? _written;
  MediaReaderTextLines? _laidOut;
  bool _loaded = false;
  bool _started = false;

  /// How much of the file is shown, and its own length, when it was cut.
  ({int shown, int total})? _cut;
  bool _wrap = true;
  bool _formatted = true;
  String? _shownFirstFor;

  MediaReaderPage get _page => widget.page;

  /// The lines on screen: laid out, or as written.
  MediaReaderTextLines? get _lines =>
      _formatted ? _laidOut ?? _written : _written;

  @override
  void initState() {
    super.initState();
    _page.isCurrent.addListener(_onCurrent);
    if (_page.isCurrent.value) unawaited(_load());
  }

  /// A neighbour asks for nothing: the file is fetched when its page
  /// comes on screen.
  void _onCurrent() {
    if (_page.isCurrent.value) {
      unawaited(_load());
      _takeKeyboard();
    } else if (_keys.hasFocus) {
      // The keys go back to the reader: the arrows page between files.
      Focus.maybeOf(context)?.requestFocus();
    }
  }

  /// The lines take the keys (Page Down, the arrows) while the reader has
  /// them, never from a field beside the reader.
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
      final written = _written ??= MediaReaderTextLines(loaded.bytes);
      written.extend(loaded.bytes.length, done: true);
      setState(() {
        _loaded = true;
        _laidOut = _layOut(written, loaded.bytes.length);
        if (loaded.total > loaded.bytes.length) {
          _cut = (shown: loaded.bytes.length, total: loaded.total);
        }
      });
      // The lines scroll up and down: a drag down is theirs.
      _page.holdsDismiss.value = true;
      if (widget.standalone) {
        _page.document.value = _document;
        _tell();
      }
      if (_page.isCurrent.value) _takeKeyboard();
    } on Object catch (error) {
      _fail(error);
    }
  }

  /// More of the file has come: its lines so far are shown.
  void _onPart(Uint8List buffer, int filled) {
    if (!mounted) return;
    setState(() {
      (_written ??= MediaReaderTextLines(buffer)).extend(filled, done: false);
    });
  }

  /// The JSON or XML laid out to be read, when it is small enough and
  /// well enough formed.
  MediaReaderTextLines? _layOut(MediaReaderTextLines written, int length) {
    if (length > widget.engine.maxFormattedBytes) return null;
    final text = switch (_flavour) {
      MediaReaderTextFlavour.json => prettyJson(written.text),
      MediaReaderTextFlavour.xml => prettyXml(written.text),
      _ => null,
    };
    if (text == null) return null;
    final bytes = utf8.encode(text);
    return MediaReaderTextLines(bytes)..extend(bytes.length, done: true);
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

  /// Tells the chrome's controls the choices as they stand.
  void _tell() {
    if (!widget.standalone) return;
    final strings = _page.chrome.strings;
    _document.toggles = [
      MediaReaderToggle(label: strings.wrap, on: _wrap, onChanged: _setWrap),
      if (_laidOut != null)
        MediaReaderToggle(
          label: strings.formatted,
          on: _formatted,
          onChanged: _setFormatted,
        ),
    ];
    // Lines that go on to the right take sideways drags.
    _page.holdsPaging.value = !_wrap;
  }

  void _setWrap(bool wrap) {
    setState(() => _wrap = wrap);
    _tell();
  }

  void _setFormatted(bool formatted) {
    setState(() => _formatted = formatted);
    _tell();
    // Other lines: what was found is found again in them.
    final query = _search.query;
    if (query.isNotEmpty) unawaited(_search.start(query));
  }

  void _onSearch() {
    if (!mounted) return;
    _document.update();
    if (_search.query.isEmpty) {
      _shownFirstFor = null;
    } else if (_search.count > 0 && _shownFirstFor != _search.query) {
      // The first match is gone to as soon as it is found.
      _shownFirstFor = _search.query;
      _reveal();
    }
    setState(() {});
  }

  /// Brings the match the search has gone to on screen.
  void _reveal() {
    final at = _search.at;
    final lines = _lines;
    final pattern = _search.pattern;
    if (at == null || lines == null || pattern == null) return;
    setState(() {});
    final text = displayedLine(lines.line(at.line));
    unawaited(
      revealTextLine(
        line: at.line,
        offset: pattern.allMatches(text).elementAtOrNull(at.place)?.start ?? 0,
        lineCount: lines.count,
        scroll: _down,
        built: _built,
        layout: _layout,
      ),
    );
  }

  MediaReaderTextLayout _layout = (rows: null, rowHeight: 0);

  /// Prose is a short text in the reader's own face, wrapped at its
  /// words. A long one is laid out in rows like everything else, to
  /// scroll as a short one does.
  bool get _prose =>
      _wrap &&
      _flavour == MediaReaderTextFlavour.prose &&
      (_lines?.bytes.length ?? 0) <= widget.engine.maxFormattedBytes;

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
    final lines = _lines;
    if (lines == null || lines.count == 0 && !_loaded) {
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
    final prose = _prose;
    final style = TextStyle(
      color: chrome.foreground,
      fontSize: prose ? 16 : 13.5,
      height: prose ? 1.45 : 1.35,
      fontFamily: prose ? null : 'monospace',
      fontFamilyFallback: prose ? null : _faces,
    );
    final safe = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(
      16 + safe.left,
      safe.top + chrome.contentInsets.top + 8,
      16 + safe.right,
      safe.bottom + chrome.contentInsets.bottom + 8,
    );
    final cut = _cut;
    final list = MediaReaderTextList(
      lines: lines,
      prose: prose,
      wrap: _wrap,
      style: style,
      padding: padding,
      down: _down,
      across: _across,
      built: _built,
      onLayout: (layout) => _layout = layout,
      pattern: _search.pattern,
      active: _search.at,
      mark: const Color(0xFFFFC107),
      foot: cut == null
          ? null
          : chrome.strings.cutShort(
              chrome.strings.size(cut.shown),
              chrome.strings.size(cut.total),
            ),
    );
    return Focus(
      focusNode: _keys,
      onKeyEvent: (node, event) => scrollByKey(_down, event),
      child: MediaReaderSelectable(
        chrome: chrome,
        onTap: _page.toggleChrome,
        // All of a text that is small enough for a clipboard.
        all: _loaded && cut == null && lines.bytes.length <= 1024 * 1024
            ? () => lines.text
            : null,
        child: list,
      ),
    );
  }
}
