/// The search through a PDF (MEDIA_READER_PLAN.md R5, R8): `pdfrx`'s
/// searcher, going to a match the reader's way: clear of the chrome, and
/// without a glide where the person has asked for less motion.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

/// `pdfrx`'s searcher over the viewer, with the reader's way to a match.
final class MediaReaderPdfSearcher(
  super.controller, {

  /// The room the chrome takes at the top and at the bottom of the
  /// view, in pixels.
  required final EdgeInsets Function() _insets,

  /// Whether the person has asked for less motion.
  required final bool Function() _reduceMotion,
}) extends PdfTextSearcher {
  /// What is kept clear around a match gone to.
  static const double _room = 24;

  static const Color _matchColour = Color(0x7FFFEB3B);
  static const Color _activeColour = Color(0x7FFF9800);

  /// The match comes into view between the chrome's top and bottom
  /// slots. The searcher's own way puts it anywhere in the view, under
  /// the slots as often as not.
  @override
  Future<void> goToMatch(PdfPageTextRange match) async {
    final controller = this.controller;
    if (controller == null || !controller.isReady) return;
    final rect = controller.calcRectForRectInsidePage(
      pageNumber: match.pageNumber,
      rect: match.bounds,
    );
    final insets = _insets();
    final matrix = controller.calcMatrixToEnsureRectVisible(
      rect,
      margin: _room,
    );
    final shown = MatrixUtils.transformRect(matrix, rect);
    final under = insets.top + _room - shown.top;
    final over =
        shown.bottom + _room - (controller.viewSize.height - insets.bottom);
    // Under the top slots the view moves down; under the bottom ones, up.
    // A match too tall for the room between goes to the top.
    final by = under > 0 ? under : (over > 0 ? -math.min(over, -under) : 0.0);
    await controller.goTo(
      Matrix4.translationValues(0, by, 0).multiplied(matrix),
      duration: _reduceMotion()
          ? Duration.zero
          : const Duration(milliseconds: 200),
    );
    controller.setCurrentPageNumber(match.pageNumber);
    controller.invalidate();
  }

  /// Marks the matches on a page, the one gone to in its own colour: for
  /// the viewer's paint callbacks.
  void paint(Canvas canvas, Rect pageRect, PdfPage page) {
    final range = getMatchesRangeForPage(page.pageNumber);
    if (range == null) return;
    final params = controller?.params;
    final colour = params?.matchTextColor ?? _matchColour;
    final active = params?.activeMatchTextColor ?? _activeColour;
    final current = currentIndex;
    for (var i = range.start; i < range.end; i++) {
      canvas.drawRect(
        matches[i].bounds.toRectInDocument(page: page, pageRect: pageRect),
        Paint()..color = i == current ? active : colour,
      );
    }
  }
}
