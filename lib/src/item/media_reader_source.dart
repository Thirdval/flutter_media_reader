/// How the reader reaches a file's bytes (MEDIA_READER_PLAN.md §2.1): a
/// remote file the host resolves, a local file, or bytes in memory.
library;

import 'dart:typed_data';

/// Where a remote file is right now: the host's answer to a resolve.
class const MediaReaderLocation(
  final Uri uri, {

  /// Sent with every request for [uri].
  final Map<String, String> headers = const {},

  /// When [uri] stops being accepted, where the host knows it. The reader
  /// asks again shortly before then, rather than only after a refusal.
  final DateTime? expiresAt,
});

/// Asks the host where a remote file is.
///
/// Called when the file is needed, and again when the last answer has
/// expired or was refused. It may throw: a [MediaReaderUnavailable] puts
/// the file's card on the page with the host's own reason; anything else
/// is the engine's to handle.
typedef MediaReaderResolve = Future<MediaReaderLocation> Function();

/// Thrown by a host's resolve when the file cannot be reached at all (no
/// access, removed, still being processed): the page shows the file's
/// card with [reason].
class const MediaReaderUnavailable(final String reason) implements Exception {
  @override
  String toString() => 'MediaReaderUnavailable: $reason';
}

/// How to reach a file's bytes.
sealed class const MediaReaderSource() {
  /// A file the host resolves to a URL and headers when it is needed, and
  /// again when that answer expires or is refused (a signed URL).
  const factory remote(MediaReaderResolve resolve) = MediaReaderRemoteSource;

  /// A file on this device.
  const factory file(String path) = MediaReaderFileSource;

  /// Bytes already in memory.
  const factory bytes(Uint8List bytes) = MediaReaderBytesSource;
}

/// See [MediaReaderSource.remote].
final class const MediaReaderRemoteSource(final MediaReaderResolve resolve)
    extends MediaReaderSource;

/// See [MediaReaderSource.file].
final class const MediaReaderFileSource(final String path)
    extends MediaReaderSource;

/// See [MediaReaderSource.bytes].
final class const MediaReaderBytesSource(final Uint8List bytes)
    extends MediaReaderSource;
