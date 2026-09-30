import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late FakeEngine engine;
  late MediaReaderEngines engines;
  setUp(() {
    engine = FakeEngine('fake', kinds: {MediaKind.picture, MediaKind.pdf});
    engines = MediaReaderEngines([engine]);
  });

  MediaReaderItem remote(String name, FakeResolve host) =>
      item(name, source: MediaReaderSource.remote(host.call));

  group("the file's card", () {
    testWidgets('shows a file no engine shows: name, kind and size', (
      tester,
    ) async {
      await pumpReader(
        tester,
        items: [
          item('model.glb', contentType: 'model/gltf-binary', size: 2562048),
        ],
        engines: engines,
        chrome: MediaReaderChrome(topStart: (_, _) => const SizedBox()),
      );

      expect(find.text('model.glb'), findsOneWidget);
      expect(find.text('File · 2.4 MB'), findsOneWidget);
      expect(find.text('GLB'), findsOneWidget);
      expect(find.text('This file cannot be shown here.'), findsOneWidget);
    });

    testWidgets('leaves out what the host did not say', (tester) async {
      await pumpReader(
        tester,
        items: [item('README')],
        chrome: MediaReaderChrome(topStart: (_, _) => const SizedBox()),
      );

      expect(find.text('README'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);
    });

    testWidgets("carries the host's actions, told whether export is allowed", (
      tester,
    ) async {
      final chrome = MediaReaderChrome(
        cardActions: (context, state) => state.canExport
            ? Text('Save ${state.item.name}')
            : const Text('Saving is off in this community'),
      );

      await pumpReader(tester, items: [item('Budget.xlsx')], chrome: chrome);
      expect(find.text('Save Budget.xlsx'), findsOneWidget);

      await pumpReader(
        tester,
        items: [item('Budget.xlsx')],
        chrome: chrome,
        policy: const MediaReaderPolicy(canExport: false),
      );
      expect(find.text('Saving is off in this community'), findsOneWidget);
    });
  });

  group('an engine that fails', () {
    testWidgets('gives way to the card, with its reason', (tester) async {
      await pumpReader(tester, items: pictures(1), engines: engines);
      expect(find.text('fake:a.jpg'), findsOneWidget);

      engine.pages['a.jpg']!.fail('The picture is damaged.');
      await tester.pump();

      expect(find.text('fake:a.jpg'), findsNothing);
      expect(engine.alive, isEmpty);
      expect(find.text('The picture is damaged.'), findsOneWidget);
      expect(find.text('Picture'), findsOneWidget);
      expect(find.text('This file cannot be shown here.'), findsNothing);
    });

    testWidgets('failing at its preview, the card is the file\'s own', (
      tester,
    ) async {
      final docx = item(
        'Minutes.docx',
        size: 1024,
        preview: MediaReaderPreview(
          source: MediaReaderSource.bytes(Uint8List(1)),
          contentType: 'application/pdf',
        ),
      );
      await pumpReader(tester, items: [docx], engines: engines);
      expect(find.text('fake:Minutes.docx'), findsOneWidget);
      // The engine was built with the preview; the page is the file's.
      expect(engine.pages['Minutes.docx']!.item, same(docx));

      engine.pages['Minutes.docx']!.fail('The preview is damaged.');
      await tester.pump();

      expect(find.text('Document · 1 KB'), findsOneWidget);
      expect(find.text('The preview is damaged.'), findsOneWidget);
    });

    testWidgets('is tried again from the card', (tester) async {
      await pumpReader(tester, items: pictures(1), engines: engines);
      engine.pages['a.jpg']!.fail('The picture is damaged.');
      await tester.pump();
      expect(engine.alive, isEmpty);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(find.text('fake:a.jpg'), findsOneWidget);
      expect(find.text('The picture is damaged.'), findsNothing);
      expect(engine.alive, ['a.jpg']);
    });

    testWidgets('has nothing to try again where no engine shows the file', (
      tester,
    ) async {
      await pumpReader(tester, items: [item('model.glb')], engines: engines);

      expect(find.text('This file cannot be shown here.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('may fail while it builds', (tester) async {
      await pumpReader(
        tester,
        items: [item('broken.bin')],
        engines: MediaReaderEngines([_FailingEngine()]),
      );
      expect(tester.takeException(), isNull);
      await tester.pump();

      expect(find.text('Not a file this engine knows.'), findsOneWidget);
      expect(find.text('about to fail'), findsNothing);
    });

    testWidgets('is tried again when another engine takes the file', (
      tester,
    ) async {
      await pumpReader(tester, items: pictures(1), engines: engines);
      engine.pages['a.jpg']!.fail('The picture is damaged.');
      await tester.pump();

      final other = FakeEngine('other', kinds: {MediaKind.picture});
      await pumpReader(
        tester,
        items: pictures(1),
        engines: MediaReaderEngines([other]),
      );

      expect(find.text('other:a.jpg'), findsOneWidget);
      expect(find.text('The picture is damaged.'), findsNothing);
    });
  });

  group('a remote source', () {
    testWidgets('is resolved when the engine asks, not before', (tester) async {
      final host = FakeResolve();
      await pumpReader(
        tester,
        items: [remote('a.jpg', host)],
        engines: engines,
      );
      expect(host.calls, 0);

      final location = await engine.pages['a.jpg']!.resolve();

      expect(host.calls, 1);
      expect(location.uri, Uri.parse('https://files.test/1'));
    });

    testWidgets('keeps its location while the file is paged away from', (
      tester,
    ) async {
      final host = FakeResolve(validFor: const Duration(minutes: 15));
      await pumpReader(
        tester,
        items: [remote('a.jpg', host), ...pictures().skip(1)],
        engines: engines,
      );
      final first = await engine.pages['a.jpg']!.resolve();

      await swipeToNext(tester);
      await swipeToNext(tester);
      expect(engine.alive, isNot(contains('a.jpg')));
      await swipeToPrevious(tester);
      await swipeToPrevious(tester);
      final again = await engine.pages['a.jpg']!.resolve();

      expect(again.uri, first.uri);
      expect(host.calls, 1);
    });

    testWidgets('is resolved again once its location has expired', (
      tester,
    ) async {
      // Valid for less than the margin: stale as soon as it is handed out.
      final host = FakeResolve(validFor: const Duration(seconds: 10));
      await pumpReader(
        tester,
        items: [remote('a.jpg', host)],
        engines: engines,
      );
      final page = engine.pages['a.jpg']!;

      final first = await page.resolve();
      final second = await page.resolve();

      expect(host.calls, 2);
      expect(second.uri, isNot(first.uri));
    });

    testWidgets('is resolved again when its location is refused', (
      tester,
    ) async {
      final host = FakeResolve();
      await pumpReader(
        tester,
        items: [remote('a.jpg', host)],
        engines: engines,
      );
      final page = engine.pages['a.jpg']!;

      final first = await page.resolve();
      final renewed = await page.renew(first);

      expect(host.calls, 2);
      expect(renewed.uri, isNot(first.uri));
      expect((await page.resolve()).uri, renewed.uri);
    });

    testWidgets('asks the host as it is now, when the host rebuilds the item', (
      tester,
    ) async {
      final before = FakeResolve();
      final after = FakeResolve();
      await pumpReader(
        tester,
        items: [remote('a.jpg', before)],
        engines: engines,
      );
      final first = await engine.pages['a.jpg']!.resolve();

      await pumpReader(
        tester,
        items: [remote('a.jpg', after)],
        engines: engines,
      );
      await engine.pages['a.jpg']!.renew(first);

      expect(before.calls, 1);
      expect(after.calls, 1);
    });

    testWidgets('forgets the location of a file the host takes away', (
      tester,
    ) async {
      final host = FakeResolve();
      final file = remote('a.jpg', host);
      final other = item('b.jpg');
      await pumpReader(tester, items: [file, other], engines: engines);
      await engine.pages['a.jpg']!.resolve();

      // Removed by a moderator, then restored.
      await pumpReader(tester, items: [other], engines: engines);
      await pumpReader(tester, items: [file, other], engines: engines);
      await tester.pump();
      await engine.pages['a.jpg']!.resolve();

      expect(host.calls, 2);
    });

    testWidgets('a file the host says is unavailable shows its card, in the '
        "host's words", (tester) async {
      final host = FakeResolve()
        ..failure = const MediaReaderUnavailable(
          'You no longer have access to this file.',
        );
      await pumpReader(
        tester,
        items: [remote('a.jpg', host)],
        engines: engines,
      );

      await expectLater(
        engine.pages['a.jpg']!.resolve(),
        throwsA(isA<MediaReaderUnavailable>()),
      );
      await tester.pump();

      expect(
        find.text('You no longer have access to this file.'),
        findsOneWidget,
      );
      expect(find.text('fake:a.jpg'), findsNothing);
    });

    testWidgets('any other failure is the engine\'s to handle', (tester) async {
      final host = FakeResolve()..failure = StateError('offline');
      await pumpReader(
        tester,
        items: [remote('a.jpg', host)],
        engines: engines,
      );

      await expectLater(engine.pages['a.jpg']!.resolve(), throwsStateError);
      await tester.pump();

      expect(find.text('fake:a.jpg'), findsOneWidget);
    });

    testWidgets("the preview's location is kept apart from the file's", (
      tester,
    ) async {
      final file = FakeResolve();
      final preview = FakeResolve();
      final docx = item(
        'Minutes.docx',
        source: MediaReaderSource.remote(file.call),
        preview: MediaReaderPreview(
          source: MediaReaderSource.remote(preview.call),
          contentType: 'application/pdf',
        ),
      );
      await pumpReader(tester, items: [docx], engines: engines);

      await engine.pages['Minutes.docx']!.resolve();

      expect(preview.calls, 1);
      expect(file.calls, 0);
    });
  });

  group('a page that is not remote', () {
    testWidgets('has no location to resolve', (tester) async {
      await pumpReader(tester, items: pictures(1), engines: engines);

      expect(engine.pages['a.jpg']!.resolve, throwsStateError);
    });
  });

  group('a page on its own', () {
    test('describes a lone page on screen', () {
      final page = MediaReaderPage(item: item('a.jpg'));
      addTearDown(page.dispose);

      expect(page.index, 0);
      expect(page.count, 1);
      expect(page.isCurrent.value, isTrue);
      expect(page.chromeVisible.value, isTrue);
      expect(page.policy.canExport, isTrue);
      expect(page.failure.value, isNull);
      expect(page.state.item.name, 'a.jpg');
      expect(page.state.close, isNull);
    });

    test('resolves its own remote source', () async {
      final host = FakeResolve();
      final page = MediaReaderPage(
        item: item('a.jpg', source: MediaReaderSource.remote(host.call)),
      );
      addTearDown(page.dispose);

      await page.resolve();
      await page.resolve();

      expect(host.calls, 1);
    });

    test('tells a slot the engine\'s status', () {
      final page = MediaReaderPage(item: item('a.pdf'))
        ..status.value = '3 of 15';
      addTearDown(page.dispose);

      expect(page.state.status, '3 of 15');
    });
  });
}

/// Finds out while building that it cannot show the file.
class _FailingEngine() implements MediaReaderEngine {
  @override
  String get id => 'failing';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) => true;

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) {
    page.fail('Not a file this engine knows.');
    return const Center(child: Text('about to fail'));
  }
}
