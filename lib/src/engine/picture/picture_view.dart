/// A picture on its page: loaded, decoded at the size of the screen, and
/// zoomed by pinch, double tap and wheel, without fighting the shell's
/// paging and dismissal.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_policy.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_widgets.dart';
import 'picture_engine.dart';
import 'remote_image.dart';

/// The picture engine's widget.
class const MediaReaderPictureView({
  required final MediaReaderPictureEngine engine,

  /// The picture shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderPictureView> createState() => _MediaReaderPictureViewState();
}

class _MediaReaderPictureViewState()
    extends State<MediaReaderPictureView>
    with SingleTickerProviderStateMixin {
  /// Above this, the picture counts as zoomed: the engine owns drags.
  static const _restScale = 1.01;

  /// Above this, the picture is decoded again with more detail.
  static const _detailScale = 1.2;

  final TransformationController _transform = TransformationController();
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_onGlide);
  Matrix4Tween? _gliding;

  /// The picture as it is loaded, before it is sized for the screen.
  ImageProvider? _picture;

  /// How many screens' worth of pixels the picture is decoded at: 1 at
  /// rest, more once it has been zoomed into.
  double _detail = 1;
  bool _preparing = false;
  bool _shown = false;
  bool _zoomed = false;
  int _pointers = 0;
  Offset _doubleTapAt = Offset.zero;
  ImageProvider? _sized;

  MediaReaderPage get _page => widget.page;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _page.isCurrent.addListener(_onCurrent);
    if (widget.engine.prepareNeighbours || _page.isCurrent.value) {
      unawaited(_prepare());
    }
  }

  /// Settles where the picture comes from: the host's provider where the
  /// policy lets it be asked, the source otherwise.
  Future<void> _prepare() async {
    if (_preparing) return;
    _preparing = true;
    final item = widget.item;
    ImageProvider? picture;
    final hosts = widget.engine.imageProvider;
    if (hosts != null && _page.policy.canExport) {
      try {
        picture = await hosts(item, _page);
      } on Object catch (error) {
        return _fail(error);
      }
    }
    picture ??= switch (item.source) {
      MediaReaderBytesSource(:final bytes) => MemoryImage(bytes),
      MediaReaderFileSource(:final path) => FileImage(File(path)),
      MediaReaderRemoteSource() => MediaReaderRemoteImage(
        // The preview of a file is another picture than the file.
        id: identical(item, _page.item) ? item.id : '${item.id}#preview',
        page: _page,
        fetcher: MediaReaderFetcher(widget.engine.transport),
        limit: widget.engine.maxBytes,
      ),
    };
    if (mounted) setState(() => _picture = picture);
  }

  /// Puts the card on the page, with why. A reason the host gave already
  /// (the file is unavailable) stands.
  void _fail(Object error) {
    if (!mounted || _page.failure.value != null) return;
    final strings = _page.chrome.strings;
    _page.fail(switch (error) {
      MediaReaderUnavailable(:final reason) => reason,
      MediaReaderTooLarge() => strings.tooLarge,
      MediaReaderFetchException() => strings.unreachable,
      _ => strings.failed,
    });
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > _restScale;
    _hold(zoomed || _pointers > 1);
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  /// While the picture is zoomed, or two fingers are on it, drags are the
  /// engine's: the shell neither pages nor dismisses.
  void _hold(bool held) {
    _page.holdsPaging.value = held;
    _page.holdsDismiss.value = held;
  }

  /// A picture left unprepared is asked for once its page is on screen;
  /// the zoom does not outlive the page being there.
  void _onCurrent() {
    if (_page.isCurrent.value) return unawaited(_prepare());
    _glide.stop();
    _transform.value = Matrix4.identity();
    if (_detail != 1) setState(() => _detail = 1);
  }

  void _onPointer(int change) {
    _pointers = math.max(0, _pointers + change);
    _hold(_zoomed || _pointers > 1);
  }

  void _onDoubleTap() {
    final size = context.size;
    if (size == null) return;
    final scale = widget.engine.doubleTapScale;
    // The point tapped stays under the finger, as far as the edges let it.
    final zoomedIn = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (-_doubleTapAt.dx * (scale - 1)).clamp(-size.width * (scale - 1), 0),
        (-_doubleTapAt.dy * (scale - 1)).clamp(-size.height * (scale - 1), 0),
        0,
      );
    _glideTo(_zoomed ? Matrix4.identity() : zoomedIn);
  }

  void _glideTo(Matrix4 target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _transform.value = target;
      return _sharpen();
    }
    _gliding = Matrix4Tween(begin: _transform.value.clone(), end: target);
    unawaited(_glide.forward(from: 0).whenComplete(_sharpen));
  }

  void _onGlide() {
    final gliding = _gliding;
    if (gliding == null) return;
    _transform.value = gliding.transform(
      Curves.easeOutCubic.transform(_glide.value),
    );
  }

  /// Once zoomed into, the picture is decoded again with the detail the
  /// zoom shows, up to the engine's cap. It is not decoded down again
  /// while the page is on screen.
  void _sharpen() {
    if (!mounted) return;
    final scale = _transform.value.getMaxScaleOnAxis();
    if (scale <= _detailScale) return;
    final detail = math.max(_detail, scale.ceilToDouble());
    if (detail != _detail) setState(() => _detail = detail);
  }

  /// [picture] decoded to fit [screen] at the current detail, with the
  /// longest side under the engine's cap. It is never decoded larger
  /// than the file is.
  ImageProvider _sizedFor(ImageProvider picture, Size screen, double ratio) {
    var width = screen.width * ratio * _detail;
    var height = screen.height * ratio * _detail;
    final over = math.max(width, height) / widget.engine.maxDecodeSide;
    if (over > 1) {
      width /= over;
      height /= over;
    }
    return ResizeImage(
      picture,
      width: math.max(1, width.round()),
      height: math.max(1, height.round()),
      policy: ResizeImagePolicy.fit,
    );
  }

  /// At rest, a finger's drag must never be the viewer's: it is the
  /// shell's, to page or to dismiss. The viewer's recognizer is the
  /// deeper one, so it would win any drag that crosses both slops in one
  /// event, which a quick flick does on a phone. With a pan slop no drag
  /// reaches, it takes a pinch (judged by the change of span) and nothing
  /// else.
  static MediaQueryData _atRest(BuildContext context) => MediaQuery.of(context)
      .copyWith(gestureSettings: const DeviceGestureSettings(touchSlop: 1e6));

  @override
  void dispose() {
    _page.isCurrent.removeListener(_onCurrent);
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    _glide.dispose();
    // With no cache allowed, the decoded picture goes with the page.
    if (_page.policy.cache is MediaReaderNoCache) unawaited(_sized?.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picture = _picture;
    final poster = widget.item.poster;
    final waiting = Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null) ExcludeSemantics(child: poster(context)),
        Center(child: MediaReaderBusy(chrome: _page.chrome)),
      ],
    );
    if (picture == null) return waiting;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sized = _sized = _sizedFor(
          picture,
          constraints.biggest,
          MediaQuery.devicePixelRatioOf(context),
        );
        return Listener(
          onPointerDown: (_) => _onPointer(1),
          onPointerUp: (_) => _onPointer(-1),
          onPointerCancel: (_) => _onPointer(-1),
          child: GestureDetector(
            onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
            onDoubleTap: _onDoubleTap,
            child: MediaQuery(
              data: _zoomed ? MediaQuery.of(context) : _atRest(context),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: widget.engine.maxScale,
                // At rest a drag is the shell's: to page, or to dismiss.
                panEnabled: _zoomed,
                onInteractionEnd: (_) => _sharpen(),
                child: SizedBox.expand(
                  child: Image(
                    image: sized,
                    fit: BoxFit.contain,
                    // The picture stays while it is decoded with more
                    // detail.
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    frameBuilder: (context, child, frame, _) {
                      _shown = _shown || frame != null;
                      return _shown ? child : waiting;
                    },
                    errorBuilder: (context, error, _) {
                      _fail(error);
                      return const SizedBox.expand();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
