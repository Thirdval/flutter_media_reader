/// One page of the pager: the registry's choice of engine for the file,
/// the file's card when that engine fails, and the page the engine is
/// handed, kept current.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../engine/media_reader_engines.dart';
import '../item/media_reader_item.dart';
import '../item/media_reader_policy.dart';
import '../item/media_reader_resolver.dart';
import 'media_reader_chrome.dart';
import 'media_reader_page.dart';

/// Gives the shell's keeper for [shown]'s source: null unless it is
/// remote. [preview] says whether the file's preview is what is shown.
typedef MediaReaderResolverFor = MediaReaderResolver? Function(
  MediaReaderItem shown, {
  required bool preview,
});

/// Builds the engine for [item] and owns its [MediaReaderPage].
class const MediaReaderPageHost({
  required final MediaReaderItem item,
  required final int index,
  required final int count,

  /// Whether this page is the one on screen, not a neighbour.
  required final bool current,
  required final MediaReaderPolicy policy,
  required final MediaReaderChrome chrome,
  required final MediaReaderEngines engines,
  required final ValueNotifier<bool> chromeVisible,
  required final VoidCallback? close,
  required final MediaReaderResolverFor resolverFor,

  /// The page exists. Called while building: the shell notes it without
  /// rebuilding.
  required final ValueChanged<MediaReaderPage> onAttached,

  /// The page is about to be released.
  required final ValueChanged<MediaReaderPage> onDetached,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderPageHost> createState() => _MediaReaderPageHostState();
}

class _MediaReaderPageHostState() extends State<MediaReaderPageHost> {
  late MediaReaderShowing _showing = _select();
  late final MediaReaderPageBinding _binding = MediaReaderPageBinding(
    MediaReaderPage(
      item: widget.item,
      index: widget.index,
      count: widget.count,
      policy: widget.policy,
      chrome: widget.chrome,
      current: widget.current,
      resolver: _resolver(),
      chromeVisible: widget.chromeVisible,
      close: widget.close,
    ),
  );

  MediaReaderPage get _page => _binding.page;

  MediaReaderShowing _select() =>
      widget.engines.select(widget.item, defaultTargetPlatform);

  MediaReaderResolver? _resolver() => widget.resolverFor(
    _showing.item,
    preview: !identical(_showing.item, widget.item),
  );

  /// Swaps the engine for the card, or back. An engine may fail while it
  /// builds: the swap then waits for the frame to end.
  void _onFailure() {
    final building =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (!building) return setState(() {});
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _page.failure.addListener(_onFailure);
    widget.onAttached(_page);
  }

  @override
  void didUpdateWidget(MediaReaderPageHost old) {
    super.didUpdateWidget(old);
    final showing = _select();
    // Another engine has the file now (its preview arrived, the host
    // changed the registry): what the last one failed at no longer holds.
    if (showing.engine.id != _showing.engine.id) _binding.clearFailure();
    _showing = showing;
    _binding
      ..update(
        item: widget.item,
        index: widget.index,
        count: widget.count,
        policy: widget.policy,
        chrome: widget.chrome,
        resolver: _resolver(),
        close: widget.close,
      )
      ..current = widget.current;
  }

  @override
  void dispose() {
    _page.failure.removeListener(_onFailure);
    widget.onDetached(_page);
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final failed = page.failure.value != null;
    final engine = failed ? MediaReaderEngines.card : _showing.engine;
    final shown = failed ? widget.item : _showing.item;
    return Semantics(
      container: true,
      label: widget.chrome.strings.page(
        widget.item.name,
        widget.index + 1,
        widget.count,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: page.toggleChrome,
        child: KeyedSubtree(
          key: ValueKey<String>(engine.id),
          child: engine.build(context, shown, page),
        ),
      ),
    );
  }
}
