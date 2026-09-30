import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

import 'host_chrome.dart';
import 'sample_server.dart';

/// How a sample's bytes reach the reader.
enum SampleVia() {
  /// Through a signed URL the host resolves, like a file on a CDN.
  remote,

  /// From a file on the device.
  file,

  /// From bytes already in memory.
  bytes,
}

/// A sample file as a host would describe it.
class const Sample({
  required final String name,
  required final String? contentType,

  /// The size the host states. For a bundled sample it is the real one.
  required final int size,

  /// Whether the file is bundled with the example. One that is not
  /// belongs to a kind whose engine has not arrived: it shows its card,
  /// and nothing is fetched.
  final bool bundled = true,
  final SampleVia via = SampleVia.remote,

  /// A bundled derivative, as a server would make: the JPEG of a HEIC.
  final String? preview,
  final String? previewType,
});

/// The example's files. It grows with the plan: a kind gets a bundled
/// sample when its engine arrives.
const List<Sample> samples = [
  Sample(name: 'harvest_supper.jpg', contentType: 'image/jpeg', size: 78816),
  Sample(
    name: 'hall_48_megapixels.jpg',
    contentType: 'image/jpeg',
    size: 607693,
  ),
  Sample(
    name: 'candle.gif',
    contentType: 'image/gif',
    size: 40959,
    via: SampleVia.bytes,
  ),
  Sample(
    name: 'banner.png',
    contentType: 'image/png',
    size: 2369,
    via: SampleVia.file,
  ),
  Sample(
    name: 'IMG_0042.heic',
    contentType: 'image/heic',
    size: 3343,
    preview: 'IMG_0042.jpg',
    previewType: 'image/jpeg',
  ),
  Sample(
    name: 'baptism.mp4',
    contentType: 'video/mp4',
    size: 48234496,
    bundled: false,
  ),
  Sample(
    name: 'voice-1790232425618.m4a',
    contentType: 'video/mp4',
    size: 181248,
    bundled: false,
  ),
  Sample(
    name: 'Rota_October.pdf',
    contentType: 'application/pdf',
    size: 264192,
    bundled: false,
  ),
  Sample(
    name: 'Budget 2026.xlsx',
    contentType: 'application/octet-stream',
    size: 58368,
    bundled: false,
  ),
  Sample(
    name: 'Sermon notes.txt',
    contentType: 'text/plain',
    size: 4096,
    bundled: false,
  ),
  Sample(name: 'README.md', contentType: null, size: 2048, bundled: false),
  Sample(
    name: 'attendance.csv',
    contentType: 'text/csv',
    size: 91136,
    bundled: false,
  ),
  Sample(
    name: 'photos.zip',
    contentType: 'application/zip',
    size: 104857600,
    bundled: false,
  ),
  Sample(
    name: 'model.glb',
    contentType: 'model/gltf-binary',
    size: 7340032,
    bundled: false,
  ),
];

/// The bundled samples in memory, the server that signs URLs for them,
/// and the files written for the samples that come from disk.
class SampleFiles(
  final Map<String, Uint8List> _bytes,
  final SampleServer server,
  final Directory _directory,
) {
  static Future<SampleFiles> load() async {
    final bytes = <String, Uint8List>{};
    for (final sample in samples.where((sample) => sample.bundled)) {
      for (final name in [sample.name, ?sample.preview]) {
        final data = await rootBundle.load('assets/samples/$name');
        bytes[name] = data.buffer.asUint8List();
      }
    }
    final directory = await Directory.systemTemp.createTemp('media_reader_');
    for (final sample in samples.where((s) => s.via == SampleVia.file)) {
      File('${directory.path}/${sample.name}')
          .writeAsBytesSync(bytes[sample.name]!);
    }
    return SampleFiles(bytes, await SampleServer.start(bytes), directory);
  }

  /// The samples as the reader's items. The host's own data rides along
  /// for its chrome.
  List<MediaReaderItem> get items => [
    for (final (index, sample) in samples.indexed)
      MediaReaderItem(
        id: 'file-$index',
        name: sample.name,
        contentType: sample.contentType,
        size: sample.size,
        source: _sourceOf(sample),
        preview: switch (sample.preview) {
          null => null,
          final preview => MediaReaderPreview(
            source: MediaReaderSource.remote(() => _resolve(preview)),
            contentType: sample.previewType,
            name: preview,
          ),
        },
        // What a host would show from a blurhash while the file comes.
        poster: (context) => const ColoredBox(color: Color(0xFF16302E)),
        data: const Shared(by: 'Ruth Adeyemi', where: '#harvest-supper'),
      ),
  ];

  MediaReaderSource _sourceOf(Sample sample) => switch (sample.via) {
    _ when !sample.bundled => MediaReaderSource.remote(
      () => _resolve(sample.name),
    ),
    SampleVia.remote => MediaReaderSource.remote(() => _resolve(sample.name)),
    SampleVia.file => MediaReaderSource.file(
      '${_directory.path}/${sample.name}',
    ),
    SampleVia.bytes => MediaReaderSource.bytes(_bytes[sample.name]!),
  };

  /// What a host's audited resolve answers: a signed URL that expires.
  Future<MediaReaderLocation> _resolve(String name) async {
    final signed = server.sign(name);
    return MediaReaderLocation(signed.uri, expiresAt: signed.expiresAt);
  }
}
