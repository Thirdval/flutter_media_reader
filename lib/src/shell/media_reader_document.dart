/// What a page shows that is read rather than looked at or played (a
/// PDF in R5; a text, a Markdown file, a table in R6), as the chrome's
/// controls see it: where it stands, and the commands a control gives.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A choice about how a document is shown, for the chrome's controls: a
/// text's lines wrapped or not, a Markdown file formatted or as it is
/// written.
class const MediaReaderToggle({
  /// The toggle's name, from the chrome's strings.
  required final String label,
  required final bool on,
  required final ValueChanged<bool> onChanged,
});

/// Where a document stands: the page on screen, its search, and the
/// choices about how it is shown.
class const MediaReaderDocumentState({
  /// The page on screen, from 1.
  final int pageNumber = 1,

  /// How many pages there are; 0 for a document without pages, a text.
  final int pageCount = 0,

  /// What is searched for; empty while nothing is.
  final String query = '',

  /// How many matches there are: so far, while [searching].
  final int matchCount = 0,

  /// The match the document has gone to, from 1; 0 while there is none.
  final int matchNumber = 0,

  /// Whether the search is still going through the pages.
  final bool searching = false,

  /// The choices this document offers; none for a PDF.
  final List<MediaReaderToggle> toggles = const [],

  /// Whether the document can be searched. A Markdown file, laid out
  /// from its source, cannot.
  final bool searchable = true,
});

/// A document on a page. An engine that shows one sets it as the page's
/// `document`; the chrome's controls drive it.
abstract interface class MediaReaderDocument() {
  ValueListenable<MediaReaderDocumentState> get state;

  /// Goes to page [number], from 1. A document without pages stays
  /// where it is.
  Future<void> goToPage(int number);

  /// Page [number] drawn small, for a strip of pages. It fills the box it
  /// is given. A document without pages gives an empty box.
  Widget thumbnail(BuildContext context, int number);

  /// Looks for [query] through the document and goes to the first match.
  /// An empty query ends the search.
  void search(String query);

  /// Goes to the match after the one on screen, round to the first.
  Future<void> nextMatch();

  /// Goes to the match before the one on screen, round to the last.
  Future<void> previousMatch();
}
