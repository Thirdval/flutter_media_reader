/// The chrome around the canvas (MEDIA_READER_PLAN.md §2.1, MR10): slots
/// the host builds, each told the item on screen and the reader's state,
/// with a plain default for each.
library;

import 'package:flutter/widgets.dart';

import '../item/media_reader_item.dart';
import '../item/media_reader_policy.dart';
import 'media_reader_document.dart';
import 'media_reader_playback.dart';
import 'media_reader_strings.dart';

/// What a chrome slot is told: the item on screen and the reader around
/// it.
class const MediaReaderState({
  required final MediaReaderItem item,

  /// The item's place among the items, from 0.
  required final int index,
  required final int count,
  required final MediaReaderPolicy policy,

  /// The engine's own status for this item, when it has one: "1 of 15",
  /// a time.
  final String? status,

  /// What plays on the page, when its engine plays something: a video,
  /// an audio file.
  final MediaReaderPlayback? playback,

  /// The document on the page, when its engine shows one: a PDF.
  final MediaReaderDocument? document,

  /// Closes the reader. Null where it cannot be closed: a pane that is
  /// always there.
  final VoidCallback? close,
}) {
  /// Whether the host lets this member export. A slot shows Share and
  /// Save only then (MR9).
  bool get canExport => policy.canExport;
}

/// Builds a chrome slot.
typedef MediaReaderSlotBuilder = Widget Function(
  BuildContext context,
  MediaReaderState state,
);

/// The reader's chrome. A slot left null shows its plain default; a
/// builder that returns an empty box leaves the slot empty.
class const MediaReaderChrome({
  /// Who shared the file, when and where. By default, its name and its
  /// place among the items.
  final MediaReaderSlotBuilder? topStart,

  /// Closing. By default, a round close button where the reader can be
  /// closed.
  final MediaReaderSlotBuilder? topEnd,

  /// The host's actions: reply, forward. Empty by default.
  final MediaReaderSlotBuilder? bottomStart,

  /// More. Empty by default.
  final MediaReaderSlotBuilder? bottomEnd,

  /// Context, above the bottom slots: "Shared in #channel". Empty by
  /// default.
  final MediaReaderSlotBuilder? contextPill,

  /// The engine's own status. By default, a pill with
  /// [MediaReaderState.status] while there is one.
  final MediaReaderSlotBuilder? status,

  /// The controls for what the page shows. For what plays
  /// ([MediaReaderState.playback]): play and pause, the scrubber, the
  /// time, speed and mute. For a document ([MediaReaderState.document]):
  /// its pages and its search. By default, a plain bar for each.
  final MediaReaderSlotBuilder? controls,

  /// The host's actions on a file's card: save, share. Empty by default,
  /// because export is only ever the host's action (MR8).
  final MediaReaderSlotBuilder? cardActions,

  /// The canvas.
  final Color background = const Color(0xFF000000),

  /// Text and glyphs on the canvas: the card, the plain defaults, and the
  /// default text style of the host's slots.
  final Color foreground = const Color(0xFFFFFFFF),

  /// What a page that scrolls keeps clear at its top and at its bottom,
  /// within the safe area: the room the chrome's slots take there. A
  /// PDF's first page starts below the top slots, and its last page can
  /// be brought above the bottom ones. The default suits the plain
  /// chrome; a host whose slots are taller says so here.
  final EdgeInsets contentInsets = const EdgeInsets.only(top: 56, bottom: 108),
  final MediaReaderStrings strings = const MediaReaderStrings(),
});
