## 1.1.1 — 2026-10-06

- The chrome rides above the on-screen keyboard: on a phone or a
  tablet a document's search field sat under it, and you typed blind.
  The slots now take the keyboard's room at the bottom (SafeArea keeps
  the system's bars only).
- Esc ends a document's search on a Mac too. A focused text field there
  keeps the Esc key and hands up a `DismissIntent` from the platform's
  `cancelOperation:`; the search now ends on that intent as well as on
  the key.

## 1.1.0 — 2026-10-01

- `MediaReaderChrome.glyph`: the host's own icons on the plain
  controls (the transport, the document bar and its search, the close
  button) in place of the glyphs the reader draws. `MediaReaderGlyph`
  names them (play, pause, sound, muted, search, pages, up, down,
  close); the builder is told the glyph, the colour and the size, and
  returns null to keep the reader's drawing. `MediaReaderAudioBar`
  takes the same builder as its `glyph`. The example's chrome uses
  Material's icons through it.

## 1.0.0 — 2026-09-30

Phase R10, 1.0 (MEDIA_READER_PLAN.md):

- **`fvp` is now your dependency**, for Windows and Linux only, where
  it registers itself as `video_player`'s implementation. A plugin is
  built for every platform an app targets, so as a dependency of this
  package it carried libmdk, FFmpeg, libass and dav1d into iOS,
  Android and macOS builds where the package never used them: 27 MB
  on macOS, 13 MB per ABI on Android. Add `fvp: ^0.39.0` to an app
  that ships on Windows or Linux; without it, video and audio show
  their card there.
- `NOTICE.md`: the packages and native libraries the engines bring,
  their licences, and what they ask of an app that ships them.
- The README's "Size" section: what the package adds to a release
  build on Android and macOS, measured; iOS estimated.
- Doc comments on every exported interface's members; `dart doc`
  builds the API docs (with dartdoc 9.0.9: the SDK's 9.0.6 crashes
  on a transitive dependency's `@docImport` lines).

## 0.8.0 — 2026-09-30

Phase R8, platform polish (MEDIA_READER_PLAN.md):

- Keys for what plays: the space bar plays and pauses, M mutes, Shift
  with an arrow seeks ten seconds. A picture zooms with + and −, and
  0 fits it again.
- `MediaReaderChrome.menu`: the host's actions for the file on screen,
  on a right-click or a long press with a finger, drawn by the reader
  where the pointer is. `MediaReaderMenuAction` and
  `MediaReaderMenuBuilder`.
- A rail of the files on a wide window, from `railFromWidth` (900
  pixels) across: each by its poster or its kind, the one on screen
  marked, a tap goes to it. It hides with the chrome.
- Less motion, where the platform asks for it: a PDF's page or match
  gone to is there at once, as pages, zooms and the chrome were
  already. A PDF's match gone to comes below the chrome's top slots.
- Text at 200 %: the transport and the document bar grow to 150 % and
  take two rows on a narrow screen; the strip of pages and the card
  keep within the width.
- A picture offers Zoom in, Zoom out and Fit to screen to a screen
  reader. `MediaReaderStrings.menu`, `rail`, `zoomIn`, `zoomOut` and
  `zoomToFit`.
- The example's chrome has the menu, and its window on macOS is wide
  enough for the rail.

## 0.7.0 — 2026-09-30

Phase R7, derivatives (MEDIA_READER_PLAN.md):

- `MediaReaderPreview.preparing()` and `.failed()`: where the host's
  server has got with a derivative. A preview being prepared shows the
  file's card, saying so; one that could not be made says that. A
  ready preview is shown by its own kind's engine, as since R1: an
  Office file through its PDF, a HEIC through its JPEG.
- `showMediaReader(liveItems:)`: the reader follows the host's items
  while it is open, so a preview the server finishes takes the card's
  place where it stands.
- The example shows an Office file through a PDF, and one whose PDF a
  switch on the samples page finishes.

## 0.6.0 — 2026-09-30

Phase R6, text, Markdown, tables and archives (MEDIA_READER_PLAN.md):

- `MediaReaderTextEngine`: text, logs, code, JSON and XML, a line at a
  time, with the lines on screen and no others built. UTF-8, UTF-16
  and Windows-1252. Prose in the reader's face; the rest in a face of
  equal widths, in rows of one height, wrapped at the column or not.
  JSON and XML laid out to be read. Search through every line.
- `MediaReaderMarkdownEngine` on `flutter_markdown_plus`: links to the
  host, images never fetched, the file as written on a toggle.
- `MediaReaderTableEngine` on `two_dimensional_scrollables`: CSV and
  TSV with the header row pinned, the delimiter from the rows, cells
  built where they are on screen, a search.
- `MediaReaderArchiveEngine`: zip, tar and gzip listed with their
  sizes, folders opened in place, and an entry opened through the
  registry in a reader over this one. A zip is read from its end and a
  tar from its headers, so a remote archive is listed after a few
  ranges.
- Selected text has a menu of Copy and Select all; Select all takes
  the whole file; what is copied from several lines has its breaks.
- `MediaReaderToggle` and `MediaReaderDocumentState.toggles`: a
  document's choices, for the chrome's controls.
- `MediaReaderByteLoader`, a file's bytes as they come, and
  `MediaReaderPage.engines`, for an engine that shows another file.
- The example shows a sermon, a README, JSON, a log of thirty thousand
  lines, a table of a hundred thousand rows, a zip and a gzipped tar.

## 0.5.0 — 2026-09-30

Phase R5, PDF (MEDIA_READER_PLAN.md):

- `MediaReaderPdfEngine`, on `pdfrx` (PDFium): continuous pages fitted
  to the width, zoom, the page on screen as the status, links inside
  the document, and the keys for a document.
- A remote PDF is read by ranges through the package's own fetcher, as
  PDFium asks for its parts: the first page is up before the rest has
  come, and the location is the page's, renewed when refused.
  `MediaReaderFetcher.fetchRange` hands over a whole file when the
  server ignores ranges.
- The ranges are kept where the policy says: in memory while the file
  is open, in memory between showings, or in the host's directory.
  `MediaReaderCache.clearMemory()` lets go of what memory holds.
- `MediaReaderDocument`: what a page with pages of its own shows, for
  the chrome's controls: the page on screen, go to a page, a page
  drawn small, search. The plain default is a strip of pages with a
  field for a page's number, and a search field.
- Selected text has a menu of Copy and Select all, and nothing else.
  Copying stays allowed with export off.
- `onLink` on `showMediaReader` and `MediaReaderView`: a web address in
  a file is handed to the host, and the reader opens nothing itself.
- A host hook for a protected PDF's password.
- `MediaReaderChrome.contentInsets`: the room the chrome takes, which a
  page that scrolls keeps clear. The plain title has a plate, to be
  read over a white page.
- The example shows a PDF of 300 pages and a protected one.

## 0.4.0 — 2026-09-30

Phase R4, audio and the waveform (MEDIA_READER_PLAN.md):

- `MediaReaderAudioEngine`: `just_audio` on iOS, Android and macOS,
  the `video_player` API (through `fvp`) on Windows and Linux. A
  format the platform's player does not play, an Ogg on an iPhone, is
  played through its preview.
- `MediaReaderAudioCoordinator`: one audio player for the app. A file
  that starts stops the one that was playing, which keeps its place;
  a video that starts stops the audio, and the other way round.
- `MediaReaderAudioBar`: the inline player for a chat's voice notes.
  It and the reader's page for the same file are one session: one
  player, one location asked of the host, and either place's controls.
- `MediaReaderWaveform`: the host's peaks as bars, the part played in
  full colour, a tap or a drag to seek, a slider to a screen reader;
  a plain track without peaks. The plain transport uses it.
- A location that has run out is renewed before a play or a seek, and
  once when the player gives up under way.
- The audio session's category stays the host's to set: the package
  configures nothing.
- The example plays a voice note in a bubble and in the reader, an
  MP3, a WAV from a file, and an Ogg with its MP3.

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
