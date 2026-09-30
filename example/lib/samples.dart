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

  /// What a server computes of a sound at upload: its peaks, and its
  /// length.
  final List<double>? peaks,
  final Duration? duration,
});

/// The voice note's name: the example also shows it inline, as a chat
/// would.
const String voiceNote = 'voice-1790232425618.m4a';

/// The voice note's peaks: a hundred, each 0..1, as a server would send
/// them.
const List<double> _voicePeaks = [
  0.13, 0.19, 0.19, 0.16, 0.07, 0.14, 0.41, 0.69, 0.92, 0.98, //
  0.97, 0.82, 0.59, 0.30, 0.09, 0.19, 0.47, 0.74, 0.95, 0.99, //
  0.95, 0.80, 0.52, 0.24, 0.07, 0.24, 0.50, 0.77, 0.96, 1.00, //
  0.94, 0.76, 0.46, 0.20, 0.09, 0.28, 0.58, 0.84, 0.98, 0.99, //
  0.90, 0.68, 0.41, 0.15, 0.12, 0.34, 0.62, 0.88, 0.97, 1.00, //
  0.87, 0.64, 0.36, 0.12, 0.15, 0.39, 0.68, 0.91, 0.97, 0.97, //
  0.84, 0.60, 0.30, 0.10, 0.19, 0.45, 0.74, 0.95, 1.00, 0.96, //
  0.79, 0.54, 0.25, 0.07, 0.23, 0.50, 0.79, 0.94, 0.99, 0.94, //
  0.75, 0.47, 0.20, 0.09, 0.28, 0.56, 0.82, 0.95, 1.00, 0.92, //
  0.70, 0.37, 0.13, 0.07, 0.17, 0.25, 0.27, 0.26, 0.19, 0.09, //
];

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
  Sample(name: 'baptism.mp4', contentType: 'video/mp4', size: 384114),
  // A WebM plays as it is on Android, Windows and Linux; on an iPhone or
  // a Mac the reader plays the MP4 a server would make of it.
  Sample(
    name: 'choir.webm',
    contentType: 'video/webm',
    size: 50786,
    preview: 'choir.mp4',
    previewType: 'video/mp4',
  ),
  // A voice note uploaded under an MPEG-4 type: its name says it is
  // audio. Its peaks and length come with it, as from a server.
  Sample(
    name: voiceNote,
    contentType: 'video/mp4',
    size: 39768,
    peaks: _voicePeaks,
    duration: Duration(seconds: 6),
  ),
  Sample(name: 'hymn.mp3', contentType: 'audio/mpeg', size: 64617),
  Sample(
    name: 'bell.wav',
    contentType: 'audio/wav',
    size: 132378,
    via: SampleVia.file,
  ),
  // An Ogg plays as it is on Android, Windows and Linux; on an iPhone or
  // a Mac the reader plays the MP3 a server would make of it.
  Sample(
    name: 'psalm.ogg',
    contentType: 'audio/ogg',
    size: 24245,
    preview: 'psalm.mp3',
    previewType: 'audio/mpeg',
  ),
  // Three hundred pages, fetched a range at a time as they are read.
  Sample(
    name: 'Rota_October.pdf',
    contentType: 'application/pdf',
    size: 1821311,
  ),
  // Protected: the reader asks the host, and the host asks for the
  // password. It is "harvest".
  Sample(name: 'Accounts_2025.pdf', contentType: 'application/pdf', size: 1406),
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
        peaks: sample.peaks,
        duration: sample.duration,
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
