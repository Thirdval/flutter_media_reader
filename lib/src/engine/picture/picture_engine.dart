/// The picture engine (MEDIA_READER_PLAN.md R2): Flutter's own decoders
/// in an `InteractiveViewer`, decoded at the size of the screen.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../io/media_reader_transport.dart';
import '../../item/media_reader_item.dart';
import '../../media_kind.dart';
import '../../shell/media_reader_page.dart';
import '../media_reader_engine.dart';
import 'picture_view.dart';

/// Gives the host's own image provider for a picture, to reuse a cache
/// the host already has; null for the engine's own loading.
///
/// A remote picture's URL comes from `page.resolve()`. Key the provider
/// by the file, not by that URL: the URL changes with every signature.
typedef MediaReaderImageProviderBuilder = FutureOr<ImageProvider?> Function(
  MediaReaderItem item,
  MediaReaderPage page,
);

/// Shows the pictures Flutter decodes on the platform. SVG, AVIF and
/// whatever else it does not decode are left to the card.
class const MediaReaderPictureEngine({
  /// The host's provider. It is asked only while the policy allows
  /// export: a host's cache is usually on disk, and with export off
  /// nothing is kept there (MR9).
  final MediaReaderImageProviderBuilder? imageProvider,

  /// Fetches a remote picture when the host gives no provider.
  final MediaReaderTransport transport = const MediaReaderIoTransport(),

  /// The most a picture is magnified.
  final double maxScale = 8,

  /// What a double tap magnifies to.
  final double doubleTapScale = 2.5,

  /// The longest side a picture is ever decoded at, in pixels, however
  /// large the file and however far it is zoomed.
  final int maxDecodeSide = 4096,

  /// The largest file the engine fetches into memory, in bytes.
  final int maxBytes = 64 * 1024 * 1024,

  /// Whether a neighbour's picture is fetched and decoded before it is
  /// paged to, so that it is there at once. When false, a picture is
  /// asked for when its page comes on screen: fewer resolves for a host
  /// that meters them, and the poster in the meantime.
  final bool prepareNeighbours = true,
}) implements MediaReaderEngine {
  /// Decoded on every platform.
  static const Set<String> _everywhere = {
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'wbmp',
    'ico',
  };

  /// Decoded by the system on iOS and macOS. Elsewhere the host's
  /// preview (a JPEG the server makes of a HEIC) is what is shown.
  static const Set<String> _onApple = {'heic', 'tiff'};

  @override
  String get id => 'picture';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) {
    if (item.kind != MediaKind.picture) return false;
    final format = item.format;
    if (_everywhere.contains(format)) return true;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return apple && _onApple.contains(format);
  }

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => MediaReaderPictureView(engine: this, item: item, page: page);
}
