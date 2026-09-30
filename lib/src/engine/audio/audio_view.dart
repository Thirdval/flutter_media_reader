/// An audio file on its page: what it is, and the file's playing handed
/// to the chrome's transport.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart' show PlayerException;

import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/transport_bar.dart' show formatPlaybackTime;
import 'audio_coordinator.dart';

/// The audio engine's widget.
class const MediaReaderAudioView({
  required final MediaReaderAudioCoordinator coordinator,

  /// The audio played: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderAudioView> createState() => _MediaReaderAudioViewState();
}

class _MediaReaderAudioViewState() extends State<MediaReaderAudioView> {
  late final MediaReaderAudioSession _session = widget.coordinator.attach(
    widget.item.id,
    source: widget.item.source,
    duration: widget.item.duration,
  );
  bool _entered = false;
  bool _resumes = false;

  MediaReaderPage get _page => widget.page;

  @override
  void initState() {
    super.initState();
    _session.failure.addListener(_onFailure);
    _page.isCurrent.addListener(_onCurrent);
    if (_page.isCurrent.value) _enter();
  }

  @override
  void didUpdateWidget(MediaReaderAudioView old) {
    super.didUpdateWidget(old);
    if (identical(old.item.source, widget.item.source)) return;
    // The host described the file again: the session takes the source as
    // it is now, and this page goes on holding it.
    widget.coordinator
      ..attach(
        widget.item.id,
        source: widget.item.source,
        duration: widget.item.duration,
      )
      ..detach(_session);
  }

  /// A neighbour asks for nothing. The file plays when its page comes on
  /// screen, stops when the page leaves, and goes on when it is back if
  /// it was playing.
  void _onCurrent() {
    if (_page.isCurrent.value) return _enter();
    _resumes = _session.state.value.playing;
    unawaited(_session.pause());
  }

  void _enter() {
    _page.playback.value = _session;
    if (!_entered || _resumes) unawaited(_session.play());
    _entered = true;
  }

  /// The player or the host gave up: the card takes the page, with why.
  /// A reason the host gave already stands.
  void _onFailure() {
    final error = _session.failure.value;
    if (error == null || _page.failure.value != null) return;
    final strings = _page.chrome.strings;
    _page.fail(switch (error) {
      MediaReaderUnavailable(:final reason) => reason,
      // The player could not open the file, or gave up on it.
      PlayerException() || PlatformException() || String() => strings.failed,
      // The host could not be asked where the file is.
      _ => strings.unreachable,
    });
  }

  @override
  void dispose() {
    _session.failure.removeListener(_onFailure);
    _page.isCurrent.removeListener(_onCurrent);
    if (identical(_page.playback.value, _session)) _page.playback.value = null;
    // The file stops with its page, unless something else shows it too:
    // a bar in the chat behind the reader.
    widget.coordinator.detach(_session);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = _page.chrome;
    final poster = widget.item.poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null) ExcludeSemantics(child: poster(context)),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _page.item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder(
                  valueListenable: _session.state,
                  builder: (context, state, _) => switch (state) {
                    _ when state.buffering => MediaReaderBusy(chrome: chrome),
                    _ => Text(
                      switch (state.duration) {
                        null => '',
                        final duration => formatPlaybackTime(duration),
                      },
                      style: TextStyle(
                        color: chrome.foreground.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
