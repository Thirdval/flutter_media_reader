/// A document's pages as a strip (MR10, R5): each page small, the one on
/// screen marked, and a field to go to a page by its number.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'media_reader_chrome.dart';
import 'media_reader_document.dart';
import 'plain_field.dart';

/// The strip the plain document bar opens.
class const MediaReaderDocumentPages({
  required final MediaReaderDocument document,
  required final MediaReaderChrome chrome,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderDocumentPages> createState() =>
      _MediaReaderDocumentPagesState();
}

class _MediaReaderDocumentPagesState() extends State<MediaReaderDocumentPages> {
  /// How wide a page is in the strip, with the space beside it.
  static const _extent = 76.0;

  late final ScrollController _strip = ScrollController(
    // The page on screen starts in view, with one before it.
    initialScrollOffset: math.max(0, (_pageNumber - 2) * _extent),
  );
  final TextEditingController _number = TextEditingController();
  final FocusNode _numberFocus = FocusNode(
    debugLabel: 'MediaReaderDocumentPages',
  );
  int _shown = 0;

  MediaReaderDocument get _document => widget.document;

  int get _pageNumber => _document.state.value.pageNumber;

  @override
  void initState() {
    super.initState();
    _shown = _pageNumber;
    _document.state.addListener(_follow);
  }

  @override
  void didUpdateWidget(MediaReaderDocumentPages old) {
    super.didUpdateWidget(old);
    if (identical(old.document, _document)) return;
    old.document.state.removeListener(_follow);
    _document.state.addListener(_follow);
  }

  /// Keeps the page on screen in view in the strip.
  void _follow() {
    final number = _pageNumber;
    if (number == _shown || !_strip.hasClients) return;
    _shown = number;
    final position = _strip.position;
    final at = (number - 1) * _extent;
    final inView =
        at >= position.pixels &&
        at + _extent <= position.pixels + position.viewportDimension;
    if (inView) return;
    final to = (at - _extent).clamp(0.0, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) return _strip.jumpTo(to);
    unawaited(
      _strip.animateTo(
        to,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
  }

  void _goTo(String typed) {
    final number = int.tryParse(typed);
    _number.clear();
    if (number != null) unawaited(_document.goToPage(number));
  }

  @override
  void dispose() {
    _document.state.removeListener(_follow);
    _strip.dispose();
    _number.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final strings = chrome.strings;
    final colour = chrome.foreground;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: chrome.background.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: ValueListenableBuilder(
          valueListenable: _document.state,
          builder: (context, state, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(color: colour.withValues(alpha: 0.5)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: SizedBox(
                        width: 96,
                        child: MediaReaderPlainField(
                          controller: _number,
                          focusNode: _numberFocus,
                          colour: colour,
                          hint: strings.goToPage,
                          digitsOnly: true,
                          action: TextInputAction.go,
                          onSubmitted: _goTo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Shrinks only where the width has no room for it.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        strings.position(state.pageNumber, state.pageCount),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 112,
                child: ListView.builder(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _extent,
                  itemCount: state.pageCount,
                  itemBuilder: (context, index) => _Page(
                    number: index + 1,
                    onScreen: index + 1 == state.pageNumber,
                    document: _document,
                    chrome: chrome,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page in the strip: a tap goes to it.
class const _Page({
  required final int number,
  required final bool onScreen,
  required final MediaReaderDocument document,
  required final MediaReaderChrome chrome,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colour = chrome.foreground;
    return Semantics(
      button: true,
      selected: onScreen,
      label: chrome.strings.pageNumber(number),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(document.goToPage(number)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colour.withValues(alpha: onScreen ? 1 : 0.25),
                        width: onScreen ? 2 : 1,
                      ),
                    ),
                    child: ExcludeSemantics(
                      child: document.thumbnail(context, number),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                ExcludeSemantics(
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: onScreen ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
