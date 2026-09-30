/// A file as the host describes it to the reader (MEDIA_READER_PLAN.md
/// §2.1), and the derivative the host may hand in with it.
library;

import 'package:flutter/widgets.dart';

import '../media_kind.dart';
import 'media_reader_source.dart';

/// A file the host hands the reader.
class const MediaReaderItem({
  /// Stable for the file: a page, its state and its kept location follow
  /// the id when the list of items changes.
  required final String id,
  required final String name,
  final String? contentType,

  /// In bytes.
  final int? size,
  final MediaKind? _kind,

  /// How to reach the bytes.
  required final MediaReaderSource source,

  /// A derivative the host makes of a file no engine shows as it is.
  final MediaReaderPreview? preview,

  /// What a page shows until its engine has something: a blurhash, a
  /// thumbnail.
  final WidgetBuilder? poster,

  /// Waveform peaks from the host, each 0..1 (MR6).
  final List<double>? peaks,
  final Duration? duration,

  /// The host's own, handed back to its chrome slots untouched.
  final Object? data,
}) {
  /// What the file is. The host's own reading (its server's family) wins;
  /// without one, [contentType] and [name] are read by [MediaKind.of].
  MediaKind get kind =>
      _kind ?? MediaKind.of(contentType: contentType, fileName: name);
}

/// A derivative the host makes of a file the reader cannot show as it is:
/// the PDF of an Office file, the JPEG of a HEIC. It is shown by its own
/// kind's engine.
class const MediaReaderPreview({
  required final MediaReaderSource source,
  final String? contentType,

  /// The derivative's file name, where it has one.
  final String? name,
  final MediaKind? _kind,
}) {
  /// What the derivative is: the host's reading, or [contentType] and
  /// [name] read by [MediaKind.of].
  MediaKind get kind =>
      _kind ?? MediaKind.of(contentType: contentType, fileName: name);
}
