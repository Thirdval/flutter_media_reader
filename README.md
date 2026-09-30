# flutter_media_reader

An in-app reader for the files your app hands it: pictures, video,
audio with waveforms, PDF, Office documents (through a PDF your server
makes), text, tables and archives, on iOS, Android, macOS, Windows and
Linux.

> **Status: pre-release (phase R2).** The reader's shell, its host
> contract and the picture engine are in. The engines for the other
> kinds arrive phase by phase; until then those files show their card.
> Progress: [MEDIA_READER_PLAN.md](MEDIA_READER_PLAN.md) §5.

## Principles

- **Files never leave the app.** The reader never hands a file to
  another app or the browser. Exporting (share, save to device) is
  your action, shown only when your policy allows it. Engines cache
  only where your policy says.
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
);
```

The future completes when the reader is dismissed. The route is
see-through: the page beneath shows as the reader is dragged away.

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
already knows it.

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
- Copying text is not an export.

## The chrome

`MediaReaderChrome` takes a builder for each slot. Each is given a
`MediaReaderState`: the item on screen, its `index` and the `count`,
the `policy` (and `canExport`), the engine's `status`, and `close`.

| Slot | For | Plain default |
| --- | --- | --- |
| `topStart` | Who shared it, when, where | The file's name and "2 of 5" |
| `topEnd` | Closing | A round close button |
| `bottomStart` | Your actions: reply, forward | Empty |
| `bottomEnd` | More | Empty |
| `contextPill` | "Shared in #channel" | Empty |
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

## Engines by kind

Every engine runs on all five platforms.

| Kind | Engine | Status |
| --- | --- | --- |
| Pictures | Flutter `Image` + `InteractiveViewer` | In |
| Video | `video_player` (AVPlayer, ExoPlayer) with [`fvp`](https://pub.dev/packages/fvp) on Windows and Linux | Planned |
| Audio | [`just_audio`](https://pub.dev/packages/just_audio); `fvp` on Windows and Linux | Planned |
| Waveform | drawn from peaks your server computes | Planned |
| PDF | [`pdfrx`](https://pub.dev/packages/pdfrx) (PDFium) | Planned |
| Office | your server's PDF, through `pdfrx` | Planned |
| Text, code, JSON, Markdown | Flutter text, `flutter_markdown_plus` | Planned |
| CSV, TSV | a virtualised table | Planned |
| Zip, tar, gz | [`archive`](https://pub.dev/packages/archive), entries previewed in place | Planned |

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
