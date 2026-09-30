/// A PDF on its page (MEDIA_READER_PLAN.md R5): the poster until it is
/// on screen, then `pdfrx`'s viewer with the reader's own gestures, menu
/// and links around it.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../io/media_reader_blocks.dart';
import '../../io/media_reader_fetcher.dart';
import '../../item/media_reader_item.dart';
import '../../item/media_reader_source.dart';
import '../../shell/media_reader_page.dart';
import '../../shell/plain_widgets.dart';
import '../../shell/text_menu.dart';
import 'pdf_document.dart';
import 'pdf_engine.dart';
import 'pdf_source.dart';

/// The PDF engine's widget.
class const MediaReaderPdfView({
  required final MediaReaderPdfEngine engine,

  /// The PDF shown: the host's item, or its preview as an item.
  required final MediaReaderItem item,
  required final MediaReaderPage page,
  super.key,
}) extends StatefulWidget {
  @override
  State<MediaReaderPdfView> createState() => _MediaReaderPdfViewState();
}

class _MediaReaderPdfViewState() extends State<MediaReaderPdfView> {
  /// What marks a link on the page.
  static const _linkColour = Color(0x332979FF);

  final PdfViewerController _controller = PdfViewerController();
  PdfDocument? _document;
  PdfDocumentRef? _ref;
  MediaReaderBlockReader? _reader;
  MediaReaderPdfDocument? _handle;
  bool _opening = false;

  /// The view's width, and what the pages keep clear at the top and the
  /// bottom, all in pixels: set as the view is built.
  double _viewWidth = 0;
  double _topInset = 0;
  double _bottomInset = 0;

  MediaReaderPage get _page => widget.page;

  @override
  void initState() {
    super.initState();
    _page.isCurrent.addListener(_onCurrent);
    _controller.addListener(_onView);
    if (_page.isCurrent.value) unawaited(_open());
  }

  /// A neighbour asks for nothing. The PDF is opened when its page comes
  /// on screen, and stays open while the page is kept.
  void _onCurrent() {
    if (_page.isCurrent.value) {
      unawaited(_open());
      _takeKeyboard();
    } else if (_controller.isReady) {
      // The keys go back to the reader: the arrows page between files.
      Focus.maybeOf(context)?.requestFocus();
    }
  }

  Future<void> _open() async {
    if (_opening || _document != null) return;
    _opening = true;
    try {
      final opened = await openMediaReaderPdf(
        item: widget.item,
        page: _page,
        engine: widget.engine,
        onReadFailure: _fail,
      );
      if (!mounted) {
        unawaited(opened.document.dispose());
        return opened.reader?.close();
      }
      setState(() {
        _document = opened.document;
        _reader = opened.reader;
        _ref = PdfDocumentRefDirect(
          opened.document,
          autoDispose: false,
          key: PdfDocumentRefKey(opened.document.sourceName),
        );
      });
      // The pages scroll up and down: a drag down is theirs.
      _page.holdsDismiss.value = true;
    } on Object catch (error) {
      _fail(error);
    } finally {
      _opening = false;
    }
  }

  /// The card takes the page, with why. A reason the host gave already
  /// stands.
  void _fail(Object error) {
    if (!mounted || _page.failure.value != null) return;
    final strings = _page.chrome.strings;
    _page.fail(switch (error) {
      MediaReaderUnavailable(:final reason) => reason,
      MediaReaderFetchException() => strings.unreachable,
      PdfPasswordException() => strings.locked,
      _ => strings.failed,
    });
  }

  void _onReady(PdfDocument document, PdfViewerController controller) {
    if (!mounted) return;
    _handle?.dispose();
    final handle = _handle = MediaReaderPdfDocument(
      document,
      controller,
      topInset: () => _topInset,
    );
    _page.document.value = handle;
    handle.start();
    _onPage(controller.pageNumber);
    _onView();
    if (_page.isCurrent.value) _takeKeyboard();
  }

  void _onPage(int? number) {
    if (!mounted || !_controller.isReady || number == null) return;
    _handle?.onPage(number);
    _page.status.value = _page.chrome.strings.position(
      number,
      _controller.pageCount,
    );
  }

  /// The pages one under the other, as the viewer lays them out itself,
  /// with room at the top and at the bottom for the chrome: the first
  /// page starts below the top slots, and the last can be brought above
  /// the bottom ones.
  PdfPageLayout _layoutPages(List<PdfPage> pages, PdfViewerParams params) {
    final width =
        pages.fold(0.0, (width, page) => math.max(width, page.width)) +
        params.margin * 2;
    // The room is in pixels; the layout is in the document's points, which
    // the view's width shows at the size that fits it.
    final perPixel = _viewWidth > 0 ? width / _viewWidth : 1.0;
    var y = params.margin + _topInset * perPixel;
    final rects = <Rect>[];
    for (final page in pages) {
      rects.add(
        Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height),
      );
      y += page.height + params.margin;
    }
    return PdfPageLayout(
      pageLayouts: rects,
      documentSize: Size(width, y + _bottomInset * perPixel),
    );
  }

  /// Magnified past its width, the page takes sideways drags; at its
  /// width they go between files.
  void _onView() {
    if (!mounted || !_controller.isReady) return;
    final width = _controller.documentSize.width * _controller.currentZoom;
    _page.holdsPaging.value = width > _controller.viewSize.width + 1;
  }

  /// The viewer takes the keys (Page Down, the arrows, copy) while the
  /// reader has them, never from a field beside the reader.
  void _takeKeyboard() {
    if (!_controller.isReady) return;
    if (Focus.maybeOf(context)?.hasFocus ?? false) _controller.requestFocus();
  }

  /// A tap on the bare page hides the chrome or brings it back, a double
  /// tap magnifies and goes back. The rest is the viewer's: a tap lets
  /// go of selected text, a long press selects a word.
  bool _onTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    switch (details.type) {
      case PdfViewerGeneralTapType.tap:
        if (controller.textSelectionDelegate.hasSelectedText) return false;
        _page.toggleChrome();
        return true;
      case PdfViewerGeneralTapType.doubleTap:
        final fit = controller.viewSize.width / controller.documentSize.width;
        final magnified = controller.currentZoom > fit * 1.05;
        unawaited(
          controller.zoomOnLocalPosition(
            localPosition: details.localPosition,
            newZoom: magnified ? fit : fit * widget.engine.doubleTapScale,
          ),
        );
        return true;
      case PdfViewerGeneralTapType.longPress ||
          PdfViewerGeneralTapType.secondaryTap:
        return false;
    }
  }

  /// A link to a place in the document goes there. A link out of it is
  /// the host's to open, or not: the reader opens nothing itself (MR8).
  void _onLink(PdfLink link) {
    if (link.dest case final dest?) {
      unawaited(_controller.goToDest(dest));
    } else if (link.url case final url?) {
      _page.openLink(url);
    }
  }

  /// Marks the links that do something.
  void _paintLinks(
    Canvas canvas,
    Rect pageRect,
    PdfPage page,
    List<PdfLink> links,
  ) {
    final paint = Paint()..color = _linkColour;
    for (final link in links) {
      if (link.dest == null && !_page.opensLinks) continue;
      for (final rect in link.rects) {
        canvas.drawRect(
          rect.toRectInDocument(page: page, pageRect: pageRect),
          paint,
        );
      }
    }
  }

  /// Copy and Select all, and nothing else (MR9).
  Widget? _menu(
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    final text = params.textSelectionDelegate;
    final strings = _page.chrome.strings;
    final enabled = params.isTextSelectionEnabled;
    final menu = MediaReaderTextMenu(
      chrome: _page.chrome,
      actions: [
        if (enabled && text.isCopyAllowed && text.hasSelectedText)
          (
            label: strings.copy,
            onPressed: () {
              unawaited(text.copyTextSelection());
              params.dismissContextMenu();
            },
          ),
        if (enabled && !text.isSelectingAllText)
          (
            label: strings.selectAll,
            onPressed: () => unawaited(text.selectAllText()),
          ),
      ],
    );
    if (menu.actions.isEmpty) return null;
    // Over a selection the viewer places the menu beside it. Elsewhere
    // it goes where the pointer was.
    return params.a != null
        ? menu
        : Positioned(
            left: params.anchorA.dx,
            top: params.anchorA.dy,
            child: menu,
          );
  }

  /// The sideways arrows are the reader's while the page fits its width:
  /// they go between files. The rest are the viewer's.
  bool? _onKey(
    PdfViewerKeyHandlerParams params,
    LogicalKeyboardKey key,
    bool isRealKeyPress,
  ) {
    final sideways =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    return sideways && !_page.holdsPaging.value ? false : null;
  }

  @override
  void dispose() {
    _page.isCurrent.removeListener(_onCurrent);
    _controller.removeListener(_onView);
    if (identical(_page.document.value, _handle)) _page.document.value = null;
    _handle?.dispose();
    // The viewer below is gone already: nothing reads the document now.
    unawaited(_document?.dispose());
    _reader?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = _page.chrome;
    final ref = _ref;
    if (ref == null) {
      final poster = widget.item.poster;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (poster != null) ExcludeSemantics(child: poster(context)),
          // A neighbour waits with its poster; the ring turns once the
          // file is asked for.
          if (_page.isCurrent.value)
            Center(child: MediaReaderBusy(chrome: chrome)),
        ],
      );
    }
    final safe = MediaQuery.paddingOf(context);
    _topInset = safe.top + chrome.contentInsets.top;
    _bottomInset = safe.bottom + chrome.contentInsets.bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewWidth = constraints.maxWidth;
        return _viewer(ref);
      },
    );
  }

  Widget _viewer(PdfDocumentRef ref) {
    final chrome = _page.chrome;
    return PdfViewer(
      ref,
      controller: _controller,
      params: PdfViewerParams(
        backgroundColor: chrome.background,
        pageDropShadow: null,
        layoutPages: _layoutPages,
        sizeDelegateProvider: PdfViewerSizeDelegateProviderSmart(
          maxScale: widget.engine.maxScale,
        ),
        textSelectionParams: const PdfTextSelectionParams(),
        linkHandlerParams: PdfLinkHandlerParams(
          onLinkTap: _onLink,
          customPainter: _paintLinks,
          // Text that only looks like an address is a link where the
          // host opens links.
          enableAutoLinkDetection: _page.opensLinks,
        ),
        pagePaintCallbacks: [
          (canvas, pageRect, page) =>
              _handle?.paintMatches(canvas, pageRect, page),
        ],
        onViewerReady: _onReady,
        onPageChanged: _onPage,
        onGeneralTap: _onTap,
        buildContextMenu: _menu,
        onKey: _onKey,
        // The default banner offers to open a web page: it is never
        // shown (MR8). What fails goes to the card.
        errorBannerBuilder: (context, error, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _fail(error));
          return const SizedBox.shrink();
        },
        loadingBannerBuilder: (context, _, _) =>
            Center(child: MediaReaderBusy(chrome: chrome)),
      ),
    );
  }
}
