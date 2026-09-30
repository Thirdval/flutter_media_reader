/// A file as the host describes it to the reader (MEDIA_READER_PLAN.md
/// §2.1), and the derivative the host may hand in with it.
library;

import 'package:flutter/widgets.dart';

import '../media_kind.dart';
import 'media_format.dart';
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

  /// The file's format as a short lower-case name ("jpeg", "mp4", "m4a",
  /// "pdf"): from [contentType] where it is specific, from the extension
  /// of [name] otherwise, and empty when neither says. An engine decides
  /// by it whether it shows the file on a platform.
  String get format => mediaFormatOf(contentType: contentType, fileName: name);

  /// The preview read as an item of its own: the preview's source, type
  /// and kind, under this file's id and with the rest of what the host
  /// said about the file. Null without a preview, and while the preview
  /// is not ready. It is what an engine is built with when it shows the
  /// preview.
  MediaReaderItem? get asPreview => switch (preview) {
    MediaReaderPreview(:final source?, :final name, :final contentType) =>
      MediaReaderItem(
        id: id,
        name: name ?? this.name,
        contentType: contentType,
        kind: preview!.kind,
        source: source,
        poster: poster,
        peaks: peaks,
        duration: duration,
        data: data,
      ),
    _ => null,
  };
}

/// How far the host's server has got with a derivative (R7).
enum MediaReaderPreviewState() {
  /// It is there to be shown.
  ready,

  /// It is being made: the file's card says so, and the file is shown
  /// once the host hands the reader the ready preview.
  preparing,

  /// It could not be made: the file's card says so.
  failed,
}

/// A derivative the host makes of a file the reader cannot show as it is:
/// the PDF of an Office file, the JPEG of a HEIC. It is shown by its own
/// kind's engine.
class const MediaReaderPreview({
  /// Where the derivative is; null while it is not [MediaReaderPreviewState.ready].
  final MediaReaderSource? source,
  final String? contentType,

  /// The derivative's file name, where it has one.
  final String? name,
  final MediaKind? _kind,
  final MediaReaderPreviewState state = MediaReaderPreviewState.ready,
}) {
  /// A derivative the server is still making.
  const factory preparing({String? contentType}) = _PreparingPreview;

  /// A derivative the server could not make.
  const factory failed() = _FailedPreview;

  this
    : assert(
        source != null || state != MediaReaderPreviewState.ready,
        'A ready preview has a source.',
      );

  /// What the derivative is: the host's reading, or [contentType] and
  /// [name] read by [MediaKind.of].
  MediaKind get kind =>
      _kind ?? MediaKind.of(contentType: contentType, fileName: name);
}

class const _PreparingPreview({super.contentType}) extends MediaReaderPreview {
  this : super(state: MediaReaderPreviewState.preparing);
}

class const _FailedPreview() extends MediaReaderPreview {
  this : super(state: MediaReaderPreviewState.failed);
}
