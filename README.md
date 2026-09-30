# flutter_media_reader

An in-app reader for the files your app hands it: pictures, video,
audio with waveforms, PDF, Office documents (through a PDF your server
makes), text, tables and archives, on iOS, Android, macOS, Windows and
Linux.

> **Status: pre-release (phase R0).** The scaffold and `MediaKind` are
> in; the reader arrives in R1. Progress:
> [MEDIA_READER_PLAN.md](MEDIA_READER_PLAN.md) §5.

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
  resolved when needed and again when it expires, a local file, or
  bytes.

## Planned engines

| Kind | Engine | Platforms |
| --- | --- | --- |
| Pictures | Flutter `Image` + `InteractiveViewer` | all |
| Video | `video_player` (AVPlayer, ExoPlayer) with [`fvp`](https://pub.dev/packages/fvp) on Windows and Linux | all |
| Audio | [`just_audio`](https://pub.dev/packages/just_audio); `fvp` on Windows and Linux | all |
| Waveform | drawn from peaks your server computes | all |
| PDF | [`pdfrx`](https://pub.dev/packages/pdfrx) (PDFium) | all |
| Office | your server's PDF, through `pdfrx` | all |
| Text, code, JSON, Markdown | Flutter text, `flutter_markdown_plus` | all |
| CSV, TSV | a virtualised table | all |
| Zip, tar, gz | [`archive`](https://pub.dev/packages/archive), entries previewed in place | all |

## What is here today

`MediaKind.of(contentType:, fileName:)` reads a file as a kind:

- A specific content type decides.
- A generic one (`application/octet-stream`) or none defers to the
  extension.
- An MPEG-4 container type defers to an audio-only extension, so a
  voice note uploaded as `video/mp4` and named `.m4a` is audio.

```dart
MediaKind.of(contentType: 'video/mp4', fileName: 'voice-1790.m4a');
// MediaKind.audio
```

## Development

Flutter 3.47.5 through [fvm](https://fvm.app):

```sh
fvm flutter pub get
fvm flutter analyze --fatal-infos
fvm flutter test
cd example && fvm flutter run
```

## Licence

Apache-2.0. Engines bring their own licences: PDFium (through
`pdfrx`) and libmdk/FFmpeg (through `fvp`). A notice file arrives
with 1.0.
