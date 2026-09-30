/// Fetches a page's remote file for an engine (MR11, §7 of the plan):
/// the location comes from the page, and a refused one is renewed once
/// before the fetch is given up.
library;

import 'dart:async';
import 'dart:typed_data';

import '../shell/media_reader_page.dart';
import 'media_reader_transport.dart';

/// A fetch that did not bring the file.
class const MediaReaderFetchException({
  /// The server's status; null when it was never reached.
  final int? status,

  /// What went wrong below HTTP: no network, a timeout.
  final Object? cause,
}) implements Exception {
  /// Whether the server turned the location down: expired, revoked, or
  /// never valid.
  bool get refused => MediaReaderFetcher.refuses(status);

  @override
  String toString() =>
      'MediaReaderFetchException(${status ?? cause ?? 'unreachable'})';
}

/// The file is larger than the engine will take into memory.
class const MediaReaderTooLarge(final int limit) implements Exception {
  @override
  String toString() => 'MediaReaderTooLarge(limit: $limit bytes)';
}

/// Part of a file, and the whole file's length where the server said.
typedef MediaReaderPart = ({Uint8List bytes, int? total});

/// Fetches through a [transport], at the location the page keeps.
class const MediaReaderFetcher([
  final MediaReaderTransport transport = const MediaReaderIoTransport(),
]) {
  /// Whether [status] says the location itself was turned down, so that
  /// a fresh one is worth asking for.
  static bool refuses(int? status) =>
      status == 401 || status == 403 || status == 410;

  /// The whole file.
  ///
  /// Throws a [MediaReaderFetchException] when the file does not come, a
  /// [MediaReaderTooLarge] past [limit] bytes, and whatever the host's
  /// resolve throws.
  Future<Uint8List> fetch(
    MediaReaderPage page, {
    int? limit,
    void Function(int received, int? total)? onProgress,
  }) async {
    final response = await _get(page, null);
    if (response.status != 200) {
      await _discard(response);
      throw MediaReaderFetchException(status: response.status);
    }
    return await _read(response, limit: limit, onProgress: onProgress);
  }

  /// Bytes [range] of the file. A server that ignores ranges answers
  /// with the whole file, which is then cut to the range; [onWhole] is
  /// handed all of it, for a caller that would otherwise ask again.
  Future<MediaReaderPart> fetchRange(
    MediaReaderPage page,
    MediaReaderRange range, {
    void Function(Uint8List whole)? onWhole,
  }) async {
    final response = await _get(page, range);
    if (response.status == 206) {
      return (bytes: await _read(response), total: response.total);
    }
    if (response.status == 200) {
      final whole = await _read(response);
      onWhole?.call(whole);
      final end = switch (range.end) {
        final end? when end < whole.length => end + 1,
        _ => whole.length,
      };
      final start = range.start.clamp(0, end);
      return (
        bytes: Uint8List.sublistView(whole, start, end),
        total: whole.length,
      );
    }
    await _discard(response);
    throw MediaReaderFetchException(status: response.status);
  }

  /// GETs the page's file, asking the host for a fresh location once
  /// when the kept one is refused.
  Future<MediaReaderResponse> _get(
    MediaReaderPage page,
    MediaReaderRange? range,
  ) async {
    var location = await page.resolve();
    for (var attempt = 0; ; attempt++) {
      final MediaReaderResponse response;
      try {
        response = await transport.get(
          location.uri,
          headers: location.headers,
          range: range,
        );
      } on Exception catch (cause) {
        throw MediaReaderFetchException(cause: cause);
      }
      if (!refuses(response.status) || attempt > 0) return response;
      await _discard(response);
      location = await page.renew(location);
    }
  }

  static Future<Uint8List> _read(
    MediaReaderResponse response, {
    int? limit,
    void Function(int received, int? total)? onProgress,
  }) async {
    if (limit != null && (response.length ?? 0) > limit) {
      await _discard(response);
      throw MediaReaderTooLarge(limit);
    }
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.body) {
        bytes.add(chunk);
        if (limit != null && bytes.length > limit) {
          throw MediaReaderTooLarge(limit);
        }
        onProgress?.call(bytes.length, response.length);
      }
    } on MediaReaderTooLarge {
      rethrow;
    } on Exception catch (cause) {
      throw MediaReaderFetchException(cause: cause);
    }
    return bytes.takeBytes();
  }

  /// Lets go of a body nobody will read.
  static Future<void> _discard(MediaReaderResponse response) async {
    try {
      await response.body.drain<void>();
    } on Exception {
      // The connection is gone already.
    }
  }
}
