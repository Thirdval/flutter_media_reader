/// Keeps a remote source's location (MEDIA_READER_PLAN.md §2.1, §7):
/// asked for once, kept until it expires or is refused, asked for again
/// then.
library;

import 'media_reader_source.dart';

/// The location of one remote source, kept between an engine's requests.
///
/// A resolve is the host's audited call, and may be metered: the keeper
/// makes it once per validity, shares it between concurrent callers, and
/// makes it again only when the kept answer has expired or was refused.
final class MediaReaderResolver(
  /// The source asked. The shell replaces it when the host rebuilds the
  /// item; the kept location stays.
  var MediaReaderRemoteSource source, {

  /// How long before its expiry a location stops being handed out: long
  /// enough for a request made with it to arrive.
  final Duration margin = const Duration(seconds: 30),
  final DateTime Function() _now = DateTime.now,
}) {
  MediaReaderLocation? _kept;
  Future<MediaReaderLocation>? _asking;

  /// The kept location while it is valid; a fresh one otherwise.
  Future<MediaReaderLocation> resolve() {
    final kept = _kept;
    if (kept != null && !_stale(kept)) return Future.value(kept);
    return _ask();
  }

  /// A fresh location, after [refused] was refused (expired early,
  /// revoked). A caller holding an older location than the kept one gets
  /// the kept one: another caller renewed it already.
  Future<MediaReaderLocation> renew(MediaReaderLocation refused) {
    final kept = _kept;
    if (kept != null && kept.uri != refused.uri && !_stale(kept)) {
      return Future.value(kept);
    }
    _kept = null;
    return _ask();
  }

  Future<MediaReaderLocation> _ask() =>
      _asking ??= _askHost().whenComplete(() => _asking = null);

  Future<MediaReaderLocation> _askHost() async =>
      _kept = await source.resolve();

  bool _stale(MediaReaderLocation location) => switch (location.expiresAt) {
    null => false,
    final expiresAt => !_now().isBefore(expiresAt.subtract(margin)),
  };
}
