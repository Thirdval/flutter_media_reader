/// A pretend document for the document bar's tests (MR14): it does what
/// it is told and remembers it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

class FakeDocument({
  int pageCount = 12,
  int pageNumber = 1,

  /// How many matches each query has; none for a query not named.
  final Map<String, int> _found = const {},
}) implements MediaReaderDocument {
  final ValueNotifier<MediaReaderDocumentState> _state = ValueNotifier(
    MediaReaderDocumentState(pageNumber: pageNumber, pageCount: pageCount),
  );

  /// Every page gone to, in order.
  final List<int> wentTo = [];

  /// Every query searched for, in order; an empty one ends a search.
  final List<String> searches = [];

  @override
  ValueListenable<MediaReaderDocumentState> get state => _state;

  void _set({int? pageNumber, String? query, int? matchNumber}) {
    final now = _state.value;
    final asked = query ?? now.query;
    final count = _found[asked] ?? 0;
    _state.value = MediaReaderDocumentState(
      pageNumber: pageNumber ?? now.pageNumber,
      pageCount: now.pageCount,
      query: asked,
      matchCount: count,
      matchNumber: matchNumber ?? (count > 0 ? 1 : 0),
    );
  }

  /// The person scrolled to page [number].
  void scrolledTo(int number) => _set(pageNumber: number);

  @override
  Future<void> goToPage(int number) async {
    wentTo.add(number);
    _set(pageNumber: number.clamp(1, _state.value.pageCount));
  }

  @override
  Widget thumbnail(BuildContext context, int number) =>
      SizedBox.expand(key: ValueKey('thumbnail-$number'));

  @override
  void search(String query) {
    searches.add(query);
    _set(query: query);
  }

  @override
  Future<void> nextMatch() async {
    final now = _state.value;
    if (now.matchCount == 0) return;
    _set(matchNumber: now.matchNumber % now.matchCount + 1);
  }

  @override
  Future<void> previousMatch() async {
    final now = _state.value;
    if (now.matchCount == 0) return;
    _set(matchNumber: (now.matchNumber - 2) % now.matchCount + 1);
  }
}

/// Shows every file as a page with [document] on it.
class DocumentEngine(final FakeDocument document) implements MediaReaderEngine {
  @override
  String get id => 'document';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) => true;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) {
    page.document.value = document;
    return Center(child: Text('document:${item.name}'));
  }
}
