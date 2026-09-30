/// The glyphs the reader draws on its plain controls, and the hook a
/// host draws them through with its own icons instead (1.1).
library;

import 'package:flutter/widgets.dart';

/// The glyphs the reader draws itself: no icon font is assumed.
enum MediaReaderGlyph() {
  /// The transport's and the audio bar's play button.
  play,

  /// Their pause button.
  pause,

  /// The transport's mute button while the sound is on.
  sound,

  /// The same button while the sound is muted.
  muted,

  /// The document bar's search.
  search,

  /// The document bar's strip of pages.
  pages,

  /// The search's previous match.
  up,

  /// The search's next match.
  down,

  /// The end of a search, and the reader's own close button.
  close,
}

/// Draws [glyph] in the host's own icon set, [size] wide and high (24
/// on the reader's 40-pixel buttons), in [colour]. Null keeps the
/// reader's own drawing of that glyph.
typedef MediaReaderGlyphBuilder = Widget? Function(
  BuildContext context,
  MediaReaderGlyph glyph,
  Color colour,
  double size,
);
