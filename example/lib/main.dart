import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

import 'host_chrome.dart';

/// The example grows with the plan. R1 opens the sample files in the
/// reader: no engine exists before R2, so every kind shows its card, and
/// the sources are fakes that nothing fetches yet.
void main() => runApp(const ExampleApp());

/// Sample files as a host would describe them.
const List<({String name, String? contentType, int size})> samples = [
  (name: 'harvest_supper.jpg', contentType: 'image/jpeg', size: 3418112),
  (name: 'baptism.mp4', contentType: 'video/mp4', size: 48234496),
  (name: 'voice-1790232425618.m4a', contentType: 'video/mp4', size: 181248),
  (name: 'Rota_October.pdf', contentType: 'application/pdf', size: 264192),
  (
    name: 'Budget 2026.xlsx',
    contentType: 'application/octet-stream',
    size: 58368,
  ),
  (name: 'Sermon notes.txt', contentType: 'text/plain', size: 4096),
  (name: 'README.md', contentType: null, size: 2048),
  (name: 'attendance.csv', contentType: 'text/csv', size: 91136),
  (name: 'photos.zip', contentType: 'application/zip', size: 104857600),
  (name: 'model.glb', contentType: 'model/gltf-binary', size: 7340032),
];

class const ExampleApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_media_reader',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1F5F5B)),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF1F5F5B),
      brightness: Brightness.dark,
    ),
    home: const SamplesPage(),
  );
}

/// The sample files, and what a host decides before it opens the reader.
class const SamplesPage({super.key}) extends StatefulWidget {
  @override
  State<SamplesPage> createState() => _SamplesPageState();
}

class _SamplesPageState() extends State<SamplesPage> {
  bool _canExport = true;
  bool _hostChrome = true;

  /// The samples as the reader's items. The host's own data rides along
  /// for its chrome.
  List<MediaReaderItem> get _items => [
    for (final (index, sample) in samples.indexed)
      MediaReaderItem(
        id: 'file-$index',
        name: sample.name,
        contentType: sample.contentType,
        size: sample.size,
        source: MediaReaderSource.remote(() => _resolve(sample.name)),
        data: const Shared(by: 'Ruth Adeyemi', where: '#harvest-supper'),
      ),
  ];

  /// What a host's audited resolve answers: a signed URL that expires.
  static Future<MediaReaderLocation> _resolve(String name) async =>
      MediaReaderLocation(
        Uri.https('files.example', '/$name', {'sig': 'fake'}),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

  void _open(int index) => unawaited(
    showMediaReader(
      context,
      items: _items,
      initialIndex: index,
      policy: MediaReaderPolicy(canExport: _canExport),
      chrome: _hostChrome ? hostChrome : const MediaReaderChrome(),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('flutter_media_reader')),
    body: ListView(
      children: [
        SwitchListTile(
          title: const Text('Members can save and share files'),
          subtitle: const Text('The policy the host passes to the reader'),
          value: _canExport,
          onChanged: (value) => setState(() => _canExport = value),
        ),
        SwitchListTile(
          title: const Text("The host's chrome"),
          subtitle: const Text('Off: the plain defaults of the package'),
          value: _hostChrome,
          onChanged: (value) => setState(() => _hostChrome = value),
        ),
        const Divider(),
        for (final (index, sample) in samples.indexed)
          ListTile(
            title: Text(sample.name),
            subtitle: Text(sample.contentType ?? 'no content type'),
            trailing: Text(
              MediaKind.of(
                contentType: sample.contentType,
                fileName: sample.name,
              ).name,
            ),
            onTap: () => _open(index),
          ),
      ],
    ),
  );
}
