## 0.1.0 — 2026-09-30

Phase R1, the core and the shell (MEDIA_READER_PLAN.md):

- `showMediaReader` and `MediaReaderView`: the canvas, paging between
  files with the neighbours prepared and further pages released, the
  arrow keys and Esc, a drag down to dismiss, and chrome that a tap
  hides and brings back.
- The host contract: `MediaReaderItem` and `MediaReaderPreview`;
  `MediaReaderSource` (remote, file, bytes), with a remote location
  kept until it expires or is refused and resolved again then;
  `MediaReaderPolicy` and `MediaReaderCache`, where export off keeps
  nothing on disk.
- `MediaReaderChrome`: seven slots, each told the item on screen and
  the reader's state, with a plain default for each, and
  `MediaReaderStrings` for the words the reader draws or speaks.
- `MediaReaderEngine`, the ordered `MediaReaderEngines` registry, and
  `MediaReaderPage`, through which an engine and the shell talk. No
  engine for a kind exists yet: every file shows its card.
- Semantics: each page says its file and its place and is announced
  when it comes on screen; the slots and the page come in reading
  order.
- A test that fails when the pubspec or a library file takes on a
  package that hands off to another app (MR8), and one for the
  400-line cap.
- The example opens its samples in the reader, and runs as an
  integration test on a device.

Every public type takes the `MediaReader` prefix: `flutter_reader`
already exports `ReaderItem` and `ReaderEngine`.

## 0.0.1 — 2026-09-30

Phase R0, the scaffold (MEDIA_READER_PLAN.md):

- The repository, Flutter 3.47.5 through fvm, lints, CI (analyze,
  format, test) and an example app for iOS, Android, macOS, Windows
  and Linux.
- `MediaKind.of(contentType:, fileName:)`: a file read as a kind — a
  specific content type decides; a generic one defers to the
  extension; an MPEG-4 container type defers to an audio-only
  extension.
- The plan of record with its phases and tracker, and the project
  rules for the package's session (CLAUDE.md).
