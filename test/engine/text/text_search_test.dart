import 'package:flutter_media_reader/src/engine/text/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A search through [lines], and how often it said it changed.
  ({MediaReaderTextSearch search, List<int> changes}) searchOf(
    List<String> lines,
  ) {
    final changes = <int>[];
    late final MediaReaderTextSearch search;
    search = MediaReaderTextSearch(
      lineCount: () => lines.length,
      lineAt: (index) => lines[index],
      onChanged: () => changes.add(search.count),
    );
    return (search: search, changes: changes);
  }

  group('MediaReaderTextSearch', () {
    test('finds every place, in any case', () async {
      final (:search, changes: _) = searchOf([
        'Harvest supper',
        'no match',
        'the harvest, the HARVEST',
      ]);

      await search.start('harvest');

      expect(search.count, 3);
      expect(search.current, 0);
      expect(search.at, (line: 0, place: 0));
      expect(search.searching, isFalse);
    });

    test('goes from match to match, round and round', () async {
      final (:search, changes: _) = searchOf(['a harvest', 'harvest harvest']);
      await search.start('harvest');

      search.step(1);
      expect(search.at, (line: 1, place: 0));
      search.step(1);
      expect(search.at, (line: 1, place: 1));
      search.step(1);
      expect(search.at, (line: 0, place: 0));
      search.step(-1);
      expect(search.at, (line: 1, place: 1));
    });

    test('looks for the words as they are, not as a pattern', () async {
      final (:search, changes: _) = searchOf(['a.b', 'axb', '(1+1)']);

      await search.start('a.b');
      expect(search.count, 1);

      await search.start('(1+1)');
      expect(search.count, 1);
    });

    test('an empty query ends the search', () async {
      final (:search, changes: _) = searchOf(['harvest']);
      await search.start('harvest');

      await search.start('');

      expect(search.count, 0);
      expect(search.current, -1);
      expect(search.at, isNull);
      expect(search.pattern, isNull);
    });

    test('goes through a long text a part at a time, saying how far it '
        'is', () async {
      final (:search, :changes) = searchOf([
        for (var i = 0; i < 7000; i++) i % 1000 == 0 ? 'harvest' : 'line $i',
      ]);

      final done = search.start('harvest');
      expect(search.searching, isTrue);
      await done;

      expect(search.count, 7);
      expect(search.searching, isFalse);
      // The count grew as the parts were gone through.
      expect(changes.toSet().length, greaterThan(3));
    });

    test('a new search takes the place of the one under way', () async {
      final (:search, changes: _) = searchOf([
        for (var i = 0; i < 7000; i++) i.isEven ? 'harvest' : 'supper',
      ]);

      final first = search.start('harvest');
      final second = search.start('supper');
      await Future.wait([first, second]);

      expect(search.query, 'supper');
      expect(search.count, 3500);
    });

    test('counts no more matches than it can hold', () async {
      final (:search, changes: _) = searchOf([
        for (var i = 0; i < 3000; i++) 'e e e e e',
      ]);

      await search.start('e');

      expect(search.count, MediaReaderTextSearch.maxMatches);
      expect(search.searching, isFalse);
    });
  });
}
