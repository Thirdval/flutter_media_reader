/// The reader's shell (MEDIA_READER_PLAN.md §2.1): the canvas, paging
/// between files with the neighbours prepared, dismissal, the keyboard,
/// and the chrome over it all.
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../engine/media_reader_engines.dart';
import '../item/media_reader_item.dart';
import '../item/media_reader_policy.dart';
import '../item/media_reader_resolver.dart';
import '../item/media_reader_source.dart';
import 'chrome_layer.dart';
import 'dismissible.dart';
import 'media_reader_chrome.dart';
import 'media_reader_page.dart';
import 'media_reader_playback.dart';
import 'page_host.dart';

/// The reader, as a widget: embed it in a pane, or open it as a route
/// with `showMediaReader`.
///
/// It pages sideways between [items], each shown by the engine the
/// registry picks or by the file's card. When the host rebuilds it with
/// another list of items, the file on screen stays on screen: pages
/// follow their item's id.
class const MediaReaderView({
  required final List<MediaReaderItem> items,

  /// The item shown first.
  final int initialIndex = 0,
  final MediaReaderChrome chrome = const MediaReaderChrome(),
  final MediaReaderPolicy policy = const MediaReaderPolicy(),
  final MediaReaderEngines engines = MediaReaderEngines.standard,

  /// The person dismissed the reader: a drag down, Esc, the close button.
  /// The host removes the view. Null where the reader cannot be
  /// dismissed: a pane that is always there.
  final VoidCallback? onDismissed,

  /// An item came on screen: the first one, and each one paged to. A
  /// neighbour being prepared is not on screen.
  final ValueChanged<MediaReaderItem>? onItemShown,

  /// Whether the reader takes the keyboard when it appears. A pane beside
  /// a text field leaves it false.
  final bool autofocus = true,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderView> createState() => _MediaReaderViewState();
}

class _MediaReaderViewState() extends State<MediaReaderView> {
  late int _index = _clamped(widget.initialIndex);
  late final PageController _pager = PageController(initialPage: _index)
    ..addListener(_onScroll);
  final FocusNode _focus = FocusNode(debugLabel: 'MediaReaderView');
  final ValueNotifier<bool> _chromeVisible = ValueNotifier(true);
  final ValueNotifier<double> _dismissing = ValueNotifier(0);

  /// The status of the page on screen. The chrome's slots follow it on
  /// their own: a status that ticks rebuilds nothing else.
  final ValueNotifier<String?> _status = ValueNotifier(null);

  /// What plays on the page on screen: the slots are rebuilt when it
  /// comes or goes, and the transport follows its state by itself.
  final ValueNotifier<MediaReaderPlayback?> _playback = ValueNotifier(null);
  final Map<String, MediaReaderPage> _pages = {};
  final Map<(String, bool), MediaReaderResolver> _resolvers = {};
  MediaReaderPage? _watched;

  int _clamped(int index) =>
      widget.items.isEmpty ? 0 : index.clamp(0, widget.items.length - 1);

  /// The shell's keeper for a remote source. It outlives the page, so a
  /// file paged away from and back to is not resolved again while its
  /// location is valid.
  MediaReaderResolver? _resolverFor(
    MediaReaderItem shown, {
    required bool preview,
  }) => switch (shown.source) {
    final MediaReaderRemoteSource source => _resolvers.update(
      (shown.id, preview),
      (kept) => kept..source = source,
      ifAbsent: () => MediaReaderResolver(source),
    ),
    _ => null,
  };

  void _attach(MediaReaderPage page) {
    _pages[page.item.id] = page;
    _watch();
  }

  void _detach(MediaReaderPage page) {
    if (identical(_pages[page.item.id], page)) _pages.remove(page.item.id);
    if (identical(_watched, page)) _watch();
  }

  /// Follows what the page on screen tells the shell.
  void _watch() {
    final page = widget.items.isEmpty ? null : _pages[widget.items[_index].id];
    if (identical(page, _watched)) return;
    _watched?.status.removeListener(_onStatus);
    _watched?.playback.removeListener(_onStatus);
    _watched?.holdsPaging.removeListener(_onHold);
    _watched?.holdsDismiss.removeListener(_onHold);
    _watched = page;
    page?.status.addListener(_onStatus);
    page?.playback.addListener(_onStatus);
    page?.holdsPaging.addListener(_onHold);
    page?.holdsDismiss.addListener(_onHold);
    _onStatus();
  }

  /// The page on screen has another status, or something else playing.
  void _onStatus() {
    final status = _watched?.status.value;
    final playback = _watched?.playback.value;
    _whenNotBuilding(() {
      _status.value = status;
      _playback.value = playback;
    });
  }

  void _onHold() => _whenNotBuilding(() => setState(() {}));

  /// Runs [change] now, or after the frame when an engine spoke while the
  /// reader was building.
  void _whenNotBuilding(VoidCallback change) {
    final building =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (!building) return change();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) change();
    });
  }

  void _onScroll() {
    final page = _pager.page?.round();
    if (page == null || page == _index) return;
    if (page < 0 || page >= widget.items.length) return;
    _index = page;
    _watch();
    _whenNotBuilding(() => setState(() {}));
    _announce();
    widget.onItemShown?.call(widget.items[page]);
  }

  void _announce() {
    final item = widget.items[_index];
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.chrome.strings.page(item.name, _index + 1, widget.items.length),
        Directionality.of(context),
      ),
    );
  }

  void _step(int by) {
    final to = _index + by;
    if (to < 0 || to >= widget.items.length || !_pager.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) return _pager.jumpToPage(to);
    unawaited(
      _pager.animateToPage(
        to,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.items.isEmpty) return;
    final first = widget.items[_index];
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onItemShown?.call(first);
    });
  }

  @override
  void didUpdateWidget(MediaReaderView old) {
    super.didUpdateWidget(old);
    if (identical(old.items, widget.items)) return;
    final items = widget.items;
    final ids = {for (final item in items) item.id};
    _resolvers.removeWhere((key, _) => !ids.contains(key.$1));
    // The file on screen stays on screen, wherever it is in the list now.
    final onScreen = _index < old.items.length ? old.items[_index].id : null;
    final at = items.indexWhere((item) => item.id == onScreen);
    final index = at >= 0 ? at : _clamped(_index);
    if (index != _index) {
      _index = index;
      if (_pager.hasClients && _pager.position.hasViewportDimension) {
        // Without notifying: the pager lays out at the new place in this
        // same frame, and nobody is told the page changed, because what
        // is on screen did not.
        _pager.position.correctPixels(
          index * _pager.position.viewportDimension,
        );
      }
    }
    _watch();
    if (at < 0 && items.isNotEmpty) {
      // The file on screen is gone: another took its place.
      final shown = items[_index];
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onItemShown?.call(shown);
      });
    }
  }

  @override
  void dispose() {
    _watched?.status.removeListener(_onStatus);
    _watched?.playback.removeListener(_onStatus);
    _watched?.holdsPaging.removeListener(_onHold);
    _watched?.holdsDismiss.removeListener(_onHold);
    _pager.dispose();
    _focus.dispose();
    _chromeVisible.dispose();
    _dismissing.dispose();
    _status.dispose();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final items = widget.items;
    if (items.isEmpty) {
      return ColoredBox(
        color: chrome.background,
        child: const SizedBox.expand(),
      );
    }
    final item = items[_index];
    final page = _pages[item.id];
    final close = widget.onDismissed;
    final towardsEnd = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final indexOf = {for (final (index, item) in items.indexed) item.id: index};
    assert(indexOf.length == items.length, 'Two items share an id.');
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _step(towardsEnd),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _step(-towardsEnd),
        const SingleActivator(LogicalKeyboardKey.escape): ?close,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: widget.autofocus,
        child: DefaultTextStyle(
          style: TextStyle(
            color: chrome.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ValueListenableBuilder(
                  valueListenable: _dismissing,
                  builder: (context, dismissing, _) => ColoredBox(
                    color: chrome.background.withValues(
                      alpha: chrome.background.a * (1 - dismissing),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(MediaReaderOrder.page),
                  child: MediaReaderDismissible(
                    enabled:
                        close != null && !(page?.holdsDismiss.value ?? false),
                    progress: _dismissing,
                    onDismissed: close ?? () {},
                    child: PageView.builder(
                      controller: _pager,
                      // The neighbours are built, so they can prepare; pages
                      // further off are released.
                      allowImplicitScrolling: true,
                      physics: page?.holdsPaging.value ?? false
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: items.length,
                      findChildIndexCallback: (key) =>
                          key is ValueKey<String> ? indexOf[key.value] : null,
                      itemBuilder: (context, index) => MediaReaderPageHost(
                        key: ValueKey<String>(items[index].id),
                        item: items[index],
                        index: index,
                        count: items.length,
                        current: index == _index,
                        policy: widget.policy,
                        chrome: chrome,
                        engines: widget.engines,
                        chromeVisible: _chromeVisible,
                        close: close,
                        resolverFor: _resolverFor,
                        onAttached: _attach,
                        onDetached: _detach,
                      ),
                    ),
                  ),
                ),
                MediaReaderChromeLayer(
                  visible: _chromeVisible,
                  dismissing: _dismissing,
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_status, _playback]),
                    builder: (context, _) => MediaReaderChromeSlots(
                      chrome: chrome,
                      state: MediaReaderState(
                        item: item,
                        index: _index,
                        count: items.length,
                        policy: widget.policy,
                        status: _status.value,
                        playback: _playback.value,
                        close: close,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
