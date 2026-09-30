## 0.3.0 — 2026-09-30

Phase R3, video (MEDIA_READER_PLAN.md):

- `MediaReaderVideoEngine`, on the `video_player` API: AVPlayer on iOS
  and macOS, ExoPlayer on Android, `fvp` on Windows and Linux. A
  format the platform's player does not play is shown through its
  preview.
- A video is resolved and opened when its page comes on screen, stops
  when the page is left and goes on when it is back; two never play
  at once; the player is released with its page.
- A location that has run out is renewed before a play or a seek, and
  once when the player gives up under way; the video goes on where it
  was.
- `MediaReaderPlayback` and the chrome's `controls` slot: what plays
  on a page, and the transport that drives it. The plain default
  plays, scrubs, shows the time played and left, changes speed and
  mutes.
- An HLS playlist is read as a video.
- The example plays bundled videos from its loopback server.

## 0.2.0 — 2026-09-30

Phase R2, pictures (MEDIA_READER_PLAN.md):

- `MediaReaderPictureEngine`: JPEG, PNG, GIF, WebP, BMP and ICO
  everywhere, HEIC and TIFF where the system decodes them; pinch,
  double tap and wheel zoom; panning within the edges; the zoom gone
  when the page is left.
- A picture is decoded to fit the screen whatever its size, again with
  more detail once zoomed into, and never past a cap.
- At rest a drag pages or dismisses; zoomed, or with two fingers down,
  it is the picture's. A quick flick pages on a phone too.
- A remote picture is fetched at the location the page keeps, renewed
  once when it is refused, and known to the image cache by the file,
  not by its URL. A host may give its own image provider, asked only
  while export is allowed.
- `MediaReaderTransport` and `MediaReaderFetcher`: how an engine with
  no plugin of its own fetches a file, whole or by range.
- The card offers "Try again" after a failure; `MediaReaderPage.retry`.
- `MediaReaderItem.format`.
- The example serves bundled samples from a loopback server that signs
  and expires URLs as a host's CDN would.

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
