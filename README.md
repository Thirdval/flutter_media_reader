# flutter_media_reader

An in-app reader for the files your app hands it: pictures, video,
audio with waveforms, PDF, Office documents (through a PDF your server
makes), text, tables and archives, on iOS, Android, macOS, Windows and
Linux.

> **Status: pre-release (phase R7).** The reader's shell, its host
> contract, and the engines for pictures, video, audio, PDF, text,
> Markdown, tables and archives are in, and Office files show through
> the PDF your server makes of them. What is left before 1.0 is the
> platform polish of R8. Progress:
> [MEDIA_READER_PLAN.md](MEDIA_READER_PLAN.md) §5.

## Principles

- **Files never leave the app.** The reader never hands a file to
  another app or the browser. Exporting (share, save to device) is
  your action, shown only when your policy allows it. Engines cache
  only where your policy says. A link in a file is handed to you, and
  the reader opens nothing itself.
- **One reader, swappable engines.** Each kind of file is shown by an
  engine, an adapter over a maintained plugin, chosen per platform.
  When no engine can show a file, the reader shows the file's card.
- **Your chrome.** The reader offers slots (who shared it, close,
  actions, more, a context pill, an engine's status such as
  "1 of 15") and a plain default for each. Your app fills them with
  its own design.
- **Your sources.** Files are reached through your app: a signed URL
  resolved when it is needed and again when it expires or is refused,
  a local file, or bytes.

## Opening the reader

```dart
await showMediaReader(
  context,
  items: [
    for (final file in files)
      MediaReaderItem(
        id: file.id,
        name: file.name,
        contentType: file.contentType,
        size: file.size,
        source: MediaReaderSource.remote(() => resolve(file)),
        data: file, // handed back to your chrome
      ),
  ],
  initialIndex: tapped,
  policy: MediaReaderPolicy(canExport: member.canExport),
  chrome: yourChrome,
  onLink: (link) => askBeforeOpening(link), // a web address in a PDF
);
```

The future completes when the reader is dismissed. The route is
see-through: the page beneath shows as the reader is dragged away.
`liveItems` lets the reader follow your items while it is open.

In the reader:

- **Paging.** A drag sideways goes between files. The two neighbours
  are built so they can prepare; pages further off are released.
- **Keyboard.** The arrows go between files, mirrored right to left.
  Esc dismisses.
- **Dismissing.** A drag down dismisses once it is long or fast
  enough, and settles back otherwise. A mouse does not drag; the close
  button and Esc are for it.
- **Chrome.** A tap on the canvas hides the chrome and another brings
  it back. With a screen reader or switch control it stays.
- **Accessibility.** Each page says its file and its place, and is
  announced when it comes on screen. The slots and the page come in
  reading order.

`MediaReaderView` is the same reader as a widget, for a pane:

```dart
MediaReaderView(
  items: items,
  onDismissed: null, // a pane that is always there
  autofocus: false, // leave the keyboard to the text field beside it
  onItemShown: (item) => recordView(item),
)
```

Rebuild it with another list and the file on screen stays on screen:
pages follow their item's `id`. `onItemShown` reports the first file
and each one paged to, never a neighbour being prepared.

## Items and sources

A `MediaReaderItem` describes a file. Its kind is read from its
content type and name by `MediaKind.of`; pass `kind` when your server
already knows it. What your server knows of a sound goes with it: its
`peaks` for the waveform, and its `duration` (see Audio).

| Source | For |
| --- | --- |
| `MediaReaderSource.remote(resolve)` | A file behind a signed URL |
| `MediaReaderSource.file(path)` | A file on the device |
| `MediaReaderSource.bytes(bytes)` | Bytes in memory |

Your `resolve` returns a `MediaReaderLocation`: the URL, the headers
to send with it, and its expiry when you know it.

```dart
Future<MediaReaderLocation> resolve(SharedFile file) async {
  final signed = await api.resolve(file.id);
  return MediaReaderLocation(
    signed.url,
    expiresAt: DateTime.now().add(signed.expiresIn),
  );
}
```

- It is called when an engine asks for the file, never just because
  the reader opened. The picture engine asks for its neighbours ahead
  of time, unless you tell it not to (see Pictures).
- The answer is kept until 30 seconds before it expires, or until an
  engine reports it refused; then `resolve` is called again.
- It is kept while the file is paged away from, and dropped when you
  take the file out of the list.
- Throw `MediaReaderUnavailable('You no longer have access.')` and the
  page shows the file's card with your words.

A `preview` is a derivative your server makes of a file no engine
shows as it is, with its own content type:

```dart
MediaReaderItem(
  id: file.id,
  name: 'Minutes.docx',
  source: MediaReaderSource.remote(() => resolve(file)),
  preview: MediaReaderPreview(
    source: MediaReaderSource.remote(() => resolvePdf(file)),
    contentType: 'application/pdf',
  ),
)
```

The file itself is preferred. Where no engine shows it, the preview's
own kind's engine shows the preview; failing that, the card.

Your server makes a preview in its own time. Say where it has got:

```dart
preview: switch (file.derivatives.pdf) {
  'ready' => MediaReaderPreview(source: ..., contentType: 'application/pdf'),
  'preparing' => const MediaReaderPreview.preparing(),
  'failed' => const MediaReaderPreview.failed(),
  _ => null,
},
```

A preview being prepared shows the file's card, saying so; one that
could not be made says that. When your server is done, hand the reader
the file again with the ready preview: `MediaReaderView` rebuilt with
the new items, or `showMediaReader(liveItems: ...)`, a
`ValueListenable` of the items the reader follows while it is open. The
card gives way to the file, where it stands.

## The policy

```dart
MediaReaderPolicy(
  canExport: member.canExport,
  cache: MediaReaderCache.directory(accountCacheDir),
)
```

- `canExport` reaches every slot as `state.canExport`. The reader has
  no export action of its own to hide: you show Share and Save only
  when it is true.
- `cache` is where engines may keep what they fetch: `none()`,
  `memory()` (the default) or `directory(path)`.
- With `canExport: false` nothing is kept on disk: a directory reads
  as memory.
- The directory is yours: the reader writes there and nowhere else,
  and never clears or bounds it. Clear it when the account changes,
  and call `MediaReaderCache.clearMemory()` with it.
- Copying text is not an export.

## The chrome

`MediaReaderChrome` takes a builder for each slot. Each is given a
`MediaReaderState`: the item on screen, its `index` and the `count`,
the `policy` (and `canExport`), the engine's `status`, what plays on
the page (`playback`) or the document on it (`document`), and
`close`.

| Slot | For | Plain default |
| --- | --- | --- |
| `topStart` | Who shared it, when, where | The file's name and "2 of 5" |
| `topEnd` | Closing | A round close button |
| `bottomStart` | Your actions: reply, forward | Empty |
| `bottomEnd` | More | Empty |
| `contextPill` | "Shared in #channel" | Empty |
| `controls` | The controls for what plays, or for a document | For what plays, a bar: play, a scrubber or the waveform, time, speed, mute. For a document, its pages and its search |
| `status` | The engine's status: "1 of 15", a time | A pill, while there is one |
| `cardActions` | Your actions on a file's card: save, share | Empty |

```dart
MediaReaderChrome(
  bottomStart: (context, state) => Row(
    children: [
      ReplyButton(to: state.item.data as SharedFile),
      if (state.canExport) ShareButton(state.item),
    ],
  ),
  strings: MediaReaderStrings(close: l10n.close),
)
```

- A slot left out shows its plain default. A builder that returns an
  empty box leaves its slot empty.
- `background` and `foreground` colour the canvas, the card and the
  plain defaults; text in your slots inherits `foreground`.
- `strings` holds the few words the reader itself draws or speaks: the
  card and its reasons, the plain defaults and the page announcement.
  They are English unless you pass your own.
- `close` is null where the reader cannot be closed.
- `contentInsets` is the room your slots take at the top and the
  bottom, within the safe area. A page that scrolls keeps it clear: a
  PDF's first page starts below your top slots, and its last page can
  be brought above your bottom ones. The default suits the plain
  chrome.

## Engines

A `MediaReaderEngine` shows the files it can, on the platforms it can.
`MediaReaderEngines` is an ordered list of them: the first that can
show a file wins, and the file's card is what is left.

```dart
showMediaReader(
  context,
  items: items,
  // Your engine is asked before the package's own.
  engines: MediaReaderEngines.standard.withFirst([const ModelEngine()]),
);
```

An engine is handed the item and its `MediaReaderPage`:

```dart
class const ModelEngine() implements MediaReaderEngine {
  @override
  String get id => 'model';

  @override
  bool canShow(MediaReaderItem item, TargetPlatform platform) =>
      item.name.endsWith('.glb');

  @override
  Widget build(
    BuildContext context,
    MediaReaderItem item,
    MediaReaderPage page,
  ) => ModelViewer(item: item, page: page);
}
```

| On the page | What it is for |
| --- | --- |
| `isCurrent` | Whether the page is on screen, not a neighbour being prepared. Play only while it is. |
| `resolve()` | Where a remote file is: the kept location, or a fresh one. |
| `renew(refused)` | A fresh location after a refusal (an expired URL). |
| `status` | Set it to show "1 of 15" or a time in the chrome. |
| `playback` | Set it to what plays on the page: the chrome's controls show its state and drive it. |
| `document` | Set it to the document on the page: the chrome's controls show its pages and search it. |
| `openLink(uri)`, `opensLinks` | Hands a link to the host's `onLink`, and says whether the host takes links at all. Mark a link as one only then. |
| `holdsPaging`, `holdsDismiss` | Set while the engine owns sideways or downward drags: zoomed, or scrolled away from its top. |
| `chromeVisible`, `toggleChrome()` | For an engine with controls of its own, or one that takes taps. |
| `fail(reason)` | The engine cannot show the file: its card takes the engine's place, with the reason. |
| `retry()` | The engine starts afresh. The card's "Try again" calls it. |
| `policy`, `chrome` | What the host allows; the colours and words around the page. |

The card shows the file's name, kind and size, why it is not shown,
and your `cardActions`. After a failure it also offers "Try again".

`item.format` is the file's format as a short name ("jpeg", "heic",
"mp4", "m4a"): from a specific content type, otherwise from the
extension. An engine decides by it whether it shows the file on a
platform.

An engine with no plugin of its own fetches through a
`MediaReaderTransport`. The default is `dart:io`'s `HttpClient`; pass
your own to an engine to use your HTTP stack:

```dart
MediaReaderPictureEngine(transport: YourTransport(dio))
```

## Pictures

`MediaReaderPictureEngine` shows what Flutter decodes on the platform:

| Format | Where |
| --- | --- |
| JPEG, PNG, GIF, WebP, BMP, ICO | Every platform |
| HEIC, TIFF | iOS and macOS, where the system decodes them |
| HEIC elsewhere | Through its `preview`, the JPEG your server makes |
| SVG, AVIF | The card |

- **Zoom.** Pinch, double tap, or the mouse wheel, up to 8 times. A
  double tap goes to 2.5 times at the point tapped, and back. A zoomed
  picture pans within its edges. The zoom is gone when the page is
  left.
- **Gestures.** At rest a drag is the shell's: it pages or dismisses.
  While the picture is zoomed, or two fingers are on it, drags are the
  picture's.
- **Memory.** A picture is decoded to fit the screen, whatever the
  file's size: a 48-megapixel photo is decoded at 1080 by 810 on a
  phone 1080 pixels wide. Zoomed into, it is decoded again with the
  detail the zoom shows, never past 4096 pixels on its longest side.
  A file over 64 MB is not fetched. All three numbers are the engine's
  parameters.
- **Loading.** The item's `poster` shows until the first frame. The
  neighbours' pictures are fetched ahead, so they are there when paged
  to; `prepareNeighbours: false` asks for a picture only when its page
  comes on screen, which suits a host that meters its resolves.
- **Failing.** A file that does not decode, does not arrive, or is too
  large gives way to the card, with the reason.

To reuse a cache your app already has, give the engine your own image
provider:

```dart
MediaReaderEngines.standard.withFirst([
  MediaReaderPictureEngine(
    imageProvider: (item, page) async {
      final location = await page.resolve();
      return YourCachedImage(
        location.uri,
        headers: location.headers,
        cacheKey: item.id, // the URL changes with every signature
      );
    },
  ),
])
```

It is asked only while the policy allows export: such a cache is
usually on disk, and with export off nothing is kept there.

## Video

`MediaReaderVideoEngine` plays through the `video_player` API: AVPlayer
on iOS and macOS, ExoPlayer on Android, and
[`fvp`](https://pub.dev/packages/fvp) (libmdk) on Windows and Linux,
where `fvp` registers itself as `video_player`'s implementation.

| Format | Where |
| --- | --- |
| MP4, M4V, MOV, 3GP, HLS | Every platform |
| WebM, Matroska, MPEG-TS | Android, Windows, Linux |
| AVI, MPEG, WMV, FLV | Windows, Linux |
| A format the platform does not play | Through its `preview`, the MP4 your server makes; else the card |

- **Paging.** A neighbour shows its poster and asks for nothing. A
  video is resolved and opened when its page comes on screen, stops
  when the page is left, and goes on when the page is back if it was
  playing. Two videos never play at once. The player is released with
  its page.
- **Controls.** The plain transport plays and pauses, scrubs, shows
  the time played and left, goes round the speeds (1, 1.5, 2) and
  mutes. It hides with the chrome. Your own goes in the `controls`
  slot, driven by `state.playback`:

  ```dart
  MediaReaderChrome(
    controls: (context, state) => switch (state.playback) {
      null => const SizedBox.shrink(),
      final playback => GlassTransport(playback),
    },
  )
  ```

- **A location that runs out.** Before a play or a seek, the location
  is checked: one that has expired gives way to a fresh one, and the
  video goes on at the same place. When the player gives up under way,
  a fresh location is asked for once; a second failure at the same
  place is the file's own, and goes to the card.
- **Sources.** A signed URL or a file. A video in memory has no
  player, and shows its card.

`fvp` is a dependency on every platform, though it plays only on
Windows and Linux: libmdk is linked into the iOS, Android and macOS
builds as well.

## Audio

`MediaReaderAudioEngine` plays through
[`just_audio`](https://pub.dev/packages/just_audio) on iOS, Android and
macOS, and through the `video_player` API on Windows and Linux, where
`fvp` plays a file that has no picture.

| Format | Where |
| --- | --- |
| MP3, M4A, M4B, AAC, WAV, FLAC | Every platform |
| AIFF | iOS, macOS, Windows, Linux |
| Ogg, Opus, WebM audio, AMR | Android, Windows, Linux |
| WMA | Windows, Linux |
| A format the platform does not play | Through its `preview`, the MP3 or M4A your server makes; else the card |

- **One sound at a time.** A `MediaReaderAudioCoordinator` gives the
  app's one audio player to one file at a time: starting a file stops
  the one that was playing, which keeps its place. A video that starts
  in the reader stops the audio, and audio that starts stops the
  video. The reader and the inline bar use
  `MediaReaderAudioCoordinator.shared` unless you pass your own.
- **In the reader.** A neighbour asks for nothing. A file plays when
  its page comes on screen, stops when the page is left, and goes on
  when the page is back if it was playing. The page shows the file's
  name and length over its `poster`; the transport is the chrome's.
- **The waveform.** Give the item the `peaks` your server computes,
  each from 0 to 1, and the scrubber is the sound's waveform: as many
  bars as fit, each the loudest of the peaks it stands for, the part
  played in full colour. A tap or a drag along it seeks, and to a
  screen reader it is a slider. Without peaks it is a plain track. The
  item's `duration` is shown until the player knows its own.
- **A location that runs out** is renewed as a video's is: before a
  play or a seek, and once when the player gives up under way.
- **Sources.** A signed URL or a file. Headers go to the platform's
  player with the URL. Audio in memory has no player, and shows its
  card.

### A voice note in a chat

`MediaReaderAudioBar` is the inline player: play and pause, the
waveform, the time, the speed.

```dart
MediaReaderAudioBar(
  item: MediaReaderItem(
    id: note.id,
    name: note.name,
    source: MediaReaderSource.remote(() => resolve(note)),
    peaks: note.peaks,
    duration: note.duration,
  ),
  color: bubble.foreground,
  strings: MediaReaderStrings(play: l10n.play, pause: l10n.pause),
)
```

- **One player with the reader.** The bar and the reader's page for
  the item with the same `id` are one session: a note that plays in
  its bubble goes on playing when it is opened in the reader, either
  place's controls drive it, and your `resolve` is asked once between
  them.
- **Nothing until it is played.** A bar shows the length you gave,
  and your `resolve` is not called until the note is played.
- **Scrolled out of sight,** a note that is playing plays on to its
  end; `stopsWhenRemoved: true` stops it with its bubble. Call
  `MediaReaderAudioCoordinator.shared.stop()` when the conversation is
  left.
- **Failing.** A note that cannot be played goes back to its play
  button, and `onFailure` is told what your `resolve` or the player
  threw: you say why, in your own way.
- **Your own bar.** `coordinator.attach(id, source: …)` gives the
  file's session, a `MediaReaderPlayback` with a `failure` to show;
  `MediaReaderWaveform` draws the peaks and seeks. Let go with
  `detach`.

### The audio session

`just_audio` pauses the file for a call or another app's sound, and
lowers it where the system says to. The session's category is your
app's to choose, and the reader sets nothing: it is one setting for
the whole app, and your app may record or make calls as well. Set it
once at start with [`audio_session`](https://pub.dev/packages/audio_session),
or an iPhone plays nothing while its silent switch is on:

```dart
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration.speech());
```

The reader shows nothing on the lock screen and asks for no
background mode: a file plays while your app is in front.

## PDF

`MediaReaderPdfEngine` shows PDFs with
[`pdfrx`](https://pub.dev/packages/pdfrx), on PDFium, on every
platform.

- **Reading.** The pages run one under the other, fitted to the
  width. A pinch, a double tap, or the wheel with Ctrl held magnifies,
  up to 8 times. While a page fits the width, a drag
  sideways goes between files; magnified, it moves the page. A drag
  down is the pages' own, so a PDF is closed with the close button or
  Esc.
- **Where it is.** The status says "3 of 300". `state.document` gives
  your controls the page on screen and the count, `goToPage`, a page
  drawn small for a strip (`thumbnail`), the search, and the
  document's `toggles` (a text's, below). The plain bar has two
  buttons: Pages opens a strip of the pages and a field for a page's
  number; Search opens a field, says "2 of 17", and steps through the
  matches.

  ```dart
  MediaReaderChrome(
    controls: (context, state) => switch (state.document) {
      null => const SizedBox.shrink(),
      final document => GlassPageStrip(document),
    },
  )
  ```

- **By ranges.** A remote PDF is read a range at a time, 256 KB by
  default (`blockSize`), as PDFium asks for its parts. The first page
  is up after two ranges, the file's first and its last, before the
  rest has come. Your `resolve` is asked once for all of them, and
  again only when the location is refused. A server that does not
  answer `Range` requests is asked for the whole file, once.
- **Kept where the policy says.** With `none()` the ranges are held
  while the PDF is open. With `memory()` they stay for the next
  showing, up to 64 MB for the whole app. With `directory(path)` they
  are written to two files there, named after the item's id, and read
  back the next time. Nothing is written anywhere else: `pdfrx`'s own
  download cache is not used.
- **Text.** A long press selects a word on a touch screen, a drag
  selects with a mouse. The menu has Copy and Select all, and nothing
  else. Copying is not an export, so it stays with export off; a PDF
  whose own permissions forbid copying is not copied.
- **Links.** A link to a place in the document goes there. A web
  address is handed to your `onLink`; without one it is not a link.
- **Passwords.** Give the engine your way to ask:

  ```dart
  MediaReaderEngines.standard.withFirst([
    MediaReaderPdfEngine(
      // Asked again, with the next attempt's number, while the answer
      // does not open the file. Null gives up: the card.
      password: (item, attempt) => askForPassword(item.name, attempt),
    ),
  ])
  ```

- **Failing.** A file that does not come, is not a PDF, or stays
  locked gives way to the card, with the reason and "Try again".
- **Keys.** Page Up and Page Down, Home and End, the arrows, select
  all and copy work while the reader has the keyboard, and Ctrl or
  Cmd with + and − magnify. The sideways arrows go between files while
  the page fits the width.

`pdfrx` brings the `url_launcher` plugin into your app for one thing:
the banner it shows when a document fails, which links to a web page.
The engine replaces that banner, so the reader never reaches the
plugin. A test in this repository fails if that changes, or if
another such package arrives with a dependency.

## Text

`MediaReaderTextEngine` shows plain text, logs, code, JSON, XML and the
like, in Flutter's own text, a line at a time: a log of 20 MB is a
buffer and a list of where its lines start, and only the lines on
screen are built.

- **Loading.** A remote file comes a range at a time, and its start is
  up while the rest comes. The most a file is taken into memory is
  32 MB (`maxBytes`); a longer one shows its start and says so at its
  end.
- **Reading it.** UTF-8, UTF-16 with its byte-order mark, and
  Windows-1252 for whatever is not Unicode. A tab is four columns.
- **How it is set.** Prose (`.txt`) is in the reader's own face,
  wrapped at its words. Everything else is in a face of equal widths,
  laid out in rows of one height and wrapped at the column, as a
  terminal wraps it; the Wrap toggle turns that off, and long lines
  then go on to the right. JSON and XML are laid out to be read
  (`Formatted`), up to 1 MB (`maxFormattedBytes`); every name, number
  and string stays as the file has it.
- **Search.** Through every line, a few thousand at a time, in any
  case; the matches are marked, and the plain bar steps through them.
- **Text.** A long press selects a word, a drag selects with a mouse;
  Copy and Select all, and nothing else. Select all takes the whole
  file, not only the lines on screen, up to 1 MB. Copying is not an
  export.
- **Keys.** The arrows, Page Up and Page Down, Home and End, while the
  reader has the keyboard.

## Markdown

`MediaReaderMarkdownEngine` lays a Markdown file out with
[`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus),
in the chrome's colours.

- **Links** go to your `onLink`, and without one are plain text.
- **Images are never fetched.** Their words stand where they would be.
- **As written.** The Formatted toggle shows the file as it is written,
  in the text engine. A file over 1 MB is shown that way from the
  start.
- The rest is as for text: selection, copy, the keys.

## Tables

`MediaReaderTableEngine` shows CSV and TSV as a table whose cells are
built only where they are on screen, with
[`two_dimensional_scrollables`](https://pub.dev/packages/two_dimensional_scrollables).
A hundred thousand rows are a hundred thousand rows.

- **Reading it.** The delimiter is the one the first rows agree on
  (comma, semicolon, tab or bar), or a tab for a `.tsv`. A cell in
  quotes may hold the delimiter, a line break, and a quote written
  twice. The columns are as wide as the first rows need, up to 40
  characters.
- **The header row stays** as the table scrolls. The status says
  "100,001 rows".
- **Search** goes through the rows and marks the cells.
- **Text.** Cells are copied with tabs between them and rows on lines
  of their own; Select all takes the file itself.
- A table wider than the screen takes sideways drags; one that fits
  leaves them to the pager.

## Archives

`MediaReaderArchiveEngine` lists what a zip, a tar or a gzip file
holds, and opens an entry through the registry in a reader over this
one, with the same chrome, policy and engines: a picture in a zip opens
as a picture, a zip in a zip lists in its turn.

- **A zip is read from its end**, where its list is, and **a tar from
  its headers**: a large archive on a server is listed after a few
  ranges, and only the entry that is opened is fetched. A gzip file is
  one stream, read whole: up to 64 MB (`maxEntryBytes`), which is also
  the most an entry is taken out at.
- **Folders** open in place, with a row to go back up. Files show their
  size; the status says how many there are.
- **What is not opened.** An encrypted entry, or one packed a way the
  reader does not unpack (everything but stored and deflated), is
  there and says so. 7z and rar show their card. An entry is bytes in
  memory, so a video or an audio file in an archive shows its card.
- Opening an entry needs a `Navigator` above the reader, as any app
  has.

The archive formats are read by the package itself, with `dart:io`'s
zlib, so that a remote archive is not fetched whole to be listed. The
tests make their archives with the `archive` package and read them
back with this one.

## Engines by kind

Every engine runs on all five platforms.

| Kind | Engine | Status |
| --- | --- | --- |
| Pictures | Flutter `Image` + `InteractiveViewer` | In |
| Video | `video_player` (AVPlayer, ExoPlayer) with [`fvp`](https://pub.dev/packages/fvp) on Windows and Linux | In |
| Audio | [`just_audio`](https://pub.dev/packages/just_audio); `fvp` on Windows and Linux | In |
| Waveform | drawn from peaks your server computes | In |
| PDF | [`pdfrx`](https://pub.dev/packages/pdfrx) (PDFium) | In |
| Office | your server's PDF, through `pdfrx` | Planned |
| Text, code, JSON | Flutter text, a line at a time | In |
| Markdown | [`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus) | In |
| CSV, TSV | [`two_dimensional_scrollables`](https://pub.dev/packages/two_dimensional_scrollables) | In |
| Zip, tar, gz | read by the package, entries opened through the registry | In |

## Development

Flutter 3.47.5 through [fvm](https://fvm.app):

```sh
fvm flutter pub get
fvm flutter analyze --fatal-infos
fvm flutter test
cd example && fvm flutter run -d <device>
```

The example also runs as a test on a device, which is how each phase
fills the plan's platform matrix:

```sh
cd example && fvm flutter test integration_test -d <device>
```

## Licence

Apache-2.0. Engines bring their own licences: PDFium (through
`pdfrx`) and libmdk/FFmpeg (through `fvp`). A notice file arrives
with 1.0.
