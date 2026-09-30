/// A PDF as the chrome's controls see it (MEDIA_READER_PLAN.md R5): its
/// pages, and its search.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../shell/media_reader_document.dart';

/// The open [PdfDocument] in its viewer, behind [MediaReaderDocument].
final class MediaReaderPdfDocument(
  final PdfDocument _document,
  final PdfViewerController _controller, {

  /// How far below the top of the view a page gone to starts, in pixels:
  /// the room the chrome takes there.
  required final double Function() _topInset,
}) implements MediaReaderDocument {
  late final ValueNotifier<MediaReaderDocumentState> _state = ValueNotifier(
    MediaReaderDocumentState(
      pageNumber: _controller.pageNumber ?? 1,
      pageCount: _controller.pageCount,
    ),
  );
  late final PdfTextSearcher _searcher = PdfTextSearcher(_controller)
    ..addListener(_onSearch);
  String _query = '';
  bool _disposed = false;

  @override
  ValueListenable<MediaReaderDocumentState> get state => _state;

  /// Draws the search's matches on a page: for the viewer's paint
  /// callbacks.
  void paintMatches(Canvas canvas, Rect pageRect, PdfPage page) =>
      _searcher.pageTextMatchPaintCallback(canvas, pageRect, page);

  /// The viewer shows another page.
  void onPage(int? number) => _set(pageNumber: number);

  @override
  Future<void> goToPage(int number) => _goTo(number);

  /// Puts the first page where the document starts: below the chrome.
  /// The viewer itself starts with the page's top at the view's.
  void start() => unawaited(_goTo(1, duration: Duration.zero));

  Future<void> _goTo(
    int number, {
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    if (_disposed || !_controller.isReady) return;
    final top = _controller.calcMatrixForPage(
      pageNumber: number.clamp(1, _controller.pageCount),
      anchor: PdfPageAnchor.top,
    );
    // The page's top comes below the chrome, not under it.
    await _controller.goTo(
      Matrix4.translationValues(0, _topInset(), 0).multiplied(top),
      duration: duration,
    );
  }

  @override
  Widget thumbnail(BuildContext context, int number) => PdfPageView(
    document: _document,
    pageNumber: number,
    // A thumbnail is small: a quarter of the default is more than it
    // shows.
    maximumDpi: 72,
    decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
  );

  @override
  void search(String query) {
    if (_disposed || query == _query) return;
    _query = query;
    if (query.isEmpty) {
      _searcher.resetTextSearch();
    } else {
      _searcher.startTextSearch(query);
    }
    _onSearch();
  }

  @override
  Future<void> nextMatch() async {
    if (!_disposed && _searcher.hasMatches) await _searcher.goToNextMatch();
  }

  @override
  Future<void> previousMatch() async {
    if (!_disposed && _searcher.hasMatches) await _searcher.goToPrevMatch();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _searcher
      ..removeListener(_onSearch)
      ..dispose();
    _state.dispose();
  }

  void _onSearch() => _set();

  void _set({int? pageNumber}) {
    if (_disposed) return;
    final now = _state.value;
    final searching = _query.isNotEmpty;
    _state.value = MediaReaderDocumentState(
      pageNumber: pageNumber ?? now.pageNumber,
      pageCount: _controller.isReady ? _controller.pageCount : now.pageCount,
      query: _query,
      matchCount: searching ? _searcher.matches.length : 0,
      matchNumber: searching ? (_searcher.currentIndex ?? -1) + 1 : 0,
      searching: searching && _searcher.isSearching,
    );
  }
}
