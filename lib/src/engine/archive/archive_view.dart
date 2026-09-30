/// An archive on its page (MEDIA_READER_PLAN.md R6): its folders and
/// files as a list, and a file opened in a reader over this one.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/scroll_keys.dart';
import '../../shell/show_media_reader.dart';
import 'archive_engine.dart';
import 'archive_entry.dart';
import 'archive_list.dart';
import 'archive_open.dart';

/// The archive engine's widget.
class const MediaReaderArchiveView({
  required final MediaReaderArchiveEngine engine,

  /// The archive shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderArchiveView> createState() => _MediaReaderArchiveViewState();
}

class _MediaReaderArchiveViewState() extends State<MediaReaderArchiveView> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _keys = FocusNode(debugLabel: 'MediaReaderArchiveView');
  MediaReaderOpenArchive? _archive;
  bool _started = false;

  /// The folder shown: empty at the top.
  String _folder = '';

  /// The entry being taken out, and what went wrong with entries that
  /// could not be.
  String? _opening;
  final Map<String, String> _failed = {};

  MediaReaderPage get _page => widget.page;

  @override
  void initState() {
    super.initState();
    _page.isCurrent.addListener(_onCurrent);
    if (_page.isCurrent.value) unawaited(_load());
  }

  void _onCurrent() {
    if (_page.isCurrent.value) {
      unawaited(_load());
      _takeKeyboard();
    } else if (_keys.hasFocus) {
      Focus.maybeOf(context)?.requestFocus();
    }
  }

  void _takeKeyboard() {
    if (!mounted || _archive == null) return;
    if (Focus.maybeOf(context)?.hasFocus ?? false) _keys.requestFocus();
  }

  Future<void> _load() async {
    if (_started) return;
    _started = true;
    final engine = widget.engine;
    try {
      final archive = await openMediaReaderArchive(
        item: widget.item,
        page: _page,
        fetcher: MediaReaderFetcher(engine.transport),
        blockSize: engine.blockSize,
        maxBytes: engine.maxEntryBytes,
      );
      if (!mounted) return archive.close();
      setState(() => _archive = archive);
      _page.holdsDismiss.value = true;
      _tell();
      if (_page.isCurrent.value) _takeKeyboard();
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    if (!mounted || _page.failure.value != null) return;
    final strings = _page.chrome.strings;
    _page.fail(switch (error) {
      MediaReaderUnavailable(:final reason) => reason,
      MediaReaderFetchException() => strings.unreachable,
      MediaReaderArchiveTooLarge() => strings.tooLarge,
      MediaReaderArchiveError() || FileSystemException() => strings.failed,
      _ => strings.failed,
    });
  }

  /// The status: how many files at the top, the folder's path inside.
  void _tell() {
    final archive = _archive;
    if (archive == null) return;
    _page.status.value = _folder.isEmpty
        ? _page.chrome.strings.files(archive.fileCount)
        : _folder;
  }

  void _enter(String folder) {
    setState(() => _folder = folder);
    _tell();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Takes [entry] out and opens it in a reader over this one, through
  /// the same engines, chrome and policy.
  Future<void> _open(MediaReaderArchiveEntry entry) async {
    if (_opening != null) return;
    final extract = entry.extract;
    if (extract == null) return;
    setState(() {
      _opening = entry.path;
      _failed.remove(entry.path);
    });
    final Uint8List bytes;
    try {
      bytes = await extract(widget.engine.maxEntryBytes);
    } on Object catch (error) {
      if (!mounted) return;
      final strings = _page.chrome.strings;
      setState(() {
        _opening = null;
        _failed[entry.path] = switch (error) {
          MediaReaderArchiveTooLarge() => strings.tooLarge,
          MediaReaderFetchException() => strings.unreachable,
          _ => strings.failed,
        };
      });
      return;
    }
    if (!mounted) return;
    setState(() => _opening = null);
    final item = widget.item;
    await showMediaReader(
      context,
      items: [
        MediaReaderItem(
          id: '${item.id}!${entry.path}',
          name: entry.name,
          size: bytes.length,
          source: MediaReaderSource.bytes(bytes),
          data: item.data,
        ),
      ],
      chrome: _page.chrome,
      policy: _page.policy,
      engines: _page.engines,
      onLink: _page.opensLinks ? _page.openLink : null,
    );
  }

  @override
  void dispose() {
    _page.isCurrent.removeListener(_onCurrent);
    _archive?.close();
    _scroll.dispose();
    _keys.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = _page.chrome;
    final archive = _archive;
    if (archive == null) {
      final poster = widget.item.poster;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (poster != null) ExcludeSemantics(child: poster(context)),
          if (_page.isCurrent.value)
            Center(child: MediaReaderBusy(chrome: chrome)),
        ],
      );
    }
    return Focus(
      focusNode: _keys,
      onKeyEvent: (node, event) => scrollByKey(_scroll, event),
      child: MediaReaderArchiveList(
        entries: archive.inFolder(_folder),
        folder: _folder,
        chrome: chrome,
        scroll: _scroll,
        opening: _opening,
        failed: _failed,
        onFolder: _enter,
        onFile: (entry) => unawaited(_open(entry)),
      ),
    );
  }
}
