/// Nothing leaves the app (MR8): the package takes on no plugin that
/// hands a file, a link or a share to another app, and no library file
/// imports one. Export is only ever the host's action.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages that hand off to another app, to the browser, or to the
/// device's own storage. The list grows as such packages appear.
const _handOffs = [
  'url_launcher',
  'open_filex',
  'open_file',
  'open_file_plus',
  'open_app_file',
  'share_plus',
  'share',
  'android_intent_plus',
  'flutter_custom_tabs',
  'flutter_web_browser',
  'external_app_launcher',
  'file_saver',
  'flutter_file_dialog',
  'gal',
  'image_gallery_saver',
  'image_gallery_saver_plus',
  'printing',
];

void main() {
  test('the pubspec names no hand-off package', () {
    final named = [
      for (final line in File('pubspec.yaml').readAsLinesSync())
        if (RegExp(r'^\s+([a-z0-9_]+)\s*:').firstMatch(line) case final entry?)
          if (_handOffs.contains(entry.group(1))) line.trim(),
    ];

    expect(named, isEmpty, reason: 'A hand-off package in pubspec.yaml (MR8)');
  });

  test('no library file imports a hand-off package', () {
    final imports = <String>[];
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final line in file.readAsLinesSync()) {
        final package = RegExp(
          r'''^\s*(?:import|export)\s+['"]package:([a-z0-9_]+)/''',
        ).firstMatch(line)?.group(1);
        if (_handOffs.contains(package)) imports.add('${file.path}: $line');
      }
    }

    expect(imports, isEmpty, reason: 'A hand-off import in lib/ (MR8)');
  });
}
