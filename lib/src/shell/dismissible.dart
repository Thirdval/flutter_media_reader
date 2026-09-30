/// Drag down to dismiss (MEDIA_READER_PLAN.md §2.1): the canvas follows
/// the finger and the reader fades with it; a long or a fast enough drag
/// dismisses, a shorter one settles back.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Moves [child] with a downward drag and reports how far it has gone.
class const MediaReaderDismissible({
  /// False while the reader cannot be dismissed, or while the page's
  /// engine owns downward drags.
  required final bool enabled,

  /// How far the drag has gone, 0..1. The shell fades its canvas and its
  /// chrome by it.
  required final ValueNotifier<double> progress,

  /// The person dismissed the reader: the host removes it.
  required final VoidCallback onDismissed,
  required final Widget child,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderDismissible> createState() => _MediaReaderDismissibleState();
}

class _MediaReaderDismissibleState()
    extends State<MediaReaderDismissible>
    with SingleTickerProviderStateMixin {
  /// The share of the height a drag must pass to dismiss.
  static const _dismissAt = 0.2;

  /// The share of the height over which the reader fades out.
  static const _fadeOver = 0.6;

  /// A downward fling at least this fast dismisses, in pixels a second.
  static const _flingSpeed = 700.0;

  /// A host that keeps the reader after a dismissal gets it back in place
  /// after this long: longer than a route takes to leave.
  static const _returnAfter = Duration(milliseconds: 400);

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(_onSettle);
  Timer? _return;
  double _extent = 1;
  double _offset = 0;
  double _settleFrom = 0;

  void _onUpdate(DragUpdateDetails details) {
    _settle.stop();
    _move(math.max(0, _offset + details.delta.dy));
  }

  void _onEnd(DragEndDetails details) {
    final fast = (details.primaryVelocity ?? 0) > _flingSpeed;
    if (_offset > _extent * _dismissAt || (fast && _offset > 0)) {
      widget.onDismissed();
      _return = Timer(_returnAfter, _settleBack);
    } else {
      _settleBack();
    }
  }

  void _settleBack() {
    if (!mounted || _offset == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) return _move(0);
    _settleFrom = _offset;
    unawaited(_settle.forward(from: 0));
  }

  void _onSettle() =>
      _move(_settleFrom * (1 - Curves.easeOut.transform(_settle.value)));

  void _move(double offset) {
    setState(() => _offset = offset);
    widget.progress.value = (offset / (_extent * _fadeOver)).clamp(0, 1);
  }

  @override
  void didUpdateWidget(MediaReaderDismissible old) {
    super.didUpdateWidget(old);
    // The engine took downward drags over in the middle of one.
    if (old.enabled && !widget.enabled && _offset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _settleBack());
    }
  }

  @override
  void dispose() {
    _return?.cancel();
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.hasBoundedHeight) {
        _extent = math.max(1, constraints.maxHeight);
      }
      final enabled = widget.enabled;
      return GestureDetector(
        supportedDevices: ScrollConfiguration.of(context).dragDevices,
        onVerticalDragUpdate: enabled ? _onUpdate : null,
        onVerticalDragEnd: enabled ? _onEnd : null,
        onVerticalDragCancel: enabled ? _settleBack : null,
        child: Transform.translate(
          offset: Offset(0, _offset),
          child: widget.child,
        ),
      );
    },
  );
}
