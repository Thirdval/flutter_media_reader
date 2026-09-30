/// What the host allows (MEDIA_READER_PLAN.md §2.1, MR9): whether this
/// member may export, and where engines may keep what they fetch.
library;

import '../io/media_reader_block_memory.dart';

/// Where engines may keep what they fetch.
sealed class const MediaReaderCache() {
  /// Nowhere: every showing fetches again.
  const factory none() = MediaReaderNoCache;

  /// In memory, never on disk.
  const factory memory() = MediaReaderMemoryCache;

  /// In a directory the host owns (per account, cleared on sign-out).
  const factory directory(String path) = MediaReaderDirectoryCache;

  /// Lets go of what the [memory] cache holds for the whole app: the
  /// parts of the files it has read. A host calls it when the account
  /// changes, as it clears its directory.
  static void clearMemory() => MediaReaderBlockMemory.shared.clear();
}

/// See [MediaReaderCache.none].
final class const MediaReaderNoCache() extends MediaReaderCache;

/// See [MediaReaderCache.memory].
final class const MediaReaderMemoryCache() extends MediaReaderCache;

/// See [MediaReaderCache.directory].
final class const MediaReaderDirectoryCache(final String path)
    extends MediaReaderCache;

/// The host's policy for a reader.
///
/// The reader enforces nothing the host could not: it tells the chrome
/// whether export is allowed, so the host shows or hides Share and Save,
/// and it keeps engines from writing where the policy does not allow.
/// Copying text is not an export (MR9).
class const MediaReaderPolicy({
  /// Whether this member may take files out of the app.
  final bool canExport = true,
  final MediaReaderCache _cache = const MediaReaderCache.memory(),
}) {
  /// Where engines may keep what they fetch. With export off nothing is
  /// kept on disk: a directory the host passed reads as memory.
  MediaReaderCache get cache => switch (_cache) {
    MediaReaderDirectoryCache() when !canExport =>
      const MediaReaderCache.memory(),
    final cache => cache,
  };
}
