# flutter_media_reader — Plan of Record

One in-app reader for every file a host hands it — pictures, video,
audio with its waveform, PDF, Office documents (through a PDF the
host makes), text, tables and archives — on iOS, Android, macOS,
Windows and Linux, each kind shown by an engine that can be swapped
per platform. Files never leave the app: exporting is the host's
action, under the host's policy.

**Status:** accepted by the owner on 2026-09-30. R0 (this scaffold)
and R1 (the core and the shell) were built the same day; both wait for
the owner's check. R1 onward belong to this repository's own session.
Progress is tracked in §5, one row per phase, updated in the same
commit as the work, with an owner check after each phase.

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
- R2–R6 one kind of file each: pictures, video, audio with waveform,
  PDF, text/tables/archives.
- R7 Office and HEIC through the host's derivatives.
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
  required final MediaReaderSource source,
  final String? contentType,
  final String? name,
  final MediaKind? kind,
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
  cardActions, // the host's actions on a file's card
  background, foreground,
  strings, // the words the package draws or speaks
});

// What a slot is told.
class const MediaReaderState({
  item, index, count, policy, // and canExport
  status, // the engine's own
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
  final ValueNotifier<bool> holdsPaging; // it owns sideways drags
  final ValueNotifier<bool> holdsDismiss; // and downward ones
  Future<MediaReaderLocation> resolve(); // the kept location
  Future<MediaReaderLocation> renew(MediaReaderLocation refused);
  void fail(String reason); // the card takes the engine's place
}
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
- `MediaReaderAudioBar`: the inline player a chat shows for a voice
  note;
- `MediaReaderWaveform`: peaks, progress and drag-to-seek;
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
| Archive (zip, tar, gz) | `archive`: list, then preview an entry through the registry | ✓ | ✓ | ✓ | ✓ | ✓ |
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
records the answer here. MR7's answer and the copy clause in MR9,
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
  - a retry from the card comes with R7, and a slot for an engine's
    transport controls with R3;
  - iOS was not run (the owner runs iOS builds), nor Windows or Linux
    (no machine; planned from R3).

### R2 — Pictures (M)

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

### R3 — Video (M)

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

### R4 — Audio and waveform (M)

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

### R5 — PDF (M)

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

### R6 — Text, tables, archives (M)

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

### R7 — Derivatives: Office and HEIC via the host (S)

- **Preview:** `MediaReaderItem.preview` is shown by its own kind's
  engine (an Office file's PDF through `pdfrx`, a HEIC's JPEG as a
  picture); the registry has chosen it that way since R1. States for
  "being prepared" and "could not be prepared", with retry.
- **Done when:** a docx with a PDF preview reads as the PDF, and one
  without shows its card saying so.

### R8 — Platform polish (M)

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
| R1 | Core and shell: items, sources, policy, registry, pager, chrome slots, the card engine | ☑ built 2026-09-30 — analyze clean, 117 tests, example run on Android and macOS | the 0.1.0 commit; tag `v0.1.0` when the owner asks | ☐ |
| R2 | Pictures | ☐ | | ☐ |
| R3 | Video (`video_player` + `fvp`) | ☐ | | ☐ |
| R4 | Audio and waveform, `MediaReaderAudioBar` | ☐ | | ☐ |
| R5 | PDF (`pdfrx`) | ☐ | | ☐ |
| R6 | Text, Markdown, tables, archives | ☐ | | ☐ |
| R7 | Derivatives: Office and HEIC through the host | ☐ | | ☐ |
| R8 | Platform polish, accessibility, Live Text decision | ☐ | | ☐ |
| R9a–d | Adoption in Tendvine (the Tendvine session) | ☐ | | ☐ |
| R10 | 1.0 | ☐ | | ☐ |

**Platform matrix** (fill per phase: ✓ run, – not run, ✗ fails):

| Phase | iOS | Android | macOS | Windows | Linux |
| --- | --- | --- | --- | --- | --- |
| R0 | – | – | ✓ build | – | – |
| R1 | – | ✓ | ✓ | – | – |

R1 was run as the example's integration test (four tests: open, page,
close by key, by button and by drag, export on and off) on a Pixel 10a
with Android 17 and on macOS 27. iOS was not run: the owner runs iOS
builds. Windows and Linux were not run: no machine.

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

- **B1 — Peaks and duration.** For audio and video, computed at upload
  and returned with the file. This also mends voice notes that show
  0:00.
  - Agreed shape: `peaks` is exactly 100 values, 0..1, to two
    decimals, and null until the file is processed; `durationSeconds`
    comes beside it.
  - Both are on the attachment, the list item and the resolve.
  - Status: the next backend batch, after the repair of old rows.
- **B2 — A PDF derivative for Office files** (Word, Excel, PowerPoint,
  OpenDocument, RTF), resolved like thumbnails, with "preparing" and
  "failed" states.
  - Decided: a separate converter container makes it (MR7).
  - Status: last in the backend's order.
- **B3 — The community download policy.**
  - Agreed shape: a new permission, `files:export`, on in every role
    by default; `canExport` on the member's capabilities and on each
    resolve. It feeds `MediaReaderPolicy.canExport` (MR9).
  - A resolve carries its intent, `view` or `export`. A view is served
    inline; an export is audited and served as an attachment.
  - The CDN already accepts a signed disposition
    (`&disp=inline|attachment`); the backend starts sending it with
    B3.
  - Status: the next backend batch, after B1.
- **B4 — Derivatives the reader relies on:** video posters, and a JPEG
  `display` variant of each HEIC/HEIF (decided; R7 relies on it), all
  actually served.
  - Not PDF previews: the server makes no PDF thumbnails, and the
    reader draws a PDF's first page itself (R5).
  - Status: old posters are repaired in the next batch; HEIC comes
    after B3.
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

---

## 7. Risks and open questions

- **libmdk licence (`fvp`'s engine):** closed-source commercial use
  needs a licence key. The mdk-sdk README lists Flutter users as
  covered ("key already included"). Get that confirmed in writing by
  its author before Tendvine ships to the stores. If it cannot be,
  `media_kit` (libmpv, LGPL) is the desktop fallback behind the same
  interface.
- **App size:** `fvp` bundles libmdk and FFmpeg on Windows and Linux;
  `pdfrx` bundles PDFium on every platform. Measure in R10.
- **Codecs:** AVPlayer refuses webm and mkv. See MR3's condition for
  widening `fvp`.
- **Expiring URLs** mid-playback or mid-PDF: re-resolve and resume
  (R1 contract, tested in R3 and R5).
- **Large files:** caps and virtualisation in R2, R5 and R6. The
  numbers go in the README.
- **Where engines write:** `pdfrx` downloads and any player cache must
  land in the policy's cache or memory. Verify each engine in its
  phase.
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
