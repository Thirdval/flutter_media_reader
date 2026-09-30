/// Fake engines, sources and hosts for the reader's tests (MR14).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// An engine that shows the kinds it is given as a line of text, and
/// remembers what happened to its pages.
class FakeEngine(
  @override final String id, {
  final Set<MediaKind> kinds = const {},

  /// Every platform when null.
  final Set<TargetPlatform>? platforms,
}) implements MediaReaderEngine {
  /// The names of the items whose page exists now, in the order they
  /// were made.
  final List<String> alive = [];

  /// The page each item was last built with, by the item's id.
  final Map<String, MediaReaderPage> pages = {};

  /// How many times the engine has built a page.
  int builds = 0;

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      kinds.contains(item.kind) && (platforms?.contains(platform) ?? true);

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => _FakeEnginePage(engine: this, item: item, page: page);
}

class const _FakeEnginePage({
  required final FakeEngine engine,
  required final MediaReaderItem item,
  required final MediaReaderPage page,
}) extends StatefulWidget {
  @override
  State<_FakeEnginePage> createState() => _FakeEnginePageState();
}

class _FakeEnginePageState() extends State<_FakeEnginePage> {
  @override
  void initState() {
    super.initState();
    widget.engine.alive.add(widget.item.name);
  }

  @override
  void dispose() {
    widget.engine.alive.remove(widget.item.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.engine
      ..builds += 1
      ..pages[widget.item.id] = widget.page;
    return Center(child: Text('${widget.engine.id}:${widget.item.name}'));
  }
}

/// A real engine, watched: the page it was last handed for each item.
class WatchedEngine(final MediaReaderEngine _engine)
    implements MediaReaderEngine {
  /// The page each item was last built with, by the item's id.
  final Map<String, MediaReaderPage> pages = {};

  @override
  String get id => _engine.id;

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      _engine.canShow(item, platform);

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) {
    pages[page.item.id] = page;
    return _engine.build(context, item, page);
  }
}

/// A host's resolve: counts its calls and answers each with a new URL.
class FakeResolve({
  /// How long each answer is valid for; forever when null.
  final Duration? validFor,
  final DateTime Function() now = DateTime.now,
}) {
  int calls = 0;

  /// Thrown by every call while set.
  Object? failure;

  Future<MediaReaderLocation> call() async {
    calls++;
    if (failure case final failure?) throw failure;
    return MediaReaderLocation(
      Uri.parse('https://files.test/$calls'),
      expiresAt: switch (validFor) {
        null => null,
        final validFor => now().add(validFor),
      },
    );
  }
}

/// An item named [name], with the name as its id and empty bytes as its
/// source unless told otherwise.
MediaReaderItem item(
  String name, {
  String? id,
  String? contentType,
  int? size,
  MediaKind? kind,
  MediaReaderSource? source,
  MediaReaderPreview? preview,
  Object? data,
}) => MediaReaderItem(
  id: id ?? name,
  name: name,
  contentType: contentType,
  size: size,
  kind: kind,
  source: source ?? MediaReaderSource.bytes(Uint8List(0)),
  preview: preview,
  data: data,
);

/// Pumps a reader view in an app, 800 by 600.
Future<void> pumpReader(
  WidgetTester tester, {
  required List<MediaReaderItem> items,
  int initialIndex = 0,
  MediaReaderChrome chrome = const MediaReaderChrome(),
  MediaReaderPolicy policy = const MediaReaderPolicy(),
  MediaReaderEngines engines = MediaReaderEngines.standard,
  VoidCallback? onDismissed,
  ValueChanged<MediaReaderItem>? onItemShown,
  ValueChanged<Uri>? onLink,
  bool autofocus = true,
  TextDirection textDirection = TextDirection.ltr,

  /// The device's touch slop, where it reports one: a phone's is about
  /// half of Flutter's own.
  double? touchSlop,
}) => tester.pumpWidget(
  WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(gestureSettings: DeviceGestureSettings(touchSlop: touchSlop)),
      child: Directionality(
        textDirection: textDirection,
        child: MediaReaderView(
          items: items,
          initialIndex: initialIndex,
          chrome: chrome,
          policy: policy,
          engines: engines,
          onDismissed: onDismissed,
          onItemShown: onItemShown,
          onLink: onLink,
          autofocus: autofocus,
        ),
      ),
    ),
  ),
);

/// Five pictures, a.jpg to e.jpg.
List<MediaReaderItem> pictures([int count = 5]) => [
  for (final letter in 'abcde'.substring(0, count).split(''))
    item('$letter.jpg'),
];

/// Drags the pager one page towards the end (to the next item, left to
/// right) and lets it settle.
Future<void> swipeToNext(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

/// Drags the pager one page towards the start and lets it settle.
Future<void> swipeToPrevious(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(500, 0));
  await tester.pumpAndSettle();
}

/// A transport that answers from [files], by the path of the URL, and
/// remembers what it was asked.
class FakeTransport([final Map<String, Uint8List> files = const {}])
    implements MediaReaderTransport {
  /// Every GET made, in order.
  final List<({Uri uri, Map<String, String> headers, MediaReaderRange? range})>
  requests = [];

  /// The status for a URL, when it is not to be served: a refusal, a
  /// missing file. Null serves the file.
  int? Function(Uri uri)? status;

  /// Thrown by every GET while set: the network is down.
  Exception? failure;

  /// Whether the server honours ranges; when not, it sends the whole
  /// file with a 200.
  bool ranges = true;

  /// Waited for before a GET is answered, when it gives something to
  /// wait for: a slow part of a file.
  Future<void>? Function(Uri uri, MediaReaderRange? range)? hold;

  @override
  Future<MediaReaderResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    MediaReaderRange? range,
  }) async {
    requests.add((uri: uri, headers: headers, range: range));
    await hold?.call(uri, range);
    if (failure case final failure?) throw failure;
    final refused = status?.call(uri);
    if (refused != null) {
      return MediaReaderResponse(status: refused, body: const Stream.empty());
    }
    final file = files[uri.path];
    if (file == null) {
      return const MediaReaderResponse(status: 404, body: Stream.empty());
    }
    if (range == null || !ranges) {
      return MediaReaderResponse(
        status: 200,
        body: Stream.value(file),
        length: file.length,
      );
    }
    final end = switch (range.end) {
      final end? when end < file.length => end + 1,
      _ => file.length,
    };
    final part = Uint8List.sublistView(file, range.start, end);
    return MediaReaderResponse(
      status: 206,
      body: Stream.value(part),
      length: part.length,
      total: file.length,
    );
  }
}

/// A PNG of one colour, [width] by [height] pixels.
Future<Uint8List> pngOf(WidgetTester tester, int width, int height) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF2266AA),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Pumps, letting real time pass between frames (an image decodes, a
/// file is read), until [done] or for a second.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var tries = 0; tries < 100 && !done(); tries++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
