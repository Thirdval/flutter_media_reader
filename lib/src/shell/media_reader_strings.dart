/// The words the reader itself draws or speaks: the file's card, the
/// plain default chrome, and what a page says when it comes on screen.
library;

import '../media_kind.dart';

/// English by default. A host passes its own through the chrome.
class const MediaReaderStrings({
  /// The close button's label.
  final String close = 'Close',

  /// An item's place among the items: "2 of 5".
  final String Function(int position, int count) position = _position,

  /// What a page says when it comes on screen.
  final String Function(String name, int position, int count) page = _page,

  /// A kind's name, on the card.
  final String Function(MediaKind kind) kind = _kind,

  /// A file's size, on the card.
  final String Function(int bytes) size = _size,

  /// On the card, when no engine shows this kind of file.
  final String notShown = 'This file cannot be shown here.',

  /// On the card, while the host's server makes what the reader shows
  /// of the file, and when it could not (R7).
  final String preparing = 'This file is being prepared.',
  final String previewFailed =
      'A copy of this file for the reader could '
      'not be made.',

  /// On the card, when an engine could not open the file it was given.
  final String failed = 'This file could not be opened.',

  /// On the card, when the file did not arrive.
  final String unreachable =
      'This file could not be reached. Check the connection.',

  /// On the card, when the file is larger than the engine takes.
  final String tooLarge = 'This file is too large to show here.',

  /// The card's button after a failure.
  final String retry = 'Try again',

  /// What a page says while its file is on the way.
  final String loading = 'Loading',

  /// The transport's buttons, and its scrubber.
  final String play = 'Play',
  final String pause = 'Pause',
  final String mute = 'Mute',
  final String unmute = 'Unmute',
  final String seek = 'Position',

  /// The speed button's label: "1.5×".
  final String Function(double speed) speed = _speed,

  /// A document's controls: its strip of pages, and its search.
  final String pages = 'Pages',
  final String search = 'Search',

  /// What the search field says while it is empty.
  final String searchHint = 'Search in this file',
  final String noMatches = 'No matches',
  final String previousMatch = 'Previous match',
  final String nextMatch = 'Next match',
  final String endSearch = 'Close search',

  /// The field a page's number is typed into, and a page by its number:
  /// "Page 3".
  final String goToPage = 'Go to page',
  final String Function(int number) pageNumber = _pageNumber,

  /// The menu over selected text.
  final String copy = 'Copy',
  final String selectAll = 'Select all',

  /// A text's choices: its long lines wrapped to the width, and a JSON,
  /// XML or Markdown file laid out rather than as it is written.
  final String wrap = 'Wrap',
  final String formatted = 'Formatted',

  /// Under a text too long to show all of: "The first 32 MB of 120 MB
  /// are shown."
  final String Function(String shown, String total) cutShort = _cutShort,

  /// A table's status: "1,234 rows".
  final String Function(int count) rows = _rows,

  /// An archive's status: "12 files"; and the row that goes up out of
  /// one of its folders.
  final String Function(int count) files = _files,
  final String up = 'Back',

  /// On the card, when a file asks for a password the host did not give.
  final String locked = 'This file is protected by a password.',
});

String _pageNumber(int number) => 'Page $number';

String _cutShort(String shown, String total) =>
    'The first $shown of $total are shown.';

String _rows(int count) => '${_grouped(count)} ${count == 1 ? 'row' : 'rows'}';

String _files(int count) =>
    '${_grouped(count)} ${count == 1 ? 'file' : 'files'}';

/// "1,234".
String _grouped(int count) {
  final digits = '$count';
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return grouped.toString();
}

String _speed(double speed) =>
    '${speed.toString().replaceFirst(RegExp(r'\.0$'), '')}×';

String _position(int position, int count) => '$position of $count';

String _page(String name, int position, int count) =>
    count > 1 ? '$name, ${_position(position, count)}' : name;

String _kind(MediaKind kind) => switch (kind) {
  MediaKind.picture => 'Picture',
  MediaKind.video => 'Video',
  MediaKind.audio => 'Audio',
  MediaKind.pdf => 'PDF',
  MediaKind.office => 'Document',
  MediaKind.text => 'Text',
  MediaKind.markdown => 'Markdown',
  MediaKind.table => 'Table',
  MediaKind.archive => 'Archive',
  MediaKind.other => 'File',
};

/// "512 B", "1.5 KB", "5 MB", "123 MB": one decimal below 100 of a unit,
/// and never a trailing ".0".
String _size(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit == 0 || value >= 100
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  return '$text ${units[unit]}';
}
