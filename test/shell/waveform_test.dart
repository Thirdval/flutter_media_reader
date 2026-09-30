import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_media_reader/flutter_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A waveform 200 wide, and the seeks it asks for.
  Future<List<Duration>> pumpWaveform(
    WidgetTester tester, {
    List<double>? peaks,
    Duration position = const Duration(seconds: 30),
    Duration? duration = const Duration(minutes: 2),
    TextDirection textDirection = TextDirection.ltr,
    String semanticLabel = 'Position',
  }) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: textDirection,
        child: Center(
          child: SizedBox(
            width: 200,
            child: MediaReaderWaveform(
              peaks: peaks,
              position: position,
              duration: duration,
              onSeek: seeks.add,
              color: const Color(0xFFFFFFFF),
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
    return seeks;
  }

  /// What the waveform paints with: bars, or a plain track.
  String painter(WidgetTester tester) => tester
      .widget<CustomPaint>(
        find.descendant(
          of: find.byType(MediaReaderWaveform),
          matching: find.byType(CustomPaint),
        ),
      )
      .painter
      .runtimeType
      .toString();

  final peaks = [for (var i = 0; i < 100; i++) (i % 10) / 10];

  group('MediaReaderWaveform', () {
    testWidgets('draws the peaks as bars', (tester) async {
      await pumpWaveform(tester, peaks: peaks);

      expect(painter(tester), '_Bars');
    });

    testWidgets('draws a plain track without peaks', (tester) async {
      await pumpWaveform(tester);
      expect(painter(tester), '_Track');

      await pumpWaveform(tester, peaks: const []);
      expect(painter(tester), '_Track');
    });

    testWidgets('paints whatever the peaks are', (tester) async {
      // More peaks than bars, fewer peaks than bars, and peaks out of
      // their range: none of them is a painting error.
      for (final odd in [
        List.filled(5000, 0.5),
        [0.2, 0.9],
        [-1.0, 7.0, double.nan],
      ]) {
        await pumpWaveform(tester, peaks: odd);
        expect(tester.takeException(), isNull);
      }
    });

    for (final drawn in ['bars', 'a plain track']) {
      testWidgets('a tap along $drawn seeks to that place', (tester) async {
        final seeks = await pumpWaveform(
          tester,
          peaks: drawn == 'bars' ? peaks : null,
        );
        final track = tester.getRect(find.byType(MediaReaderWaveform));

        await tester.tapAt(track.centerLeft + const Offset(50, 0));
        await tester.pump();

        expect(seeks.single, const Duration(seconds: 30));
      });
    }

    testWidgets('a drag seeks when it ends, where it ends', (tester) async {
      final seeks = await pumpWaveform(tester, peaks: peaks);
      final track = tester.getRect(find.byType(MediaReaderWaveform));

      final gesture = await tester.startGesture(
        track.centerLeft + const Offset(40, 0),
      );
      await gesture.moveBy(const Offset(60, 0));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(seeks, isEmpty);

      await gesture.up();
      await tester.pump();

      expect(seeks.single, const Duration(seconds: 90));
    });

    testWidgets('a drag past the ends stays inside the file', (tester) async {
      final seeks = await pumpWaveform(tester, peaks: peaks);
      final track = tester.getRect(find.byType(MediaReaderWaveform));

      await tester.dragFrom(track.center, const Offset(500, 0));
      await tester.pump();
      await tester.dragFrom(track.center, const Offset(-500, 0));
      await tester.pump();

      expect(seeks, [const Duration(minutes: 2), Duration.zero]);
    });

    testWidgets('nothing can be sought while the length is not known', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final seeks = await pumpWaveform(tester, peaks: peaks, duration: null);

      await tester.tap(find.byType(MediaReaderWaveform));
      await tester.pump();

      expect(seeks, isEmpty);
      expect(
        tester.getSemantics(find.byType(MediaReaderWaveform)),
        isSemantics(label: 'Position', value: '0:30', isSlider: true),
      );
      semantics.dispose();
    });

    testWidgets('is a slider a screen reader can move', (tester) async {
      final semantics = tester.ensureSemantics();
      final seeks = await pumpWaveform(
        tester,
        peaks: peaks,
        semanticLabel: 'Position dans la note',
      );

      expect(
        tester.getSemantics(find.byType(MediaReaderWaveform)),
        isSemantics(
          label: 'Position dans la note',
          value: '0:30',
          increasedValue: '0:35',
          decreasedValue: '0:25',
          isSlider: true,
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );

      tester.semantics.performAction(
        find.semantics.byLabel('Position dans la note'),
        SemanticsAction.increase,
      );
      await tester.pump();

      expect(seeks.single, const Duration(seconds: 35));
      semantics.dispose();
    });

    testWidgets('runs left to right in a right-to-left language', (
      tester,
    ) async {
      final seeks = await pumpWaveform(
        tester,
        peaks: peaks,
        textDirection: TextDirection.rtl,
      );
      final track = tester.getRect(find.byType(MediaReaderWaveform));

      await tester.tapAt(track.centerLeft + const Offset(50, 0));
      await tester.pump();

      expect(seeks.single, const Duration(seconds: 30));
    });
  });
}
