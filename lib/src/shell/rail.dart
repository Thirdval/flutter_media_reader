/// The rail of files on a wide window (MEDIA_READER_PLAN.md R8): each by
/// its poster or its kind, the one on screen marked; a tap goes to it.
library;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../item/media_reader_item.dart';
import 'chrome_layer.dart';
import 'media_reader_chrome.dart';

/// The rail, at the start of the reader.
class const MediaReaderRail({
  required final List<MediaReaderItem> items,

  /// The item on screen.
  required final int index,
  required final MediaReaderChrome chrome,
  required final ValueChanged<int> onSelect,
  super.key,
}) extends StatefulWidget {
  /// The rail's width, in pixels.
  static const double width = 104;

  /// Each file's height in the rail: the tile, its name and the gap.
  static const double _extent = 96;

  @override
  State<MediaReaderRail> createState() => _MediaReaderRailState();
}

class _MediaReaderRailState() extends State<MediaReaderRail> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(atOnce: true));
  }

  @override
  void didUpdateWidget(MediaReaderRail old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _show();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the item on screen into the rail's view, as far as it has to.
  void _show({bool atOnce = false}) {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasViewportDimension) return;
    final top = widget.index * MediaReaderRail._extent;
    final bottom = top + MediaReaderRail._extent;
    final shown = position.pixels;
    final to = switch (bottom - position.viewportDimension) {
      _ when top < shown => top,
      final end when end > shown => end,
      _ => null,
    };
    if (to == null) return;
    final target = to.clamp(0.0, position.maxScrollExtent);
    if (atOnce || MediaQuery.disableAnimationsOf(context)) {
      return position.jumpTo(target);
    }
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final count = widget.items.length;
    return Semantics(
      container: true,
      label: chrome.strings.rail,
      sortKey: const OrdinalSortKey(MediaReaderOrder.rail),
      child: SizedBox(
        width: MediaReaderRail.width,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemExtent: MediaReaderRail._extent,
          itemCount: count,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            return _Tile(
              item: item,
              chrome: chrome,
              current: index == widget.index,
              label: chrome.strings.page(item.name, index + 1, count),
              onTap: () => widget.onSelect(index),
            );
          },
        ),
      ),
    );
  }
}

class const _Tile({
  required final MediaReaderItem item,
  required final MediaReaderChrome chrome,
  required final bool current,
  required final String label,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  static const double _side = 64;

  @override
  Widget build(BuildContext context) {
    final colour = chrome.foreground;
    return Semantics(
      button: true,
      selected: current,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  SizedBox.square(
                    dimension: _side,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colour.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colour.withValues(alpha: current ? 1 : 0.25),
                          width: current ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: switch (item.poster) {
                          final poster? => poster(context),
                          null => Center(
                            child: Text(
                              _extension(item.name),
                              style: TextStyle(
                                color: colour,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colour.withValues(alpha: current ? 1 : 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "PDF", "JPG": the file's extension, short and in capitals.
  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    final extension = name.substring(dot + 1).toUpperCase();
    return extension.length > 4 ? extension.substring(0, 4) : extension;
  }
}
