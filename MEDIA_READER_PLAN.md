# flutter_media_reader — Plan of Record

One in-app reader for every file a host hands it — pictures, video,
audio with its waveform, PDF, Office documents (through a PDF the
host makes), text, tables and archives — on iOS, Android, macOS,
Windows and Linux, each kind shown by an engine that can be swapped
per platform. Files never leave the app: exporting is the host's
action, under the host's policy.

**Status:** accepted by the owner on 2026-09-30. R0 (this scaffold)
was built the same day, and the phases after it by this repository's
own session: §5 says how far it has come. Each phase's row is updated
in the same commit as its work, and goes into `main` once the session
has verified it. The owner's check of each phase is still the
owner's.

**Owner decisions (2026-09-30):**
- Video goes through the `video_player` API with `fvp` as its engine
  (MR2).
- A community may turn downloads off: the host passes that policy to
  the reader (MR9), and Tendvine's backend stores it (B3).
- The package is its own Flutter project, public under the Thirdval
  organisation, like `flutter_reader`, with its own Claude session
  (MR1).
- Copying text is not an export in any kind of file, not only in a
  PDF: it stays allowed under a no-download policy (MR9, R5, R6).
- Every public type takes the `MediaReader` prefix (`MediaReaderItem`,
  `MediaReaderEngine`, and so on). `flutter_reader`, which Tendvine's
  chat views import, already exports `ReaderItem` and `ReaderEngine`
  (§2.2).
- The session carries on through the remaining phases, and puts each
  in `main` after verifying it: format, analyze, the tests, and the
  example's integration test on the devices at hand. Nothing is pushed
  or tagged until the owner asks.

**Owner decisions (2026-09-30, relayed by Tendvine's backend
session):**
- Copying text from a PDF is not an export: it stays allowed under a
  no-download policy (MR9, R5).
- The server makes no PDF thumbnails. Where the reader needs a PDF's
  poster, it draws the first page itself (R5, B4).
- Office files become PDFs in a separate converter container on the
  server, so MR7 stands (B2).
- A HEIC becomes a JPEG `display` variant on the server (B4, R7).
- B1–B5 go ahead on the backend's recommendations, in this order: B5,
  the repair of old rows, B1, B3, HEIC, B2 (§6).

**Standing rules:** [CLAUDE.md](CLAUDE.md). English only. Push only
when the owner asks.

---

## 0. Summary for the owner

Tendvine shows pictures and video inside the app, but hands every
other file — PDFs, audio, documents, text, archives — to another app
through the system (`launchUrl`, external application). That is the
leak this package closes. Video and voice notes also do not play on
Windows or Linux today: neither `video_player` nor `just_audio` ships
an implementation there.

The package is a **reader shell with pluggable engines**, not a set of
native plugins. The shell is the full-screen canvas with its chrome
slots, paging between files, zoom, dismiss and keyboard. Each engine
is a small adapter over a maintained plugin:
- `pdfrx` for PDF;
- `video_player` + `fvp` for video;
- `just_audio` for audio, and `fvp` for audio on the desktop;
- Flutter itself for pictures and text;
- `archive` for zip and tar.

A registry picks an engine per file kind and platform. When none can
show a file, the reader shows the file's card, never another app. The
host (Tendvine) lends:
- its chrome (the glass capsules of the Slack-style viewer);
- its actions (reply, forward, share, save, report);
- its audited way to reach a file (signed URLs);
- its policy (may this member export; where may the reader cache).

**Phases:**
- R0 scaffold (built).
- R1 the core and the shell (built).
- R2–R6 one kind of file each: pictures (built), video (built), audio
  with waveform (built), PDF (built), text/tables/archives (built).
- R7 Office and HEIC through the host's derivatives (built).
- R8 platform polish.
- R9 Tendvine adopts it (in its own session, in four steps, the first
  right after R3, which already removes the external hand-off).
- R10 1.0.

**Needed from the backend** (§6):
- waveform peaks and duration at upload;
- a PDF made from each Office file;
- the community download policy;
- range requests on signed URLs.

---

## 1. Where Tendvine stands (the first host)

| Kind | Today | Gap |
| --- | --- | --- |
| Pictures | In-app gallery, in Tendvine's chat feature | Tied to the chat feature; no desktop keyboard or pointer polish |
| Video | In-app page on `video_player` (AVPlayer, ExoPlayer) | No Windows or Linux implementation; webm/mkv do not play on iOS |
| Audio | Voice notes play inline on `just_audio`; audio *files* open outside the app | No waveform for uploads; some voice notes show 0:00 |
| PDF, Office, text, archives | `launchUrl(…, externalApplication)`: another app or the browser | Leaves the app — the reason for this package |
| Export | System share sheet with the signed URL | No community policy |

**Reference:** Slack's iOS file viewer (2026).
- **Canvas:** black.
- **Top:** the sharer's capsule on the left (avatar, name, date, "Thread
  in: …" or the file name) and a round close button on the right.
- **Bottom:** a capsule on the left with Reply and Forward, and a round
  "…" on the right. Above them, a "Shared in #channel" pill.
- **PDFs:** continuous pages with a "1 of 15" pill.
- **Pictures:** iOS Live Text.

The package draws none of that styling itself: it offers the slots
(§2.1) and a plain default. Tendvine fills them with its glass.

---

## 2. Target

### 2.1 Shape

- **The shell:**
  - opened as a route (`showMediaReader`) or embedded
    (`MediaReaderView`, for a desktop pane);
  - pages sideways between items, preparing the neighbours;
  - drag down to dismiss (Esc on the desktop), arrows between items,
    pinch and wheel zoom where the engine zooms;
  - chrome that hides and returns on a tap;
  - semantics and focus order.
- **Chrome slots:** the host builds:
  - top start (who, when, where);
  - top end (close);
  - bottom start (actions);
  - bottom end (more);
  - a context pill;
  - an engine's own status ("1 of 15", a time);
  - the host's actions on a file's card.

  Each slot receives the current item and the reader's state. The
  package ships a plain default for each.
- **Items:** a `MediaReaderItem` describes a file.
  - Its identity and name, content type and size, the kind the host
    already knows (the server's family) if any.
  - A source: how to reach the bytes.
  - A preview: a derivative with its own content type, such as the PDF
    of an Office file or the JPEG of a HEIC.
  - A poster (placeholder), waveform peaks and duration.
  - An opaque host payload for the chrome.
- **Sources:**
  - a remote source is resolved when needed and again when it expires
    or is refused: the host returns a URL, headers, and the expiry
    where it knows it;
  - a local file;
  - bytes in memory.
- **Engines:**
  - `canShow(item, platform)` and `build(context, item, page)`, with
    playback or page state exposed to the chrome;
  - an ordered registry — the first engine that can show the item
    wins;
  - the last one is always the file's card: name, kind, size, and the
    host's actions.
- **Policy:** `MediaReaderPolicy`.
  - Whether export is allowed: the reader tells the chrome, so the
    host shows or hides Share and Save.
  - Where engines may cache: none, memory, or a directory the host
    owns.
  - The package never writes anywhere else and never hands a file to
    another app.

### 2.2 The host contract (settled in R1)

```dart
Future<void> showMediaReader(
  BuildContext context, {
  required List<MediaReaderItem> items,
  int initialIndex = 0,
  MediaReaderChrome chrome = const MediaReaderChrome(), // the slots
  MediaReaderPolicy policy = const MediaReaderPolicy(), // export, cache
  MediaReaderEngines engines = MediaReaderEngines.standard,
  ValueChanged<MediaReaderItem>? onItemShown, // on screen, not prepared
  ValueChanged<Uri>? onLink, // a link in a file: the host's to open (R5)
  ValueListenable<List<MediaReaderItem>>? liveItems, // followed while open (R7)
});

// The same reader as a widget, for a pane. Rebuilt with another list,
// it keeps the file on screen: pages follow their item's id.
class const MediaReaderView({
  required final List<MediaReaderItem> items,
  // ... as above, and:
  final VoidCallback? onDismissed, // null: it cannot be dismissed
  final bool autofocus = true,
});

class const MediaReaderItem({
  required final String id,
  required final String name,
  final String? contentType,
  final int? size,
  final MediaKind? kind, // the host's own reading wins
  required final MediaReaderSource source,
  final MediaReaderPreview? preview, // Office → PDF, HEIC → JPEG
  final WidgetBuilder? poster, // blurhash, thumbnail
  final List<double>? peaks, // 0..1, from the host (MR6)
  final Duration? duration,
  final Object? data, // the host's, for the chrome
});

// A derivative with its own type: its own kind's engine shows it.
class const MediaReaderPreview({
  final MediaReaderSource? source, // null while not ready (R7)
  final String? contentType,
  final String? name,
  final MediaKind? kind,
  final MediaReaderPreviewState state = ready, // preparing, failed (R7)
});

sealed class const MediaReaderSource() {
  // Resolved when needed, kept until it expires or is refused, then
  // resolved again.
  const factory remote(Future<MediaReaderLocation> Function() resolve);
  const factory file(String path);
  const factory bytes(Uint8List bytes);
}

class const MediaReaderLocation(
  final Uri uri, {
  final Map<String, String> headers = const {},
  final DateTime? expiresAt, // asked again shortly before
});

// Thrown by a resolve: the page shows the card, in the host's words.
class const MediaReaderUnavailable(final String reason);

class const MediaReaderPolicy({
  final bool canExport = true,
  // With export off, a directory reads as memory (MR9).
  final MediaReaderCache cache = const MediaReaderCache.memory(),
});

class const MediaReaderChrome({
  // Each slot: Widget Function(BuildContext, MediaReaderState).
  topStart, topEnd, bottomStart, bottomEnd, contextPill, status,
  controls, // for what plays (R3), or for a document (R5)
  cardActions, // the host's actions on a file's card
  menu, // the host's actions on a right-click or a long press (R8)
  background, foreground,
  contentInsets, // the room the slots take: a page that scrolls keeps it clear (R5)
  railFromWidth, // the width from which the rail of files stands (R8)
  strings, // the words the package draws or speaks
});

// What a slot is told.
class const MediaReaderState({
  item, index, count, policy, // and canExport
  status, // the engine's own
  playback, // what plays on the page, for the controls (R3)
  document, // the document on the page, for the controls (R5)
  close, // null where the reader cannot be closed
});

abstract interface class MediaReaderEngine() {
  String get id;
  bool canShow(MediaReaderItem item, TargetPlatform platform);
  Widget build(
    BuildContext context,
    MediaReaderItem item, // the host's, or its preview as an item
    MediaReaderPage page,
  );
}

// An engine's page: what the shell tells it, what it tells the shell.
final class MediaReaderPage {
  MediaReaderItem get item; // always the host's
  ValueListenable<bool> get isCurrent; // on screen, not a neighbour
  ValueListenable<bool> get chromeVisible;
  final ValueNotifier<String?> status; // "1 of 15", a time
  final ValueNotifier<MediaReaderPlayback?> playback; // R3
  final ValueNotifier<MediaReaderDocument?> document; // R5
  bool get opensLinks; // whether the host takes links (R5)
  void openLink(Uri link); // to the host's onLink, and nowhere else
  final ValueNotifier<bool> holdsPaging; // it owns sideways drags
  final ValueNotifier<bool> holdsDismiss; // and downward ones
  Future<MediaReaderLocation> resolve(); // the kept location
  Future<MediaReaderLocation> renew(MediaReaderLocation refused);
  void fail(String reason); // the card takes the engine's place
  void retry(); // the engine starts afresh (R2)
}

// What plays: its state, and play, pause, seekTo, setSpeed, setMuted.
abstract interface class MediaReaderPlayback() { ... }

// A document: the page on screen and the count, goToPage, a page drawn
// small (thumbnail), and search with nextMatch and previousMatch (R5).
// Its state carries the document's toggles, for the controls: a text's
// Wrap, a JSON's or a Markdown's Formatted (R6).
abstract interface class MediaReaderDocument() { ... }
```

What R1 settled beyond the sketch it started from:
- **Names:** every public type is `MediaReader*` (owner, 2026-09-30).
- **A resolve's answer** is a class, `MediaReaderLocation`, not a
  record: it carries an optional expiry, and can grow without breaking
  every host.
- **The preview** has its own content type and kind. The registry asks
  the engines about the file first, then about its preview, and falls
  back to the card.
- **`MediaReaderPage`** is defined: it was named in the sketch and
  left open.
- **`MediaReaderUnavailable`:** how a host's resolve gives the card its
  reason.
- **`cardActions`:** a seventh slot, because the card carries the
  host's actions.
- **`MediaReaderStrings`:** the package draws and speaks a few words
  (the card, the plain defaults, the page announcement); a host passes
  its own.
- **`onItemShown`:** a resolve is not a view; the host hears when an
  item comes on screen.
- **Export off and a directory cache:** the directory reads as memory,
  so MR9 holds whatever the host passes.

Also exported for hosts:
- `MediaReaderAudioBar` (R4): the inline player a chat shows for a
  voice note. It and the reader's page for the item with the same id
  are one session;
- `MediaReaderAudioCoordinator` (R4): one audio player for the app,
  `shared` unless the host passes its own. `attach(id, source:)` gives
  a file's session, a `MediaReaderPlayback`, to a host that draws its
  own bar;
- `MediaReaderWaveform` (R4): peaks, progress and drag-to-seek;
- `MediaKind`: done in R0.

### 2.3 Engines by kind and platform

| Kind | Engine | iOS | Android | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- | --- |
| Picture | Flutter `Image` + `InteractiveViewer` | ✓ | ✓ | ✓ | ✓ | ✓ |
| Video | `video_player` API: native AVPlayer/ExoPlayer; `fvp` where there is none (MR3) | AVPlayer | ExoPlayer | AVPlayer | fvp | fvp |
| Audio | `just_audio`; `fvp` audio-only on the desktop (MR4) | just_audio | just_audio | just_audio | fvp | fvp |
| Waveform | `MediaReaderWaveform` from host peaks | ✓ | ✓ | ✓ | ✓ | ✓ |
| PDF | `pdfrx` (PDFium) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Office | the host's PDF derivative → `pdfrx` (MR7) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Text, code, JSON, XML | Flutter text, monospace, pretty print | ✓ | ✓ | ✓ | ✓ | ✓ |
| Markdown | `flutter_markdown_plus` (MR12) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Table (CSV, TSV) | a virtualised table | ✓ | ✓ | ✓ | ✓ | ✓ |
| Archive (zip, tar, gz) | read by the package itself, from a zip's end and a tar's headers; an entry opens through the registry (R6) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Anything else | the file's card | ✓ | ✓ | ✓ | ✓ | ✓ |

### 2.4 What stays in the host

- **Its design system:** the glass chrome, colours, type and icons.
  The package's defaults are plain.
- **Who shared it and where**, and its actions: reply, forward, star,
  share, save to device, report, delete. The package shows the host's
  widgets.
- **The audited resolve** that turns a file into a signed URL, and
  its authentication.
- **The policy's source:** Tendvine's community setting and the
  member's rights.
- **The cache directory:** per account, cleared on sign-out.
- **Recording voice notes**, and capturing their peaks while
  recording.

---

## 3. Decisions (MR)

| # | Decision | Status |
| --- | --- | --- |
| MR1 | Own public repository `Thirdval/flutter_media_reader`, Apache-2.0, consumed by Tendvine through a git tag, like `flutter_reader` | **Decided** 2026-09-30 |
| MR2 | Video through the `video_player` API with `fvp` as its engine | **Decided** 2026-09-30 |
| MR3 | `fvp` registered for Windows and Linux only (`registerWith(options: {'platforms': ['windows', 'linux']})`). iOS, Android and macOS keep AVPlayer/ExoPlayer: battery, AirPlay, picture in picture, HDR. Widen to every platform only if codecs the native players refuse (webm/mkv on iOS) turn up in practice | Recommended |
| MR4 | Audio behind one `AudioEngine`: `just_audio` on iOS, Android and macOS (audio session, interruptions); `video_player`/`fvp` audio-only on Windows and Linux | Recommended |
| MR5 | PDF on `pdfrx` (PDFium, MIT, every platform; `PdfViewer.uri` takes auth headers, range access and progressive loading) | Recommended |
| MR6 | Waveform peaks come from the host: the server computes them at upload, in-app recordings capture them while recording. No on-device extraction before 1.0; without peaks the bar shows a plain progress track | Recommended |
| MR7 | Office formats are never parsed here: the host hands a PDF derivative as `preview`. Tendvine's server makes it in a separate converter container (B2) | **Decided** 2026-09-30 |
| MR8 | Nothing leaves the app: no `url_launcher`, `open_filex`, `share_plus` or other hand-off in `lib/` (a test reads the pubspec); export is only ever the host's action | **Decided** 2026-09-30 |
| MR9 | Download policy: the host says whether export is allowed and where engines may cache. With export off, the chrome hides Share and Save and nothing is kept on disk. Copying text is not an export, in any kind of file: it stays allowed with export off. Tendvine's comes from a community setting (B3) | **Decided** 2026-09-30 |
| MR10 | The package draws a plain default chrome; hosts supply theirs through slot builders | Recommended |
| MR11 | Sources resolve through the host (signed URLs, auth headers, the audited resolve); engines stream. The package owns no HTTP client beyond what an engine needs | Recommended |
| MR12 | Markdown on `flutter_markdown_plus`; links go to the host's handler, never to a browser | Recommended |
| MR13 | Git tags only until 1.0; pub.dev at R10 | Recommended |
| MR14 | Tests: unit and widget tests with fake engines and sources; each adapter behind its interface; a manual platform matrix in the tracker; no goldens until the chrome settles | Recommended |

The owner accepts or overrides each Recommended row; the session
records the answer here. MR5 was built on `pdfrx` as recommended, but
not on `PdfViewer.uri`: R5 says why. MR7's answer and the copy clause in MR9,
for PDFs, reached this session through Tendvine's backend session on
2026-09-30. The owner widened the clause to every kind of file in this
session the same day.

---

## 4. Phases

### 4.0 Standing rules for every phase

- **Tests:** every public behaviour has one. `fvm flutter analyze
  --fatal-infos` is clean, and `lib/` files stay at or under 400 lines.
- **Documentation:** the example app shows the new kind, and the
  README's section for it is written from the tests.
- **Tracker:** the phase's row in §5 is updated in the same commit.
  A phase ends with a tag (`v0.N.0`) that Tendvine can pin.
- **Platform matrix:**
  - Android on a Pixel, macOS on the owner's Mac, iOS on the owner's
    iPhone (the owner runs iOS builds);
  - Windows and Linux from R3 on, when a machine or CI is available;
  - write down what was not run, rather than assuming it.

### R0 — Scaffold (S) · done

- **Built:** a public repository and Flutter 3.47.5 pinned through
  fvm. It has Tendvine's lints (primary constructors among them), a CI
  workflow (analyze, format, test) and an example app for all five
  platforms. It also has `MediaKind` with its detection rules and
  tests, this plan, CLAUDE.md, the README and the CHANGELOG.
- **Done when:** analyze is clean, the tests pass, and the example
  builds.

### R1 — Core and shell (L) · built

- **Types:**
  - `MediaReaderItem`, `MediaReaderSource` (remote, which re-resolves
    after a refusal; file; bytes), `MediaReaderPolicy`,
    `MediaReaderCache`;
  - `MediaReaderEngine`, the ordered `MediaReaderEngines` registry,
    and the file's card engine.
- **The shell:**
  - `showMediaReader` and `MediaReaderView`;
  - paging with neighbours prepared and far pages released;
  - drag to dismiss; Esc and the arrow keys; the chrome toggled by a
    tap;
  - the chrome slots with plain defaults, and `MediaReaderChrome`;
  - semantics: each page announced; slots in reading order.
- **Guard:** a test that fails when the pubspec gains a hand-off
  dependency (MR8).
- **Example app:** fake engines and sources show every kind as its
  card.
- **Done when:**
  - a host can open a list of items, page, dismiss and fill every slot;
  - an unknown kind shows its card;
  - with `canExport: false` the chrome learns it;
  - tests cover the registry order, the fallback, re-resolution after
    an expired URL, and disposal.
- **Built (2026-09-30):**
  - the contract as §2.2 now states it, with what R1 settled beyond
    the sketch listed there;
  - 117 tests, with fake engines and sources; the guard reads the
    pubspec and every import under `lib/`;
  - the example opens its samples in the reader, under a host's chrome
    or the plain defaults, with export on or off; its integration test
    ran on a Pixel 10a (Android 17) and on macOS;
  - built on MR10, MR11 and MR14 as recommended: those rows still wait
    for the owner.
- **Left for later phases:**
  - no engine exists yet, so every file shows its card;
  - a slot for an engine's transport controls comes with R3 (the
    retry from the card came with R2);
  - iOS was not run (the owner runs iOS builds), nor Windows or Linux
    (no machine; planned from R3).

### R2 — Pictures (M) · built

- **Engine:** `InteractiveViewer`.
  - Pinch, double-tap and wheel zoom; pan within bounds; the zoom
    resets when the page changes; dismiss only at rest scale.
- **Decoding:** at screen size (`ResizeImage`); animated GIF and WebP;
  the poster until the first frame.
- **Loading:** a host hook for the image provider (to reuse a host's
  cache).
- **Fallback:** SVG and undecodable files go to the card.
- **Done when:** a 50 MP photo opens without a memory spike, zoom and
  dismiss never fight, and the tests cover the gesture states.
- **Built (2026-09-30):**
  - `MediaReaderPictureEngine`: JPEG, PNG, GIF, WebP, BMP and ICO on
    every platform; HEIC and TIFF on iOS and macOS, and a HEIC
    elsewhere through its preview (the server's JPEG);
  - a picture is decoded to fit the screen; zoomed into, again with
    the detail the zoom shows, never past 4096 pixels on its longest
    side; a file over 64 MB is not fetched. The three numbers are the
    engine's parameters, and are in the README;
  - a 48-megapixel JPEG (8000 by 6000) was decoded at 1080 by 810 on
    the Pixel and within the window on macOS;
  - at rest a drag is the shell's; zoomed, or with two fingers down,
    it is the picture's. On a phone the picture's own recognizer took
    any quick flick, because it is the deeper one and a phone's pan
    slop is small: at rest its pan slop is now out of reach, and a
    pinch is judged by the change of span;
  - a remote picture is fetched by the package (`MediaReaderFetcher`
    over a `MediaReaderTransport`, `dart:io` by default), at the
    location the page keeps, renewed once on 401, 403 or 410, and
    known to the image cache by the file's id;
  - the host's image provider is asked only while export is allowed:
    a host's cache is usually on disk (MR9);
  - the neighbours' pictures are fetched ahead, as §2.1 says. A host
    that meters its resolves turns that off (`prepareNeighbours`);
  - the card offers "Try again" after a failure;
  - the example serves its bundled samples from a loopback server that
    signs, expires and ranges as a CDN would; 182 tests.
- **Left for later phases:** zooming by keyboard and the semantics of
  zoom (R8); an animated picture on a neighbour page keeps decoding
  its frames.

### R3 — Video (M) · built

- **Engine:** `video_player`, with `fvp` registered for Windows and
  Linux (MR3), streaming from the resolved URL with its headers.
- **Controls:** play and pause, scrub, elapsed and remaining time,
  mute, speed, loop off; the poster until the first frame; a
  buffering state.
- **Playback:** paused when paged away, disposed when released;
  resumes after a re-resolve (expired URL) at the same position.
- **Errors:** they go to the card with the reason.
- **Done when:** an MP4 plays and seeks on Android, iOS and macOS, and
  on Windows and Linux through `fvp` where a machine is available. Two
  videos in a row never play at once, and the tests use a fake
  controller.
- **Built (2026-09-30):**
  - `MediaReaderVideoEngine` on `video_player` 2.14 and `fvp` 0.39.
    `fvp` registers itself on Windows and Linux, so MR3's split is its
    default and the package calls nothing;
  - what each player plays is a table in the engine (MP4, MOV and HLS
    everywhere; WebM and Matroska on Android and the desktop; AVI and
    WMV through libmdk). A format the platform does not play is shown
    through its preview: a WebM played through its MP4 on macOS, and
    as it is on the Pixel;
  - a neighbour shows its poster and asks for nothing; a video is
    resolved and opened when its page comes on screen; it stops when
    the page is left, and two never play at once;
  - a location that has run out is renewed before a play or a seek,
    and once when the player gives up under way; the video goes on
    where it was. On both devices a URL was let run out under a paused
    video, and the video went on from the same place at a second
    signature;
  - `MediaReaderPlayback` and the chrome's `controls` slot (§2.2): the
    transport is the host's to draw, and the package's plain one is
    the default;
  - the tests run the real `video_player` controller on a pretend
    platform; 225 tests.
- **Not run:** iOS (the owner runs iOS builds); Windows and Linux (no
  machine), so `fvp` has been built into the macOS and Android apps
  but has played nothing yet.
- **Left for later phases:** the keyboard for play and seek (R8);
  picture in picture (R8, and it needs a decision: `video_player`
  offers none on iOS or Android).

### R4 — Audio and waveform (M) · built

- **Engine:** `AudioEngine` (MR4), with one player at a time across
  the app (a coordinator the host can share).
- **`MediaReaderWaveform`:**
  - peaks drawn as bars, progress coloured, drag to seek;
  - slider semantics;
  - a plain track without peaks.
- **Controls:** speed 1×, 1.5×, 2×, and the duration from the host or
  the engine.
- **Interruptions:** audio-session interruptions and ducking (calls,
  other apps).
- **`MediaReaderAudioBar`:** the inline form, for a chat's voice notes.
- **Done when:** an m4a, mp3, ogg/opus or wav file plays and seeks on
  each platform in the matrix. A voice note inline and the same file
  in the reader share one player. The waveform tests cover peaks,
  none, and seeking.
- **Built (2026-09-30):**
  - `MediaReaderAudioEngine` on `just_audio` 0.10 for iOS, Android and
    macOS, and on the `video_player` API for Windows and Linux, where
    `fvp` plays a file that has no picture. That is MR4 as
    recommended: the row still waits for the owner;
  - what each player plays is a table in the engine: MP3, M4A, AAC,
    WAV and FLAC everywhere; Ogg, Opus and AMR on Android and the
    desktop; AIFF where AVPlayer or libmdk plays. An Ogg played as it
    is on the Pixel, and through its MP3 on macOS;
  - `MediaReaderAudioCoordinator`: one audio player for the app. A
    file that starts stops the one that was playing, which keeps its
    place. A video that starts in the reader stops the audio, and the
    other way round: one sound at a time across both engines;
  - `MediaReaderAudioBar`, the inline form. It and the reader's page
    for the same file are one session. On both devices a voice note
    was played and paused in its bubble, went on in the reader from
    the same place on the one signature, was paused there, and went on
    again in the bubble;
  - `MediaReaderWaveform`: bars from the host's peaks, however many
    there are, and a plain track without; a tap or a drag seeks; a
    slider to a screen reader. The plain transport scrubs along it;
  - a location that has run out is renewed before a play or a seek,
    and once when the player gives up under way, as for video. On both
    devices a URL was let run out under a paused MP3, and it went on
    from the same place at a second signature;
  - a location's headers go to the platform's player with the URL.
    `just_audio`'s default sends them through a plain-HTTP proxy on
    the device, which the host would have had to allow;
  - 304 tests, with pretend players behind the engine's interface.
- **The audio session is the host's.** `just_audio` pauses for an
  interruption and lowers the sound where the system says to. The
  session's category is one setting for the whole app, and a host may
  record or make calls as well, so the package sets nothing (A4 in
  §6). Nothing shows on the lock screen, and no background mode is
  asked for.
- **Not run:**
  - iOS (the owner runs iOS builds). The silent switch and an
    interruption by a call are the things to try there;
  - an interruption on Android: the integration test cannot make one;
  - Windows and Linux (no machine): audio through `fvp` has played
    nothing yet.
- **Left for later phases:** the keyboard for play and seek (R8).

### R5 — PDF (M) · built

- **Engine:** `pdfrx`, from a URI (headers, range access, progressive
  loading), bytes or a file.
- **Viewing:**
  - continuous pages, with a "1 of N" status for the chrome;
  - a page-thumbnails strip or sheet, and go to a page;
  - zoom.
- **Text:** search and selection. Copying stays allowed under a
  no-download policy: it is not an export (owner, 2026-09-30).
- **Poster:** where a PDF needs one, the engine draws the first page
  itself; the server makes no PDF thumbnails (owner, 2026-09-30).
- **Passwords:** a host hook.
- **Cache:** `pdfrx`'s download cache points to the host's directory
  or memory (check its cache hook).
- **Done when:** a 300-page PDF opens progressively and search finds
  text. Nothing is written outside the policy's cache.
- **Built (2026-09-30):**
  - `MediaReaderPdfEngine` on `pdfrx` 2.6 (PDFium), which is MR5 as
    recommended: the row still waits for the owner. One thing differs
    from the row and from the sketch above: the engine does not hand
    `pdfrx` the URL. It reads a remote file by ranges itself, through
    the package's fetcher, and gives `pdfrx` the bytes
    (`PdfDocument.openCustom`). So the location is the page's, kept
    and renewed as for every other kind; nothing goes to `pdfrx`'s own
    download cache; and a signed URL is never in `pdfrx`'s log lines;
  - ranges of 256 KB. The first page is up after two of them, the
    file's first and its last. A test holds the middle of a file back
    and the first page still shows. On both devices the example's
    rota, 300 pages in 1.8 MB, opened by ranges on one signature, and
    went to page 300 by its number;
  - the ranges are kept where the policy says: held while the file is
    open (none), between showings up to 64 MB for the app (memory), or
    in two files named after the item's id in the host's directory.
    With export off nothing is on disk. The tests read the host's
    directory and `pdfrx`'s own, which stays empty;
  - a range that stalls is given up on after a minute, and closing the
    page fails a waiting read at once: PDFium has one thread for every
    document, so one stalled read would hold up every PDF;
  - the contract grew (§2.2): `MediaReaderDocument` on the page and in
    the slots' state; `onLink`; `contentInsets`, so that a PDF's first
    page starts below the top slots; the plain title has a plate, to
    be read over a white page;
  - the plain controls for a document: a strip of pages drawn small
    with a field for a page's number, and a search that says "2 of 17"
    and steps through the matches. On both devices "Harvest supper"
    was found on three of the rota's 300 pages;
  - selected text has a menu of Copy and Select all and nothing else,
    and is copied with export off too (MR9);
  - a link to a place in the document goes there. A web address goes
    to the host's `onLink`, and without one is not a link;
  - a host hook for a password, asked again while the answer is wrong.
    A PDF that stays locked shows its card;
  - the poster: the engine draws any page small (`thumbnail`), the
    first among them. The server makes none (owner, 2026-09-30);
  - 395 tests. The PDF tests run the real PDFium, the library
    `flutter test` builds for the host, on PDFs made on the spot, one
    of them protected.
- **`url_launcher` comes with `pdfrx`.** It is there for the banner
  `pdfrx` shows when a document fails, which links to a web page. The
  engine replaces that banner, so nothing in this package reaches the
  plugin; but a host's app links it. Two tests guard this: one fails
  if a viewer is built with the default banner, the other if any
  other hand-off package arrives with a dependency (MR8, §7).
- **Not run:** iOS (the owner runs iOS builds); Windows and Linux (no
  machine); a screen reader over a PDF's text, which `pdfrx` exposes
  when one is on.
- **Known limits:**
  - a drag down scrolls a PDF and does not dismiss it: the close
    button and Esc do;
  - a sideways drag over a PDF at its width goes between files when it
    starts as a finger does, from rest. A jump of more than twice the
    touch slop in one step is taken by the page;
  - a page reached with Page Down may come under the top slots until
    the chrome is tapped away (a match gone to by the search comes
    below them since R8);
  - the outline (bookmarks) is not shown.

### R6 — Text, tables, archives (M) · built

- **Text:**
  - encoding detection (UTF-8, UTF-16 with BOM, Latin-1 fallback);
  - monospace for code, a wrap toggle;
  - JSON and XML pretty-printed;
  - a size cap with paging for large files.
- **Markdown** (MR12).
- **Tables:** CSV and TSV as a virtualised table with a header row and
  delimiter detection.
- **Archives:** zip, tar and gz listed with sizes. An entry opens
  through the registry (within a size cap), and nested archives list
  in turn.
- **Copying:** where text can be selected, copying it stays allowed
  under a no-download policy: it is not an export, in any kind (owner,
  2026-09-30). The owner accepts that Select All then Copy takes a
  text or CSV file's whole content.
- **Done when:** a 20 MB log and a 100,000-row CSV scroll smoothly,
  and a zip entry opens in its own engine.
- **Built (2026-09-30):**
  - `MediaReaderTextEngine`: a file's bytes as they come, by ranges
    for a remote file, with the lines found as the bytes arrive and
    decoded only when shown. A 20 MB log is a buffer and an index of
    line starts; only the lines on screen are built. UTF-8, UTF-16 by
    its mark, Windows-1252 as the fallback; a tab is four columns;
    a line of megabytes is shown as several;
  - prose in the reader's own face, wrapped at its words; everything
    else in a face of equal widths, laid out in rows of one height
    and wrapped at the column as a terminal does, so a long text
    scrolls and jumps to a place as a short one; the Wrap toggle
    turns it off. JSON and XML laid out to be read up to 1 MB, every
    value as the file has it;
  - a search through every line, a few thousand a frame, marked on
    the lines; Copy and Select all, with Select all the whole file
    up to 1 MB; what is copied from several lines has its breaks;
  - `MediaReaderMarkdownEngine` on `flutter_markdown_plus` 1.0
    (MR12 as recommended: the row still waits for the owner). Links
    to the host's `onLink`, images never fetched, the file as written
    on a toggle, and above 1 MB from the start;
  - `MediaReaderTableEngine` on `two_dimensional_scrollables` 0.5: the
    delimiter from the first rows, quoted cells with line breaks, the
    header row pinned, cells built where they are on screen, a search
    that goes to the row. A hundred thousand rows opened on both
    devices and went to the last row by its key;
  - `MediaReaderArchiveEngine`: zip, tar and gzip. The package reads
    the formats itself, with `dart:io`'s zlib: a zip's list is at its
    end and a tar's in its headers, so a remote archive is listed
    after a few ranges and only the entry opened is fetched, which the
    `archive` package cannot do with a stream it has not got whole.
    That package makes the tests' archives instead. An entry opens
    through the registry in a reader over this one, with the same
    chrome, policy and engines: a zip in a zip lists in its turn;
  - `MediaReaderToggle` in the document's state, `MediaReaderPage.
    engines`, `MediaReaderByteLoader` and `MediaReaderReadAt`: what an
    engine needs to load a file and to show another;
  - 510 tests. The example's integration test (twenty-nine) ran on a
    Pixel 10a (Android 17) and on macOS: a sermon searched, a log of
    thirty thousand lines from a file, a table of a hundred thousand
    rows, a README whose link reached the host, JSON laid out, a zip
    whose picture opened in a reader over the reader, a gzipped tar.
- **Not run:** iOS (the owner runs iOS builds); Windows and Linux (no
  machine); a screen reader over a long text.
- **Known limits, left for R8 or later:**
  - a video or an audio file inside an archive shows its card: an
    entry is bytes in memory, and those players take a file or a URL;
  - 7z and rar show their card;
  - Select all in a text over 1 MB, or a table over 1 MB, selects
    what is built, not the file;
  - a table is not scrolled sideways by the keyboard, and its cells
    are not selected across a scroll;
  - the tests run the real widgets, the real zlib and the real
    formats, on files made on the spot; no goldens (MR14).

### R7 — Derivatives: Office and HEIC via the host (S) · built

- **Preview:** `MediaReaderItem.preview` is shown by its own kind's
  engine (an Office file's PDF through `pdfrx`, a HEIC's JPEG as a
  picture); the registry has chosen it that way since R1. States for
  "being prepared" and "could not be prepared", with retry.
- **Done when:** a docx with a PDF preview reads as the PDF, and one
  without shows its card saying so.
- **Built (2026-09-30):**
  - `MediaReaderPreview` has a state: ready, preparing or failed, as
    the backend's `derivatives` says (§6, B2 and B4). A ready preview
    is shown by its own kind's engine, as the registry has done since
    R1; a preview being prepared shows the file's card with a ring and
    the words, one that failed shows the card with its words; neither
    offers a retry, since the server is not asked again by the reader;
  - `showMediaReader(liveItems:)`: the reader follows the host's items
    while it is open, so that the push the host hears
    (`attachment.updated`) turns the card into the file where it
    stands. `MediaReaderView` did that already when rebuilt;
  - the example shows an Office file through a PDF, and one whose PDF
    a switch finishes; on both devices the card gave way to the PDF
    while the reader was open. 516 tests.
- **Not run:** iOS; Windows and Linux; a real `docx` through
  Tendvine's converter (that is R9, in Tendvine's session).
- **Left for R9:** the mapping from the backend's `derivatives` and
  the resolve of `variant: pdf` or `display` to items, which is the
  host's.

### R8 — Platform polish (M) · built

- **Desktop:**
  - keyboard shortcuts (zoom, page, play);
  - pointer and wheel;
  - right-click menus (host actions);
  - a wide-screen layout with a thumbnails rail.
- **Accessibility:** RTL, reduced motion, 200 % text, TalkBack and
  VoiceOver passes.
- **Mobile video:** picture in picture.
- **iOS Live Text** on pictures: VisionKit needs native code, so this
  is a decision for the owner before any plugin is written.
- **Done when:** the matrix in §5 is filled for every kind, with gaps
  named.
- **Built (2026-09-30):**
  - the keys: the space bar plays and pauses, M mutes, Shift with an
    arrow seeks ten seconds, on whatever plays on the page on screen;
    + and − zoom a picture about its middle and 0 fits it again, a
    key pressed while the last zoom glides adding to where it is
    going. A key typed into a field is the field's, and the space bar
    on a button the button's. Page Up and Page Down, Home and End were
    a PDF's and a text's already (R5, R6), and the arrows the shell's
    (R1);
  - `MediaReaderChrome.menu` (§2.2): the host's actions for the file
    on screen, on a right-click or a long press with a finger, never
    a mouse held down. The reader draws them in the chrome's colours
    where the pointer is, above a finger, within the reader; a tap
    elsewhere or Esc closes the menu, and so does paging away, and
    the keys go back to where they were. What is under the menu is
    not read by a screen reader while it is up. An engine's own menu
    over text stands: a long press on a word selects it (R6), and a
    right-click on a PDF gives its Copy and Select all (R5);
  - the rail of files, `railFromWidth` (§2.2): from 900 pixels across
    a rail stands at the start of the reader, at the end right to
    left, with every file by its poster or its extension, the one on
    screen outlined, a tap going to it — at once past a neighbour, so
    the pages between are not brought on screen on the way. It scrolls
    only as far as it must to keep the file on screen in view, hides
    and returns with the chrome, and fades with a dismissing drag.
    `double.infinity` removes it;
  - less motion: a PDF's page or match gone to is there at once, as
    the pager, a picture's zoom, the dismissal, the chrome, the strip
    of pages and the busy ring were already. The reader reads it from
    `MediaQuery.disableAnimations`, which is the platform's setting;
  - a match gone to by the search comes below the chrome's top slots
    and above its bottom ones, with a little room: the package's own
    searcher over `pdfrx`'s (`MediaReaderPdfSearcher`), which also
    paints the matches;
  - text at 200 %, on a phone 320 pixels wide: nothing overflows. The
    transport and the document bar grow to 150 % of the person's size,
    as a toolbar does, and take two rows below 340 and 280 pixels at
    that size (the scrubber above the buttons; the search's count and
    arrows under its field); the document bar's tools wrap; the strip
    of pages and the times shrink only where even that is too little.
    The card, the titles and the files' own text grow the whole way;
  - a screen reader: a picture is an image with the actions Zoom in,
    Zoom out and Fit to screen; the rail's files are buttons with
    "selected" on the one on screen; the menu is a group of buttons;
    the rail comes last in the reading order (`MediaReaderOrder.rail`);
  - right to left: the rail stands at the end, the shell pages
    mirrored (R1), the bars run left to right as every player's do;
  - 557 tests; two more integration tests (the menu, the rail).
- **Blocked, for the owner (native code, MR2):**
  - **picture in picture:** `video_player` offers none on iOS or
    Android. It needs either a plugin with native code (`AVPictureIn
    PictureController`, Android's `enterPictureInPictureMode` with the
    activity's manifest flag) or a fork. Nothing was written;
  - **iOS Live Text:** VisionKit's `ImageAnalysisInteraction` is
    native code. Nothing was written.
- **Not run:** iOS (the owner runs iOS builds), so no VoiceOver pass;
  a TalkBack pass on the Pixel with a person, which the integration
  test cannot make (it checks the semantics tree); Windows and Linux
  (no machine): the right-click, the rail and the keys were run on
  macOS only.
- **Left:** a table is not scrolled sideways by the keyboard (R6).

### R9 — Adoption in Tendvine (M; the Tendvine session)

Done in Tendvine, against a tag, in four steps.
- **R9a**, after R3:
  - Tendvine's file opener calls `showMediaReader`, and its
    `launchUrl` hand-off is deleted;
  - its gallery and video page are replaced;
  - the glass chrome fills the slots;
  - unknown kinds show the card.
- **R9b**, after R5: PDF.
- **R9c**, after R4:
  - audio files, and voice notes on `MediaReaderAudioBar`;
  - peaks captured while recording (the host's `record` amplitude
    stream).
- **R9d**, after R6 and R7: text, tables, archives, and Office through
  the backend's PDF.

In every step:
- Share and Save follow the community download policy (B3);
- the cache is per account and cleared on sign-out.

### R10 — 1.0 (S)

- **Documentation:** the README written from the tests, API docs, and
  the CHANGELOG.
- **Licences:** a notice file for PDFium, libmdk and FFmpeg.
- **Size:** the example's added size per platform, measured and
  written down.
- **Release:** `v1.0.0`, and the pub.dev decision (MR13).

---

## 5. Tracker

| Phase | Title | Status | Commit / tag | Owner check |
| --- | --- | --- | --- | --- |
| R0 | Scaffold: repo, pins, lints, CI, example for five platforms, `MediaKind`, plan, CLAUDE.md | ☑ built 2026-09-30 — analyze clean, 5 tests, example builds for macOS | initial commit | ☐ |
| R1 | Core and shell: items, sources, policy, registry, pager, chrome slots, the card engine | ☑ built 2026-09-30 — analyze clean, 117 tests, example run on Android and macOS | `d2c235e`; tag `v0.1.0` when the owner asks | ☐ |
| R2 | Pictures | ☑ built 2026-09-30 — analyze clean, 182 tests, example run on Android and macOS | `c6ba3f5`; tag `v0.2.0` when the owner asks | ☐ |
| R3 | Video (`video_player` + `fvp`) | ☑ built 2026-09-30 — analyze clean, 225 tests, example run on Android and macOS | `ea38e36`; tag `v0.3.0` when the owner asks | ☐ |
| R4 | Audio and waveform, `MediaReaderAudioBar` | ☑ built 2026-09-30 — analyze clean, 304 tests, example run on Android and macOS | `9bbd4b5`; tag `v0.4.0` when the owner asks | ☐ |
| R5 | PDF (`pdfrx`) | ☑ built 2026-09-30 — analyze clean, 395 tests, example run on Android and macOS | `b2f1290`; tag `v0.5.0` when the owner asks | ☐ |
| R6 | Text, Markdown, tables, archives | ☑ built 2026-09-30 — analyze clean, 510 tests, example run on Android and macOS | `5dc5016`; tag `v0.6.0` when the owner asks | ☐ |
| R7 | Derivatives: Office and HEIC through the host | ☑ built 2026-09-30 — analyze clean, 516 tests, example run on Android and macOS | the 0.7.0 commit; tag `v0.7.0` when the owner asks | ☐ |
| R8 | Platform polish, accessibility, Live Text decision | ☑ built 2026-09-30 — analyze clean, 557 tests, example run on Android and macOS; PiP and Live Text blocked on the owner (native code) | the 0.8.0 commit; tag `v0.8.0` when the owner asks | ☐ |
| R9a–d | Adoption in Tendvine (the Tendvine session) | ☐ | | ☐ |
| R10 | 1.0 | ☐ | | ☐ |

**Platform matrix** (fill per phase: ✓ run, – not run, ✗ fails):

| Phase | iOS | Android | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| R0 | – | – | ✓ build | – | – |
| R1 | – | ✓ | ✓ | – | – |
| R2 | – | ✓ | ✓ | – | – |
| R3 | – | ✓ | ✓ | – | – |
| R4 | – | ✓ | ✓ | – | – |
| R5 | – | ✓ | ✓ | – | – |
| R6 | – | ✓ | ✓ | – | – |
| R7 | – | ✓ | ✓ | – | – |
| R8 | – | ✓ | ✓ | – | – |

Each ✓ is the example's integration test, run on a Pixel 10a with
Android 17 and on macOS 27. iOS was not run: the owner runs iOS
builds. Windows and Linux were not run: no machine.
- R1: four tests (open, page, close by key, by button and by drag,
  export on and off).
- R2: eight tests. Pictures from a signed URL, a file and bytes; a
  48-megapixel JPEG decoded within the screen; zoom; paging; a HEIC
  as it is on macOS and through its JPEG on Android; an expired URL
  resolved again.
- R3: eleven tests. An MP4 played, paused, sought and resumed by
  AVPlayer and by ExoPlayer; a URL renewed under a paused video; a
  WebM as it is on Android and through its MP4 on macOS.
- R4: seventeen tests. A voice note (M4A) played, paused, sought along
  its waveform and resumed; an MP3 from a signed URL and a WAV from a
  file; an Ogg as it is on Android and through its MP3 on macOS; a
  voice note shared between its bubble and the reader; a URL renewed
  under a paused MP3; a video that starts stopping the voice note.
- R5: twenty-two tests. A PDF of 300 pages opened by ranges and gone
  to its last page by number; a search through every page; the pages
  scrolled by a drag and the next file reached by a drag sideways; a
  protected PDF opened with the host's password, and left locked; a
  link handed to the host.
- R6: twenty-nine tests. A text searched; a log of thirty thousand
  lines gone to its end; a table of a hundred thousand rows with its
  header pinned; a README laid out, its link handed to the host; JSON
  laid out; a zip's folder opened and its picture shown in a reader
  over the reader; a gzipped tar listed.
- R7: thirty-one tests. An Office file shown through its PDF, its own
  bytes never asked for; one being prepared shown as its card, and as
  the PDF once the host said the server was done.
- R8: thirty-three tests. The host's menu opened by a right-click on
  macOS and a long press on the Pixel, its action the host's; on
  macOS, whose window is now 1100 wide, the rail with the file on
  screen marked and a text reached by a tap on it; on the Pixel, no
  rail.

Legend: ☐ not started · ◐ in progress · ☑ done (commit) · ✔ owner
verified · ⊘ blocked (reason). Update the row in the same commit as
the work.

**Order:**
1. R0, then R1.
2. R2 to R6 in any order, recommended as R2, R3, R5, R4, R6: pictures
   and video first let Tendvine drop the hand-off at R9a; PDF is the
   most common document.
3. R7 when the backend's derivatives exist.
4. R8.
5. R10.

R9 steps follow their phases.

---

## 6. Asks outside this repository

These asks belong to Tendvine's backend and app sessions.

**Backend (Tendvine API):**

On 2026-09-30 the owner said go on B1–B5, on the backend's
recommendations (relayed by Tendvine's backend session). The backend
works in this order: B5, the repair of old rows (posters, voice notes
that show 0:00), B1, B3, HEIC (B4), B2. Its session announces the
commit and a guide when each batch lands.

Later the same day Tendvine's app session reported all five live on
staging, with a guide for hosts:
`tendvine/docs/media_reader_integration.md`. Checked from this
repository's session: the guide, and that the commits it names are in
the backend repository (`2bc0b819`, `197f0d86`, `159da9e0`,
`19e69f44`, `dad7afc5`). Not run from here: any request against
staging.

- **B1 — Peaks and duration.** For audio and video, computed at upload
  and returned with the file. This also mends voice notes that show
  0:00.
  - Agreed shape: `peaks` is exactly 100 values, 0..1, to two
    decimals, and null until the file is processed; `durationSeconds`
    comes beside it.
  - Both are on the attachment, the list item and the resolve.
  - Status: reported live on staging (`197f0d86`, `dad7afc5`), with
    the old rows repaired. They also come with the room's
    `attachment.updated` push when processing ends.
- **B2 — A PDF derivative for Office files** (Word, Excel, PowerPoint,
  OpenDocument, RTF), resolved like thumbnails, with "preparing" and
  "failed" states.
  - Decided: a separate converter container makes it (MR7).
  - Status: reported live on staging (`159da9e0`). The variant is
    `pdf`, for ten formats, up to 50 MB, and it answers ranges. Its
    state is `derivatives.pdf`: `ready`, `preparing`, `failed` or
    `none`. A failed conversion is not tried again on its own. R7
    shows those states.
- **B3 — The community download policy.**
  - Agreed shape: a new permission, `files:export`, on in every role
    by default; `canExport` on the member's capabilities and on each
    resolve. It feeds `MediaReaderPolicy.canExport` (MR9).
  - A resolve carries its intent, `view` or `export`. A view is served
    inline; an export is audited and served as an attachment.
  - The CDN already accepts a signed disposition
    (`&disp=inline|attachment`); the backend starts sending it with
    B3.
  - Status: reported live on staging (`197f0d86`). The package's
    policy takes the one bool, `canExport`; the intent and the refusal
    (`File.ExportNotAllowed`) stay on the host's side.
- **B4 — Derivatives the reader relies on:** video posters, and a JPEG
  `display` variant of each HEIC/HEIF (decided; R7 relies on it), all
  actually served.
  - Not PDF previews: the server makes no PDF thumbnails, and the
    reader draws a PDF's first page itself (R5).
  - Status: reported live on staging (`159da9e0`). The `display`
    variant is a JPEG of at most 2560 pixels for HEIC, HEIF, AVIF and
    TIFF, with `derivatives.display` as its state. A variant that was
    never made is no longer signed.
- **B5 — Range requests** on signed URLs, for streaming, seeking and
  PDF range access.
  - Status: live on staging since 2026-09-30 (backend commit
    `2bc0b819`).
  - The backend session reports that every signed `cdn.tendvine.io`
    URL answers 206 with `Content-Range` (open-ended and suffix ranges
    too), 416 past the end, HEAD with `Content-Length`, and
    `Accept-Ranges: bytes`; and that video seeking and `pdfrx`'s range
    access work against staging.
  - Checked from this repository's session: the Worker's source at
    that commit. Not run from here: a request against the live edge.

**App (Tendvine client):**
- **A1:** R9a–R9d as above.
- **A2:** capture peaks while recording voice notes.
- **A3:** an account-scoped reader cache, cleared on sign-out.
- **A4:** the audio session's category, set once by the app with
  `audio_session` (R4). The reader sets nothing: the app records voice
  notes as well, and the category is one setting for all of it. Left
  at its default, an iPhone plays nothing while its silent switch is
  on.

---

## 7. Risks and open questions

- **libmdk licence (`fvp`'s engine):** closed-source commercial use
  needs a licence key. The mdk-sdk README lists Flutter users as
  covered ("key already included"). Get that confirmed in writing by
  its author before Tendvine ships to the stores. If it cannot be,
  `media_kit` (libmpv, LGPL) is the desktop fallback behind the same
  interface.
- **App size:** `fvp` bundles libmdk and FFmpeg, and not only on
  Windows and Linux: its pod and its Android library are linked into
  the iOS, macOS and Android builds too, though it plays nothing
  there. `pdfrx` bundles PDFium on every platform. Measure in R10.
- **Codecs:** AVPlayer refuses webm and mkv. See MR3's condition for
  widening `fvp`. Since R3 such a file is shown through its preview
  (the server's MP4) where the host gives one, which may make the
  widening unnecessary.
- **Expiring URLs** mid-playback or mid-PDF: re-resolve and resume
  (R1 contract, tested in R3 and R5).
- **Large files:** caps and virtualisation in R2, R5 and R6. The
  numbers go in the README. R2's are there: the screen's size at rest,
  4096 pixels on the longest side when zoomed, 64 MB fetched.
- **Where engines write:** `pdfrx` downloads and any player cache must
  land in the policy's cache or memory. Verify each engine in its
  phase. Since R5 `pdfrx` downloads nothing: the PDF engine reads the
  file itself and keeps its ranges where the policy says, and the
  tests read both directories.
- **`url_launcher` in the host's app:** `pdfrx` depends on it for its
  own error banner. The PDF engine never shows that banner, and no
  code of this package reaches the plugin (R5, with two guard tests);
  but the plugin is linked into every host. If that is not acceptable,
  the ways out are a change upstream to make it optional, or a fork of
  `pdfrx` without the banner: an owner decision.
- **Copy and export:** settled by the owner on 2026-09-30. Copying
  text is not an export, in a PDF or any other kind of file, so it
  stays allowed under a no-download policy (MR9, R5, R6).
- **Live Text:** it needs native code on iOS (VisionKit). An owner
  decision in R8.

---

## Appendix A — Engines checked on 2026-09-30

| Package | Version then | Platforms | Licence | Notes |
| --- | --- | --- | --- | --- |
| [`fvp`](https://pub.dev/packages/fvp) | 0.39.0 (published that day) | Android, iOS, macOS, Windows, Linux | BSD-3-Clause; libmdk needs a licence key for closed-source commercial use; Flutter users are listed as covered ([mdk-sdk](https://github.com/wang-bin/mdk-sdk)) | Backend for `video_player` through `registerWith`; `'platforms'` limits it; plays audio without video |
| [`video_player`](https://pub.dev/packages/video_player) | 2.14 (Tendvine) | Android, iOS, macOS, web | BSD-3-Clause | No Windows or Linux implementation of its own |
| [`just_audio`](https://pub.dev/packages/just_audio) | 0.10 (Tendvine) | Android, iOS, macOS, web | MIT | Desktop through community backends |
| [`pdfrx`](https://pub.dev/packages/pdfrx) | 2.6.5 (about 11 days old) | Android, iOS, macOS, Windows, Linux, web | MIT (PDFium) | `PdfViewer.uri(headers:, preferRangeAccess:, useProgressiveLoading:)`, `PdfViewer.data` |
| [`media_kit`](https://pub.dev/packages/media_kit) | 1.2.6 (about 9 months old) | all | MIT; bundles libmpv/FFmpeg | Considered for video and audio; set aside for MR2, kept as the libmdk fallback |
