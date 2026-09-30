/// The plain default controls for a document (MR10, R5): its pages as a
/// strip, and its search. A host replaces them through the chrome's
/// `controls` slot.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'document_pages.dart';
import 'media_reader_chrome.dart';
import 'media_reader_document.dart';
import 'plain_field.dart';
import 'plain_widgets.dart';

/// What the bar shows above or in place of its two buttons.
enum _Showing() {
  tools,
  pages,
  search,
}

/// The default document bar. Like every such bar, it runs left to right
/// in every language.
class const MediaReaderDocumentBar({
  required final MediaReaderDocument document,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderDocumentBar> createState() => _MediaReaderDocumentBarState();
}

class _MediaReaderDocumentBarState() extends State<MediaReaderDocumentBar> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode(debugLabel: 'MediaReaderDocumentBar');
  _Showing _showing = _Showing.tools;

  MediaReaderDocument get _document => widget.document;

  @override
  void didUpdateWidget(MediaReaderDocumentBar old) {
    super.didUpdateWidget(old);
    if (identical(old.document, _document)) return;
    // Another document came on screen: the search was the last one's.
    old.document.search('');
    _query.clear();
    _showing = _Showing.tools;
  }

  void _toggle(_Showing showing) {
    setState(() => _showing = _showing == showing ? _Showing.tools : showing);
    if (_showing == _Showing.search) _queryFocus.requestFocus();
  }

  void _endSearch() {
    _query.clear();
    _document.search('');
    setState(() => _showing = _Showing.tools);
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showing == _Showing.pages) ...[
          MediaReaderDocumentPages(document: _document, chrome: widget.chrome),
          const SizedBox(height: 8),
        ],
        if (_showing == _Showing.search) _search() else _tools(),
      ],
    ),
  );

  Widget _bar({required Widget child}) => DecoratedBox(
    decoration: ShapeDecoration(
      color: widget.chrome.background.withValues(alpha: 0.6),
      shape: const StadiumBorder(),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: child,
    ),
  );

  Widget _tools() {
    final strings = widget.chrome.strings;
    final colour = widget.chrome.foreground;
    return Center(
      child: _bar(
        child: ValueListenableBuilder(
          valueListenable: _document.state,
          builder: (context, state, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A text has no pages to show in a strip.
              if (state.pageCount > 0)
                MediaReaderGlyphButton(
                  glyph: MediaReaderGlyph.pages,
                  label: strings.pages,
                  colour: colour,
                  onPressed: () => _toggle(_Showing.pages),
                ),
              if (state.searchable)
                MediaReaderGlyphButton(
                  glyph: MediaReaderGlyph.search,
                  label: strings.search,
                  colour: colour,
                  onPressed: () => _toggle(_Showing.search),
                ),
              for (final toggle in state.toggles)
                Semantics(
                  toggled: toggle.on,
                  child: Opacity(
                    opacity: toggle.on ? 1 : 0.5,
                    child: MediaReaderTextButton(
                      text: toggle.label,
                      onPressed: () => toggle.onChanged(!toggle.on),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _search() {
    final strings = widget.chrome.strings;
    final colour = widget.chrome.foreground;
    return CallbackShortcuts(
      // Esc ends the search before it closes the reader.
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _endSearch},
      child: _bar(
        child: ValueListenableBuilder(
          valueListenable: _document.state,
          builder: (context, state, _) {
            final found = state.matchCount > 0;
            return Row(
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: MediaReaderPlainField(
                    controller: _query,
                    focusNode: _queryFocus,
                    colour: colour,
                    hint: strings.searchHint,
                    action: TextInputAction.search,
                    onChanged: _document.search,
                    onSubmitted: (_) {
                      unawaited(_document.nextMatch());
                      _queryFocus.requestFocus();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  switch (state) {
                    _ when state.query.isEmpty => '',
                    _ when found => strings.position(
                      state.matchNumber,
                      state.matchCount,
                    ),
                    _ when state.searching => '',
                    _ => strings.noMatches,
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                MediaReaderGlyphButton(
                  glyph: MediaReaderGlyph.up,
                  label: strings.previousMatch,
                  colour: colour.withValues(alpha: found ? 1 : 0.4),
                  onPressed: found
                      ? () => unawaited(_document.previousMatch())
                      : null,
                ),
                MediaReaderGlyphButton(
                  glyph: MediaReaderGlyph.down,
                  label: strings.nextMatch,
                  colour: colour.withValues(alpha: found ? 1 : 0.4),
                  onPressed: found
                      ? () => unawaited(_document.nextMatch())
                      : null,
                ),
                MediaReaderGlyphButton(
                  glyph: MediaReaderGlyph.close,
                  label: strings.endSearch,
                  colour: colour,
                  onPressed: _endSearch,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
