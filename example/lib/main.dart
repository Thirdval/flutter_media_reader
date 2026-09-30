import 'package:flutter/material.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

/// The example grows with the plan: R0 shows how sample files are read
/// as kinds; R1 opens them in the reader.
void main() => runApp(const ExampleApp());

/// Sample files as a host would describe them.
const List<({String name, String? contentType})> samples = [
  (name: 'harvest_supper.jpg', contentType: 'image/jpeg'),
  (name: 'baptism.mp4', contentType: 'video/mp4'),
  (name: 'voice-1790232425618.m4a', contentType: 'video/mp4'),
  (name: 'Rota_October.pdf', contentType: 'application/pdf'),
  (name: 'Budget 2026.xlsx', contentType: 'application/octet-stream'),
  (name: 'Sermon notes.txt', contentType: 'text/plain'),
  (name: 'README.md', contentType: null),
  (name: 'attendance.csv', contentType: 'text/csv'),
  (name: 'photos.zip', contentType: 'application/zip'),
  (name: 'model.glb', contentType: 'model/gltf-binary'),
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
    home: Scaffold(
      appBar: AppBar(title: const Text('flutter_media_reader')),
      body: ListView.builder(
        itemCount: samples.length,
        itemBuilder: (context, index) {
          final sample = samples[index];
          final kind = MediaKind.of(
            contentType: sample.contentType,
            fileName: sample.name,
          );
          return ListTile(
            title: Text(sample.name),
            subtitle: Text(sample.contentType ?? 'no content type'),
            trailing: Text(kind.name),
          );
        },
      ),
    ),
  );
}
