/// A text as the chrome's controls see it (MEDIA_READER_PLAN.md R6): no
/// pages, a search, and its choices.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../shell/media_reader_document.dart';
import 'text_search.dart';

/// The text on a page, behind [MediaReaderDocument].
final class MediaReaderTextDocument({
  required final MediaReaderTextSearch _search,

  /// Brings the match the search has gone to on screen.
  required final void Function() _reveal,
}) implements MediaReaderDocument {
  final ValueNotifier<MediaReaderDocumentState> _state = ValueNotifier(
    const MediaReaderDocumentState(),
  );
  List<MediaReaderToggle> _toggles = const [];
  bool _disposed = false;

  @override
  ValueListenable<MediaReaderDocumentState> get state => _state;

  /// The choices as they stand now.
  set toggles(List<MediaReaderToggle> toggles) {
    _toggles = toggles;
    update();
  }

  /// The search, or the choices, have changed.
  void update() {
    if (_disposed) return;
    _state.value = MediaReaderDocumentState(
      query: _search.query,
      matchCount: _search.count,
      matchNumber: _search.current + 1,
      searching: _search.searching,
      toggles: _toggles,
    );
  }

  @override
  Future<void> goToPage(int number) async {}

  @override
  Widget thumbnail(BuildContext context, int number) => const SizedBox.shrink();

  @override
  void search(String query) {
    if (_disposed || query == _search.query) return;
    unawaited(_search.start(query));
  }

  @override
  Future<void> nextMatch() async => _step(1);

  @override
  Future<void> previousMatch() async => _step(-1);

  void _step(int by) {
    if (_disposed || _search.count == 0) return;
    _search.step(by);
    _reveal();
  }

  void dispose() {
    _disposed = true;
    _search.dispose();
    _state.dispose();
  }
}
