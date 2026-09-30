/// An engine's page in the reader: what the shell tells the engine, and
/// what the engine tells the shell (MEDIA_READER_PLAN.md §2.2).
library;

import 'package:flutter/foundation.dart';

import '../item/media_reader_item.dart';
import '../item/media_reader_policy.dart';
import '../item/media_reader_resolver.dart';
import '../item/media_reader_source.dart';
import 'media_reader_chrome.dart';

/// One page of the reader, as its engine sees it.
///
/// The shell makes one per page and keeps it current. An engine under
/// test makes its own: the defaults describe a lone page on screen.
final class MediaReaderPage({
  required MediaReaderItem item,
  int index = 0,
  int count = 1,
  MediaReaderPolicy policy = const MediaReaderPolicy(),
  MediaReaderChrome chrome = const MediaReaderChrome(),
  bool current = true,
  MediaReaderResolver? resolver,
  ValueNotifier<bool>? chromeVisible,
  VoidCallback? close,
}) {
  MediaReaderItem _item = item;
  int _index = index;
  int _count = count;
  MediaReaderPolicy _policy = policy;
  MediaReaderChrome _chrome = chrome;
  VoidCallback? _close = close;
  MediaReaderResolver? _resolver =
      resolver ??
      switch (item.source) {
        final MediaReaderRemoteSource source => MediaReaderResolver(source),
        _ => null,
      };
  final ValueNotifier<bool> _current = ValueNotifier(current);
  final ValueNotifier<bool> _chromeVisible =
      chromeVisible ?? ValueNotifier(true);
  final bool _ownsChromeVisible = chromeVisible == null;
  final ValueNotifier<String?> _failure = ValueNotifier(null);
  bool _disposed = false;

  /// The engine's own status for the chrome: "1 of 15", a time. Null for
  /// none.
  final ValueNotifier<String?> status = ValueNotifier(null);

  /// True while the engine owns sideways drags (a zoomed picture being
  /// panned): the shell stops paging on a drag.
  final ValueNotifier<bool> holdsPaging = ValueNotifier(false);

  /// True while the engine owns downward drags (zoomed, or scrolled away
  /// from its top): the shell stops dismissing on a drag.
  final ValueNotifier<bool> holdsDismiss = ValueNotifier(false);

  /// The item the host handed in. When its preview is shown, the item an
  /// engine is built with is the preview's; this is still the host's.
  MediaReaderItem get item => _item;

  /// The item's place among the items, from 0.
  int get index => _index;
  int get count => _count;
  MediaReaderPolicy get policy => _policy;

  /// The chrome around the page: its colours and strings, for an engine
  /// that draws text of its own.
  MediaReaderChrome get chrome => _chrome;

  /// Whether this page is the one on screen, not a neighbour being
  /// prepared. An engine plays only while it is.
  ValueListenable<bool> get isCurrent => _current;

  /// Whether the chrome is showing. An engine's own controls follow it.
  ValueListenable<bool> get chromeVisible => _chromeVisible;

  /// Why the page shows the file's card in place of its engine; null
  /// while the engine shows the file.
  ValueListenable<String?> get failure => _failure;

  /// What a chrome slot is told about this page.
  MediaReaderState get state => MediaReaderState(
    item: _item,
    index: _index,
    count: _count,
    policy: _policy,
    status: status.value,
    close: _close,
  );

  /// Hides the chrome, or brings it back: a tap on the canvas. An engine
  /// that takes taps itself calls this where a tap means the same.
  void toggleChrome() {
    if (!_disposed) _chromeVisible.value = !_chromeVisible.value;
  }

  /// Puts the file's card on the page with [reason]: the engine cannot
  /// show the file.
  void fail(String reason) {
    if (!_disposed) _failure.value = reason;
  }

  /// Where the shown file is, for a remote source: the kept location
  /// while it is valid, a fresh one otherwise.
  ///
  /// A host's [MediaReaderUnavailable] puts the card on the page and is
  /// thrown on; anything else the host throws is the engine's to handle.
  Future<MediaReaderLocation> resolve() =>
      _located((resolver) => resolver.resolve());

  /// A fresh location after [refused] was refused: an expired or revoked
  /// URL. Fails as [resolve] does.
  Future<MediaReaderLocation> renew(MediaReaderLocation refused) =>
      _located((resolver) => resolver.renew(refused));

  Future<MediaReaderLocation> _located(
    Future<MediaReaderLocation> Function(MediaReaderResolver resolver) ask,
  ) async {
    final resolver = _resolver;
    if (resolver == null) {
      throw StateError('The page shows a source that is not remote.');
    }
    try {
      return await ask(resolver);
    } on MediaReaderUnavailable catch (unavailable) {
      fail(unavailable.reason);
      rethrow;
    }
  }

  /// Releases the page. The shell calls it for its pages; a test calls it
  /// for one it made.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    status.dispose();
    holdsPaging.dispose();
    holdsDismiss.dispose();
    _current.dispose();
    _failure.dispose();
    if (_ownsChromeVisible) _chromeVisible.dispose();
  }
}

/// The shell's side of a page: what it keeps current for the engine.
/// Engines are handed the [page] alone.
final class const MediaReaderPageBinding(final MediaReaderPage page) {
  /// Brings the page up to date with the shell.
  void update({
    required MediaReaderItem item,
    required int index,
    required int count,
    required MediaReaderPolicy policy,
    required MediaReaderChrome chrome,
    required MediaReaderResolver? resolver,
    required VoidCallback? close,
  }) {
    page
      .._item = item
      .._index = index
      .._count = count
      .._policy = policy
      .._chrome = chrome
      .._resolver = resolver
      .._close = close;
  }

  /// Whether the page is the one on screen.
  set current(bool value) {
    if (!page._disposed) page._current.value = value;
  }

  /// Lets the engine try again: the card gives way to it.
  void clearFailure() {
    if (!page._disposed) page._failure.value = null;
  }
}
