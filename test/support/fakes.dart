/// Fake engines, sources and hosts for the reader's tests (MR14).
library;

import 'dart:typed_data';

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
  bool autofocus = true,
  TextDirection textDirection = TextDirection.ltr,
}) => tester.pumpWidget(
  WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => Directionality(
      textDirection: textDirection,
      child: MediaReaderView(
        items: items,
        initialIndex: initialIndex,
        chrome: chrome,
        policy: policy,
        engines: engines,
        onDismissed: onDismissed,
        onItemShown: onItemShown,
        autofocus: autofocus,
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
