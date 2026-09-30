import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';

import 'host_chrome.dart';
import 'samples.dart';

/// The example grows with the plan. Pictures, videos, audio and PDFs
/// open in their engines, through a signed URL, a file or bytes in
/// memory; a kind whose engine has not arrived shows its card.
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
  /// The voice note the page shows inline, as a chat would.
  late final MediaReaderItem _voice = widget.files.items.firstWhere(
    (item) => item.name == voiceNote,
  );

  /// The package's engines, with the host's way to ask for a PDF's
  /// password.
  late final MediaReaderEngines _engines = MediaReaderEngines.standard
      .withFirst([MediaReaderPdfEngine(password: _askPassword)]);
  bool _canExport = true;
  bool _hostChrome = true;

  void _open(int index) => unawaited(
    showMediaReader(
      context,
      items: widget.files.items,
      // A preview the server finishes while the reader is open comes
      // through: the file's card gives way to it.
      liveItems: widget.files.live,
      initialIndex: index,
      policy: MediaReaderPolicy(canExport: _canExport),
      chrome: _hostChrome ? hostChrome : const MediaReaderChrome(),
      engines: _engines,
      onLink: _onLink,
    ),
  );

  /// A link in a file is the host's to open, or not. This host shows it.
  void _onLink(Uri link) => unawaited(
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A link in the file'),
        content: Text(
          '$link\n\nThe reader opens nothing itself: it hands the link to '
          'the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );

  /// Asks for the password of a protected PDF, again while it is wrong.
  Future<String?> _askPassword(MediaReaderItem item, int attempt) =>
      showDialog<String>(
        context: context,
        builder: (context) =>
            _PasswordDialog(name: item.name, again: attempt > 0),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('flutter_media_reader')),
    body: Column(
      children: [
        _VoiceBubble(note: _voice),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Members can save and share files'),
                subtitle: const Text(
                  'The policy the host passes to the reader',
                ),
                value: _canExport,
                onChanged: (value) => setState(() => _canExport = value),
              ),
              SwitchListTile(
                title: const Text("The host's chrome"),
                subtitle: const Text('Off: the plain defaults of the package'),
                value: _hostChrome,
                onChanged: (value) => setState(() => _hostChrome = value),
              ),
              SwitchListTile(
                title: const Text(
                  'The server has made the PDF of '
                  'Minutes.docx',
                ),
                subtitle: const Text(
                  'Off: the file is being prepared. Turn it on while '
                  'the reader shows the file.',
                ),
                value: widget.files.serverDone,
                onChanged: (value) =>
                    setState(() => widget.files.serverDone = value),
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
        ),
      ],
    ),
  );
}

/// The host's own dialog for a protected file's password.
class const _PasswordDialog({
  required final String name,

  /// Whether the last password did not open the file.
  required final bool again,
}) extends StatefulWidget {
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState() extends State<_PasswordDialog> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.name),
    content: TextField(
      controller: _password,
      autofocus: true,
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'Password',
        errorText: widget.again ? 'That password did not open it.' : null,
      ),
      onSubmitted: (password) => Navigator.of(context).pop(password),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_password.text),
        child: const Text('Open'),
      ),
    ],
  );
}

/// A voice note where it stands in a chat, in its bubble. It shares the
/// app's one player with the reader: play it here, open the same file
/// below, and either place's controls drive it.
class const _VoiceBubble({required final MediaReaderItem note})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A voice note, as a chat shows it',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: MediaReaderAudioBar(
                  item: note,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
