/// The size cap of the project rules: library files stay at or under 400
/// lines. There is no ledger; a file over the cap splits by concern.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _cap = 400;

void main() {
  test('library files stay at or under the size cap', () {
    final over = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync().length;
      if (lines > _cap) over.add('${file.path}: $lines > $_cap');
    }

    expect(over, isEmpty, reason: 'Over the size cap:\n${over.join('\n')}');
  });
}
