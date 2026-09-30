/// A remote picture as an image provider: fetched at the location the
/// page keeps, and known to the image cache by the file, not by a URL
/// that changes with every signature.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../io/media_reader_fetcher.dart';
import '../../shell/media_reader_page.dart';

/// The picture behind [page]'s remote source.
final class const MediaReaderRemoteImage({
  /// What the image cache knows the picture by: the file's id, and
  /// whether it is the file's preview.
  required final String id,
  required final MediaReaderPage page,
  final MediaReaderFetcher fetcher = const MediaReaderFetcher(),

  /// The largest file taken into memory, in bytes.
  final int? limit,
}) extends ImageProvider<MediaReaderRemoteImage> {
  @override
  Future<MediaReaderRemoteImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    MediaReaderRemoteImage key,
    ImageDecoderCallback decode,
  ) {
    final chunks = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode, chunks),
      chunkEvents: chunks.stream,
      scale: 1,
      debugLabel: id,
    );
  }

  Future<ui.Codec> _load(
    MediaReaderRemoteImage key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunks,
  ) async {
    try {
      final bytes = await fetcher.fetch(
        page,
        limit: limit,
        onProgress: (received, total) => chunks.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: received,
            expectedTotalBytes: total,
          ),
        ),
      );
      return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (_) {
      // A failed load is not kept: the next try fetches again.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    } finally {
      unawaited(chunks.close());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MediaReaderRemoteImage && other.id == id;

  @override
  int get hashCode => Object.hash(MediaReaderRemoteImage, id);

  @override
  String toString() => 'MediaReaderRemoteImage($id)';
}
