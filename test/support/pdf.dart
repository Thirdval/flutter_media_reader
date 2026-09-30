/// PDFs made on the spot, and the real PDFium to read them with, for the
/// PDF engine's tests (MR14): the engine is tested against the library
/// it adapts.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Points the package at the PDFium that `flutter test` built for this
/// machine, and gives pdfrx a directory of its own for whatever it would
/// keep: the tests check that it keeps nothing there.
Directory setUpPdfium() {
  final kept = Directory.systemTemp.createTempSync('pdfrx_');
  Pdfrx.cacheDirectoryPath = kept.path;
  Pdfrx.pdfiumModulePath ??= Directory('build/native_assets')
      .listSync(recursive: true)
      .whereType<File>()
      .firstWhere((file) => file.path.contains('pdfium'))
      .absolute
      .path;
  return kept;
}

/// Frames and real time, until [done] or for some seconds: PDFium works
/// on another thread, and the viewer on timers.
Future<void> pumpPdf(WidgetTester tester, bool Function() done) async {
  for (var tries = 0; tries < 400 && !done(); tries++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'Still waiting for the PDF');
}

/// Lets the viewer finish what it has under way: the pages after the
/// first, the images of those on screen.
Future<void> settlePdf(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Takes the reader down and lets PDFium finish with its documents,
/// inside the test: PDFium has one thread for every document, and what a
/// test leaves reading holds up the tests after it.
Future<void> closePdf(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settlePdf(tester, 5);
}

/// A PDF of [pages] US Letter pages.
///
/// Each page has the lines [lines] gives for it (its number, from 1), or
/// "Page n" when it gives none. With [link], the first line of the first
/// page is a link to it. With [password], the file is encrypted (RC4, 40
/// bits) and opens with that password alone. [padding] bytes are added
/// after the header, to make a file of several ranges.
Uint8List pdfOf(
  int pages, {
  List<String> Function(int page)? lines,
  Uri? link,
  String? password,
  int padding = 0,
}) {
  assert(link == null || password == null, 'A link is not encrypted here');
  final id = md5.convert(utf8.encode('pdf-$pages-$padding')).bytes;
  final key = password == null ? null : _Encryption(password, id);
  final objects = <List<int>>[
    ascii.encode('<< /Type /Catalog /Pages 2 0 R >>'),
    ascii.encode(
      '<< /Type /Pages /Kids '
      '[${[for (var i = 0; i < pages; i++) '${4 + i * 2} 0 R'].join(' ')}] '
      '/Count $pages >>',
    ),
    ascii.encode(
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
      '/Encoding /WinAnsiEncoding >>',
    ),
  ];
  for (var page = 1; page <= pages; page++) {
    final text = lines?.call(page) ?? ['Page $page'];
    final content = StringBuffer('BT /F1 18 Tf 72 700 Td 24 TL\n');
    for (final line in text) {
      final escaped = line.replaceAllMapped(
        RegExp(r'[\\()]'),
        (match) => '\\${match[0]}',
      );
      content.write('($escaped) Tj T*\n');
    }
    content.write('ET');
    final annotation = link == null || page > 1
        ? ''
        : ' /Annots [<< /Type /Annot /Subtype /Link /Rect [72 694 400 720] '
              '/Border [0 0 0] /A << /S /URI /URI ($link) >> >>]';
    final contentNumber = 5 + (page - 1) * 2;
    final stream = ascii.encode(content.toString());
    final body = key?.encrypt(stream, contentNumber) ?? stream;
    objects
      ..add(
        ascii.encode(
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Resources << /Font << /F1 3 0 R >> >> '
          '/Contents $contentNumber 0 R$annotation >>',
        ),
      )
      ..add([
        ...ascii.encode('<< /Length ${body.length} >>\nstream\n'),
        ...body,
        ...ascii.encode('\nendstream'),
      ]);
  }
  if (key != null) objects.add(ascii.encode(key.dictionary));

  final out = BytesBuilder()..add(ascii.encode('%PDF-1.4\n'));
  if (padding > 0) out.add(ascii.encode('%${'x' * padding}\n'));
  final offsets = <int>[];
  for (final (index, object) in objects.indexed) {
    offsets.add(out.length);
    out
      ..add(ascii.encode('${index + 1} 0 obj\n'))
      ..add(object)
      ..add(ascii.encode('\nendobj\n'));
  }
  final xref = out.length;
  final hex = [for (final byte in id) byte.toRadixString(16).padLeft(2, '0')];
  out.add(
    ascii.encode(
      'xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'
      '${[for (final offset in offsets) '${'$offset'.padLeft(10, '0')} 00000 n \n'].join()}'
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R '
      '${key == null ? '' : '/Encrypt ${objects.length} 0 R '}'
      '/ID [<${hex.join()}> <${hex.join()}>] >>\n'
      'startxref\n$xref\n%%EOF\n',
    ),
  );
  return out.takeBytes();
}

/// The standard security handler, revision 2: enough to make a file
/// that asks for its password.
class _Encryption(String password, final List<int> _id) {
  static const _pad = [
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, //
    0x56, 0xFF, 0xFA, 0x01, 0x08, 0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, //
    0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
  ];

  /// Every permission: the file is locked, not restricted.
  static const _permissions = -4;

  final List<int> _padded = [...ascii.encode(password), ..._pad].sublist(0, 32);
  late final List<int> _owner = _rc4(
    md5.convert(_padded).bytes.sublist(0, 5),
    _padded,
  );
  late final List<int> _key = md5
      .convert([
        ..._padded,
        ..._owner,
        ...(ByteData(
          4,
        )..setInt32(0, _permissions, Endian.little)).buffer.asUint8List(),
        ..._id,
      ])
      .bytes
      .sublist(0, 5);

  String get dictionary =>
      '<< /Filter /Standard /V 1 /R 2 /O <${_hex(_owner)}> '
      '/U <${_hex(_rc4(_key, _pad))}> /P $_permissions >>';

  /// [data] as it stands in object [number], generation 0.
  List<int> encrypt(List<int> data, int number) => _rc4(
    md5
        .convert([
          ..._key,
          number & 0xFF,
          (number >> 8) & 0xFF,
          (number >> 16) & 0xFF,
          0,
          0,
        ])
        .bytes
        .sublist(0, 10),
    data,
  );

  static String _hex(List<int> bytes) =>
      [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')].join();

  static List<int> _rc4(List<int> key, List<int> data) {
    final s = List<int>.generate(256, (i) => i);
    void swap(int i, int j) {
      final held = s[i];
      s[i] = s[j];
      s[j] = held;
    }

    for (var i = 0, j = 0; i < 256; i++) {
      j = (j + s[i] + key[i % key.length]) & 0xFF;
      swap(i, j);
    }
    final out = Uint8List(data.length);
    for (var n = 0, i = 0, j = 0; n < data.length; n++) {
      i = (i + 1) & 0xFF;
      j = (j + s[i]) & 0xFF;
      swap(i, j);
      out[n] = data[n] ^ s[(s[i] + s[j]) & 0xFF];
    }
    return out;
  }
}

/// A host's canvas for a PDF test, as wide as a phone is not: 800 by 600.
const Size pdfSurface = Size(800, 600);
