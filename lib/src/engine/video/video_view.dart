/// A video on its page: the poster until it is on screen, then the
/// player, which stops when the page is left.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../../item/media_reader_item.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_widgets.dart';
import 'video_session.dart';

/// The video engine's widget.
class const MediaReaderVideoView({
  /// The video shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderVideoView> createState() => _MediaReaderVideoViewState();
}

class _MediaReaderVideoViewState() extends State<MediaReaderVideoView> {
  late final MediaReaderVideoSession _session = MediaReaderVideoSession(
    item: widget.item,
    page: widget.page,
  );
  bool _started = false;

  MediaReaderPage get _page => widget.page;

  @override
  void initState() {
    super.initState();
    _page.isCurrent.addListener(_onCurrent);
    if (_page.isCurrent.value) unawaited(_start());
  }

  /// A neighbour shows its poster and asks for nothing. The video is
  /// opened when its page comes on screen, stops when the page leaves,
  /// and goes on when it is back if it was playing.
  void _onCurrent() {
    if (!_page.isCurrent.value) return _started ? _session.leave() : null;
    if (_started) return _session.comeBack();
    unawaited(_start());
  }

  Future<void> _start() async {
    _started = true;
    await _session.start();
    if (mounted && _session.player.value != null) {
      _page.playback.value = _session;
    }
  }

  @override
  void dispose() {
    _page.isCurrent.removeListener(_onCurrent);
    if (identical(_page.playback.value, _session)) _page.playback.value = null;
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.item.poster;
    return ListenableBuilder(
      listenable: Listenable.merge([_session.player, _session.opening]),
      builder: (context, _) {
        final player = _session.player.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (player == null && poster != null)
              ExcludeSemantics(child: poster(context)),
            if (player != null)
              Center(
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
            // The ring turns while the video is opened, and while the
            // player waits for data. Only the ring follows the state:
            // the position ticks ten times a second.
            ValueListenableBuilder(
              valueListenable: _session.state,
              builder: (context, state, _) =>
                  _session.opening.value || state.buffering
                  ? Center(child: MediaReaderBusy(chrome: _page.chrome))
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}
