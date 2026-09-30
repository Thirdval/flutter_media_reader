/// The file's card (MEDIA_READER_PLAN.md §2.1): what the reader shows
/// when no engine shows a file, or when one failed. Never another app.
library;

import 'package:flutter/widgets.dart';

import '../item/media_reader_item.dart';
import '../shell/media_reader_page.dart';
import 'media_reader_engine.dart';

/// Shows any file as its card: its name, kind and size, why it is not
/// shown, and the host's actions for it.
class const MediaReaderCardEngine() implements MediaReaderEngine {
  @override
  String get id => 'card';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) => true;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => _Card(item: item, page: page);
}

class const _Card({
  required final MediaReaderItem item,
  required final MediaReaderPage page,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chrome = page.chrome;
    final strings = chrome.strings;
    final faint = TextStyle(
      color: chrome.foreground.withValues(alpha: 0.7),
      fontSize: 13,
    );
    final details = [
      strings.kind(item.kind),
      if (item.size case final size?) strings.size(size),
    ].join(' · ');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_extension(item.name) case final extension?) ...[
                ExcludeSemantics(
                  child: _Badge(extension, color: chrome.foreground),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(details, textAlign: TextAlign.center, style: faint),
              const SizedBox(height: 16),
              ValueListenableBuilder(
                valueListenable: page.failure,
                builder: (context, failure, _) => Text(
                  failure ?? strings.notShown,
                  textAlign: TextAlign.center,
                  style: faint,
                ),
              ),
              if (chrome.cardActions case final actions?) ...[
                const SizedBox(height: 24),
                actions(context, page.state),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The name's extension in capitals, where it is short enough to badge.
  static String? _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    final extension = name.substring(dot + 1);
    return RegExp(r'^[A-Za-z0-9]{1,5}$').hasMatch(extension)
        ? extension.toUpperCase()
        : null;
  }
}

class const _Badge(final String text, {required final Color color})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}
