/// Archives made on the spot for the archive engine's tests (MR14), by a
/// second implementation of the formats.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;

/// A zip of [files] (path to bytes) and [folders], deflated unless
/// [stored]; encrypted with [password] when given.
Uint8List zipOf(
  Map<String, List<int>> files, {
  List<String> folders = const [],
  bool stored = false,
  String? password,
}) {
  final archive = ar.Archive();
  for (final folder in folders) {
    archive.add(ar.ArchiveFile.directory(folder));
  }
  for (final MapEntry(key: path, value: bytes) in files.entries) {
    archive.add(ar.ArchiveFile.bytes(path, bytes));
  }
  return ar.ZipEncoder(password: password).encodeBytes(
    archive,
    level: stored ? ar.DeflateLevel.none : ar.DeflateLevel.defaultCompression,
  );
}

/// A tar of [files] and [folders].
Uint8List tarOf(
  Map<String, List<int>> files, {
  List<String> folders = const [],
}) {
  final archive = ar.Archive();
  for (final folder in folders) {
    archive.add(ar.ArchiveFile.directory(folder));
  }
  for (final MapEntry(key: path, value: bytes) in files.entries) {
    archive.add(ar.ArchiveFile.bytes(path, bytes));
  }
  return ar.TarEncoder().encodeBytes(archive);
}

/// [bytes], gzipped.
Uint8List gzipOf(List<int> bytes) => Uint8List.fromList(gzip.encode(bytes));
