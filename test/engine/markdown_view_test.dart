import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_media_reader/src/engine/markdown/markdown_style.dart';
import 'package:flutter_media_reader/src/engine/text/text_line.dart';
import 'package:flutter_media_reader/src/shell/document_bar.dart';
import 'package:flutter_media_reader/src/shell/text_menu.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  const source =
      '# Rota\n\n'
      'The [rota online](https://tendvine.example/rota) has every week.\n\n'
      '![The hall](https://tendvine.example/hall.jpg)\n\n'
      '- Welcome: Ruth\n'
      '- Sound: Daniel\n';

  late WatchedEngine engine;
  late FakeTransport transport;
  setUp(() {
    transport = FakeTransport();
    // What one test's file left in memory is not the next test's file.
    MediaReaderCache.clearMemory();
  });

  MediaReaderItem markdown(String content, {MediaReaderSource? source}) =>
      MediaReaderItem(
        id: 'notes',
        name: 'notes.md',
        source: source ?? MediaReaderSource.bytes(utf8.encode(content)),
      );

  Future<MediaReaderPage> pumpMarkdown(
    WidgetTester tester,
    MediaReaderItem item, {
    int maxFormattedBytes = 1024 * 1024,
    ValueChanged<Uri>? onLink,
  }) async {
    engine = WatchedEngine(
      MediaReaderMarkdownEngine(
        transport: transport,
        maxFormattedBytes: maxFormattedBytes,
      ),
    );
    await pumpReader(
      tester,
      items: [item],
      engines: MediaReaderEngines([engine]),
      onLink: onLink,
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    return engine.pages['notes']!;
  }

  group('a Markdown file', () {
    testWidgets('is laid out, with the plain bar offering to show it as '
        'written', (tester) async {
      final semantics = tester.ensureSemantics();
      final page = await pumpMarkdown(tester, markdown(source));

      expect(find.byType(Markdown), findsOneWidget);
      expect(find.text('Rota'), findsOneWidget);
      expect(find.textContaining('has every week'), findsOneWidget);
      expect(find.textContaining('Welcome: Ruth'), findsOneWidget);
      expect(page.holdsDismiss.value, isTrue);

      expect(find.byType(MediaReaderDocumentBar), findsOneWidget);
      expect(find.text('Formatted'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsNothing);
      expect(find.bySemanticsLabel('Pages'), findsNothing);
      semantics.dispose();
    });

    testWidgets('is shown as it is written when asked', (tester) async {
      final page = await pumpMarkdown(tester, markdown(source));

      page.document.value!.state.value.toggles.single.onChanged(false);
      await tester.pumpAndSettle();

      expect(find.byType(Markdown), findsNothing);
      expect(find.byType(MediaReaderTextLine), findsWidgets);
      expect(find.textContaining('# Rota'), findsOneWidget);
      // Nothing was fetched again: the text is the bytes that came.
      expect(transport.requests, isEmpty);
    });

    testWidgets('too long to lay out is shown as it is written', (
      tester,
    ) async {
      await pumpMarkdown(tester, markdown(source), maxFormattedBytes: 20);

      expect(find.byType(Markdown), findsNothing);
      expect(find.textContaining('# Rota'), findsOneWidget);
    });

    testWidgets('comes from a signed URL', (tester) async {
      final host = FakeResolve();
      transport = FakeTransport({'/1': utf8.encode(source)});

      await pumpMarkdown(
        tester,
        markdown('', source: MediaReaderSource.remote(host.call)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rota'), findsOneWidget);
      expect(host.calls, 1);
    });

    testWidgets('that does not come says so', (tester) async {
      transport.failure = const SocketException('no route');

      final page = await pumpMarkdown(
        tester,
        markdown('', source: MediaReaderSource.remote(FakeResolve().call)),
      );
      await tester.pumpAndSettle();
      expect(page.failure.value, isNotNull);

      expect(
        find.text('This file could not be reached. Check the connection.'),
        findsOneWidget,
      );
    });
  });

  group('what is in it', () {
    testWidgets('a link is handed to the host, and looks like one', (
      tester,
    ) async {
      final opened = <Uri>[];
      await pumpMarkdown(tester, markdown(source), onLink: opened.add);
      final paragraph = find.textContaining('rota online');
      final style = tester.widget<Markdown>(find.byType(Markdown)).styleSheet!;
      expect(style.a!.decoration, TextDecoration.underline);

      // The link follows "The ": four letters of the test font's, each
      // as wide as the type is high.
      await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(80, 10));
      await tester.pumpAndSettle();

      expect(opened, [Uri.parse('https://tendvine.example/rota')]);
    });

    testWidgets('without a host to hand it to, a link is plain text', (
      tester,
    ) async {
      await pumpMarkdown(tester, markdown(source));
      final paragraph = find.textContaining('rota online');
      final style = tester.widget<Markdown>(find.byType(Markdown)).styleSheet!;
      expect(style.a!.decoration, isNull);

      await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(80, 10));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('an image is never fetched: its words stand for it', (
      tester,
    ) async {
      await pumpMarkdown(tester, markdown(source));

      expect(find.byType(Image), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MediaReaderImageStandIn),
          matching: find.text('The hall'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tap hides the chrome, and another brings it back', (
      tester,
    ) async {
      final page = await pumpMarkdown(tester, markdown(source));

      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
      expect(page.chromeVisible.value, isFalse);

      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
      expect(page.chromeVisible.value, isTrue);
    });

    testWidgets('text can be selected and copied', (tester) async {
      final copied = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final data = call.arguments as Map<Object?, Object?>;
              copied.add(data['text']! as String);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpMarkdown(tester, markdown(source));

      await tester.longPressAt(
        tester.getTopLeft(find.text('Rota')) + const Offset(10, 10),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MediaReaderTextMenu), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied.single, 'Rota');
    });

    testWidgets('Page Down scrolls it', (tester) async {
      final long = [for (var i = 0; i < 200; i++) 'Paragraph $i.'].join('\n\n');
      await pumpMarkdown(tester, markdown(long));
      expect(find.text('Paragraph 0.'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();

      expect(find.text('Paragraph 0.'), findsNothing);
    });
  });
}
