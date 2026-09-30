import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

import 'host_chrome.dart';
import 'samples.dart';

/// The example grows with the plan. The pictures open in the picture
/// engine, through a signed URL, a file and bytes in memory; a kind
/// whose engine has not arrived shows its card.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ExampleApp(files: await SampleFiles.load()));
}

class const ExampleApp({required final SampleFiles files, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_media_reader',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1F5F5B)),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF1F5F5B),
      brightness: Brightness.dark,
    ),
    home: SamplesPage(files: files),
  );
}

/// The sample files, and what a host decides before it opens the reader.
class const SamplesPage({required final SampleFiles files, super.key})
    extends StatefulWidget {
  @override
  State<SamplesPage> createState() => _SamplesPageState();
}

class _SamplesPageState() extends State<SamplesPage> {
  bool _canExport = true;
  bool _hostChrome = true;

  void _open(int index) => unawaited(
    showMediaReader(
      context,
      items: widget.files.items,
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
            subtitle: Text(
              [
                sample.contentType ?? 'no content type',
                if (sample.bundled) sample.via.name,
              ].join(' · '),
            ),
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
