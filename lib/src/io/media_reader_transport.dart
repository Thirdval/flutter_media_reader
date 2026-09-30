/// How an engine without a plugin of its own fetches a remote file
/// (MR11): a GET with the host's headers and, for part of a large file,
/// a byte range. A host with its own HTTP stack passes its own.
library;

import 'dart:async';
import 'dart:io';

/// Bytes `start` to `end`, both included; to the end of the file when
/// `end` is null.
typedef MediaReaderRange = ({int start, int? end});

/// The answer to a GET.
class const MediaReaderResponse({
  required final int status,
  required final Stream<List<int>> body,

  /// The body's length, where the server gave it.
  final int? length,

  /// The whole file's length, from the `Content-Range` of a range
  /// response.
  final int? total,
});

/// Makes the GETs an engine asks for.
abstract interface class MediaReaderTransport() {
  /// GETs [uri] with [headers], or only [range] of it.
  Future<MediaReaderResponse> get(
    Uri uri, {
    Map<String, String> headers,
    MediaReaderRange? range,
  });
}

/// The default transport, on `dart:io`'s [HttpClient].
class const MediaReaderIoTransport() implements MediaReaderTransport {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15);

  @override
  Future<MediaReaderResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    MediaReaderRange? range,
  }) async {
    final request = await _client.getUrl(uri);
    headers.forEach(request.headers.set);
    if (range != null) {
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=${range.start}-${range.end ?? ''}',
      );
    }
    final response = await request.close();
    return MediaReaderResponse(
      status: response.statusCode,
      body: response,
      length: response.contentLength < 0 ? null : response.contentLength,
      total: _total(response.headers.value(HttpHeaders.contentRangeHeader)),
    );
  }

  /// The length after the slash of `bytes 0-99/1234`.
  static int? _total(String? contentRange) => switch (contentRange) {
    null => null,
    final value => int.tryParse(value.substring(value.lastIndexOf('/') + 1)),
  };
}
