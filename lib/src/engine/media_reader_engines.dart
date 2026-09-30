/// The registry (MEDIA_READER_PLAN.md §2.1): engines in order, the first
/// that can show a file wins, and the file's card is always last.
library;

import 'package:flutter/foundation.dart';

import '../item/media_reader_item.dart';
import 'audio/audio_engine.dart';
import 'media_reader_card_engine.dart';
import 'media_reader_engine.dart';
import 'pdf/pdf_engine.dart';
import 'picture/picture_engine.dart';
import 'video/video_engine.dart';

/// What the registry chose for a file: the engine, and the item it is
/// built with — the host's own, or its preview read as an item.
typedef MediaReaderShowing = ({MediaReaderEngine engine, MediaReaderItem item});

/// An ordered list of engines.
class const MediaReaderEngines(final List<MediaReaderEngine> _engines) {
  /// The package's own engines, in the order they are asked. A kind
  /// without an engine yet shows its card.
  static const MediaReaderEngines standard = MediaReaderEngines([
    MediaReaderPictureEngine(),
    MediaReaderVideoEngine(),
    MediaReaderAudioEngine(),
    MediaReaderPdfEngine(),
  ]);

  /// The file's card. It is not in the list: it is what [select] falls
  /// back to, so every file has something to show.
  static const MediaReaderEngine card = MediaReaderCardEngine();

  /// This registry with [engines] asked first: a host's own engine for a
  /// kind, or one in place of the card.
  MediaReaderEngines withFirst(List<MediaReaderEngine> engines) =>
      MediaReaderEngines([...engines, ..._engines]);

  /// What shows [item] on [platform]: the first engine that can show the
  /// file itself; failing that, the first that can show its preview;
  /// failing that, the card.
  MediaReaderShowing select(MediaReaderItem item, TargetPlatform platform) {
    final preview = item.asPreview;
    for (final shown in [item, ?preview]) {
      for (final engine in _engines) {
        if (engine.canShow(shown, platform)) {
          return (engine: engine, item: shown);
        }
      }
    }
    return (engine: card, item: item);
  }
}
