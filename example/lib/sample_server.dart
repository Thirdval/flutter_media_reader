import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Serves the example's bundled files the way a host's CDN serves its
/// own: a signed URL that expires, byte ranges, and a refusal for what
/// is expired or unsigned. It listens on this device's loopback only, so
/// the example needs no network and no account.
class SampleServer(
  final HttpServer _server,
  final Map<String, Uint8List> _files,
) {
  static Future<SampleServer> start(Map<String, Uint8List> files) async {
    final server = SampleServer(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      files,
    );
    server._server.listen((request) => unawaited(server._answer(request)));
    return server;
  }

  static const _types = {
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'heic': 'image/heic',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'm4a': 'audio/mp4',
    'mp3': 'audio/mpeg',
    'ogg': 'audio/ogg',
    'wav': 'audio/wav',
    'pdf': 'application/pdf',
    'txt': 'text/plain; charset=utf-8',
    'md': 'text/markdown; charset=utf-8',
    'csv': 'text/csv; charset=utf-8',
    'log': 'text/plain; charset=utf-8',
    'json': 'application/json',
    'zip': 'application/zip',
    'gz': 'application/gzip',
  };

  /// How long a signed URL is good for.
  Duration validFor = const Duration(minutes: 15);

  /// How many URLs have been signed for each file: what a host's audit
  /// would count.
  final Map<String, int> signed = {};

  /// Files whose next request is refused as expired, whatever its
  /// signature says: a URL that ran out while the reader held it.
  final Set<String> expireNext = {};

  /// What was served: the file, the status, and the range asked for.
  final List<({String name, int status, String? range})> served = [];

  /// A signed URL for [name], and when it stops being accepted.
  ({Uri uri, DateTime expiresAt}) sign(String name) {
    signed.update(name, (count) => count + 1, ifAbsent: () => 1);
    final expiresAt = DateTime.now().add(validFor);
    final exp = expiresAt.millisecondsSinceEpoch;
    return (
      uri: Uri(
        scheme: 'http',
        host: _server.address.address,
        port: _server.port,
        pathSegments: ['files', name],
        queryParameters: {'exp': '$exp', 'sig': _signature(name, exp)},
      ),
      expiresAt: expiresAt,
    );
  }

  Future<void> close() => _server.close(force: true);

  /// A stand-in for a real signature: enough to tell a URL this server
  /// signed from one it did not.
  String _signature(String name, int exp) =>
      Object.hash(name, exp, _server.port).toRadixString(16);

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    final name = request.uri.pathSegments.last;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    final exp = int.tryParse(request.uri.queryParameters['exp'] ?? '');
    final file = _files[name];
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (exp == null ||
        request.uri.queryParameters['sig'] != _signature(name, exp)) {
      response.statusCode = HttpStatus.forbidden;
    } else if (expireNext.remove(name) ||
        DateTime.now().millisecondsSinceEpoch > exp) {
      response.statusCode = HttpStatus.gone;
    } else if (file == null) {
      response.statusCode = HttpStatus.notFound;
    } else {
      response.headers.set(
        HttpHeaders.contentTypeHeader,
        _types[name.split('.').last.toLowerCase()] ??
            'application/octet-stream',
      );
      _send(request, file, range);
    }
    served.add((name: name, status: response.statusCode, range: range));
    await response.close();
  }

  /// The whole of [file], or the part [range] asks for.
  void _send(HttpRequest request, Uint8List file, String? range) {
    final response = request.response;
    final head = request.method == 'HEAD';
    final bounds = range == null
        ? null
        : RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
    if (bounds == null) {
      response.contentLength = file.length;
      if (!head) response.add(file);
      return;
    }
    final first = int.tryParse(bounds.group(1)!);
    final last = int.tryParse(bounds.group(2)!);
    // "bytes=-500" is the last 500 bytes; "bytes=500-" is from 500 on.
    final start = first ?? (file.length - (last ?? 0)).clamp(0, file.length);
    final end = first == null
        ? file.length - 1
        : (last ?? file.length - 1).clamp(0, file.length - 1);
    if (start >= file.length || start > end) {
      response
        ..statusCode = HttpStatus.requestedRangeNotSatisfiable
        ..headers.set(HttpHeaders.contentRangeHeader, 'bytes */${file.length}');
      return;
    }
    response
      ..statusCode = HttpStatus.partialContent
      ..headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${file.length}',
      )
      ..contentLength = end - start + 1;
    if (!head) response.add(Uint8List.sublistView(file, start, end + 1));
  }
}
