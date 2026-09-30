/// A Markdown file on its page (MEDIA_READER_PLAN.md R6): laid out by
/// `flutter_markdown_plus` in the chrome's colours, with the reader's
/// own selection, links and images.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../io/media_reader_bytes.dart';
import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_document.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_selection.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/scroll_keys.dart';
import '../text/text_engine.dart';
import '../text/text_lines.dart';
import '../text/text_view.dart';
import 'markdown_engine.dart';
import 'markdown_style.dart';

/// The Markdown engine's widget.
class const MediaReaderMarkdownView({
  required final MediaReaderMarkdownEngine engine,

  /// The file shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderMarkdownView> createState() =>
      _MediaReaderMarkdownViewState();
}

class _MediaReaderMarkdownViewState()
    extends State<MediaReaderMarkdownView>
    implements MediaReaderDocument {
  final ValueNotifier<MediaReaderDocumentState> _state = ValueNotifier(
    const MediaReaderDocumentState(searchable: false),
  );
  final ScrollController _scroll = ScrollController();
  final FocusNode _keys = FocusNode(debugLabel: 'MediaReaderMarkdownView');
  MediaReaderByteLoader? _loader;

  /// The file's text, once it has come; null when it is too long to lay
  /// out, and is shown as it is written.
  String? _text;
  Uint8List? _bytes;
  bool _started = false;
  bool _loaded = false;
  bool _formatted = true;

  MediaReaderPage get _page => widget.page;

  @override
  ValueListenable<MediaReaderDocumentState> get state => _state;

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
      limit: engine.maxFormattedBytes,
      fetcher: MediaReaderFetcher(engine.transport),
    );
    try {
      final loaded = await loader.load();
      if (!mounted) return;
      final short = loaded.total <= engine.maxFormattedBytes;
      final lines = MediaReaderTextLines(loaded.bytes)
        ..extend(loaded.bytes.length, done: true);
      setState(() {
        _loaded = true;
        _bytes = loaded.bytes;
        _text = short ? lines.text : null;
      });
      _page
        ..document.value = this
        ..holdsDismiss.value = true;
      _tell();
      if (_page.isCurrent.value) _takeKeyboard();
    } on Object catch (error) {
      _fail(error);
    }
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

  void _tell() => _state.value = MediaReaderDocumentState(
    searchable: false,
    toggles: [
      if (_text != null)
        MediaReaderToggle(
          label: _page.chrome.strings.formatted,
          on: _formatted,
          onChanged: (on) {
            setState(() => _formatted = on);
            _tell();
          },
        ),
    ],
  );

  @override
  Future<void> goToPage(int number) async {}

  @override
  Widget thumbnail(BuildContext context, int number) => const SizedBox.shrink();

  @override
  void search(String query) {}

  @override
  Future<void> nextMatch() async {}

  @override
  Future<void> previousMatch() async {}

  /// A link is the host's to open, or not (MR12, MR8).
  void _onLink(String text, String? href, String title) {
    final link = href == null ? null : Uri.tryParse(href);
    if (link != null) _page.openLink(link);
  }

  @override
  void dispose() {
    _page.isCurrent.removeListener(_onCurrent);
    if (identical(_page.document.value, this)) _page.document.value = null;
    _loader?.cancel();
    _scroll.dispose();
    _keys.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = _page.chrome;
    final text = _text;
    if (!_loaded) {
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
    // Too long to lay out, or wanted as it is written: a text like any
    // other, in the text engine's own view. What has come already is
    // not fetched again.
    if (text == null || !_formatted) {
      final item = widget.item;
      return MediaReaderTextView(
        engine: MediaReaderTextEngine(
          transport: widget.engine.transport,
          maxBytes: widget.engine.maxBytes,
        ),
        item: text == null
            ? item
            : MediaReaderItem(
                id: item.id,
                name: item.name,
                contentType: item.contentType,
                size: item.size,
                kind: item.kind,
                source: MediaReaderSource.bytes(_bytes!),
                poster: item.poster,
                data: item.data,
              ),
        page: _page,
        // The page's document stays this one: the text's search and
        // choices are not offered over the Markdown's.
        standalone: false,
      );
    }
    final safe = MediaQuery.paddingOf(context);
    return Focus(
      focusNode: _keys,
      onKeyEvent: (node, event) => scrollByKey(_scroll, event),
      child: MediaReaderSelectable(
        chrome: chrome,
        onTap: _page.toggleChrome,
        child: Markdown(
          data: text,
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            16 + safe.left,
            safe.top + chrome.contentInsets.top + 8,
            16 + safe.right,
            safe.bottom + chrome.contentInsets.bottom + 8,
          ),
          styleSheet: markdownStyleOf(chrome, links: _page.opensLinks),
          onTapLink: _onLink,
          // An image is never fetched (MR12): its words stand for it.
          imageBuilder: (uri, title, alt) => MediaReaderImageStandIn(
            text: alt ?? title ?? uri.pathSegments.lastOrNull ?? '',
            chrome: chrome,
          ),
        ),
      ),
    );
  }
}
