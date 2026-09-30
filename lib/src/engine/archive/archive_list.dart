/// The list of what an archive's folder holds (MEDIA_READER_PLAN.md R6):
/// plain rows, a folder's opened in place, a file's in a reader over
/// this one.
library;

import 'package:flutter/widgets.dart';

import '../../shell/media_reader_chrome.dart';
import '../../shell/plain_widgets.dart';
import 'archive_entry.dart';

/// The rows of one folder of an archive.
class const MediaReaderArchiveList({
  required final List<MediaReaderArchiveEntry> entries,

  /// The folder shown: empty at the top, where there is no way up.
  required final String folder,
  required final MediaReaderChrome chrome,
  required final ScrollController scroll,

  /// The path of the entry being taken out, while one is.
  required final String? opening,

  /// Why an entry could not be opened, by its path.
  required final Map<String, String> failed,
  required final ValueChanged<String> onFolder,
  required final ValueChanged<MediaReaderArchiveEntry> onFile,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final up = folder.isNotEmpty;
    return ListView.builder(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(
        safe.left,
        safe.top + chrome.contentInsets.top,
        safe.right,
        safe.bottom + chrome.contentInsets.bottom,
      ),
      itemCount: entries.length + (up ? 1 : 0),
      itemBuilder: (context, index) {
        if (up && index == 0) {
          final slash = folder.lastIndexOf('/');
          return _Row(
            title: chrome.strings.up,
            detail: folder,
            chrome: chrome,
            onTap: () => onFolder(slash < 0 ? '' : folder.substring(0, slash)),
          );
        }
        final entry = entries[index - (up ? 1 : 0)];
        final strings = chrome.strings;
        if (entry.isDirectory) {
          return _Row(
            title: '${entry.name}/',
            chrome: chrome,
            onTap: () => onFolder(entry.path),
          );
        }
        final why = entry.unsupported ?? failed[entry.path];
        return _Row(
          title: entry.name,
          detail: why == null
              ? strings.size(entry.size)
              : '${strings.size(entry.size)} · $why',
          busy: opening == entry.path,
          dim: entry.unsupported != null,
          chrome: chrome,
          onTap: entry.extract == null ? null : () => onFile(entry),
        );
      },
    );
  }
}

class const _Row({
  required final String title,
  final String? detail,
  final bool busy = false,
  final bool dim = false,
  required final MediaReaderChrome chrome,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colour = chrome.foreground;
    return Semantics(
      button: onTap != null,
      label: detail == null ? title : '$title, $detail',
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: dim ? 0.5 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colour.withValues(alpha: 0.12)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15),
                            ),
                            if (detail != null)
                              Text(
                                detail!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colour.withValues(alpha: 0.7),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (busy) MediaReaderBusy(chrome: chrome),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
