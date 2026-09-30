# Notices

`flutter_media_reader` is licensed under the Apache License 2.0
(`LICENSE`). Its engines are adapters over other packages, and some of
those bring native libraries into an app that uses this package. This
file names them and their licences, so that a host can carry the
notices its own licence terms ask for. The pub packages' own licence
files are in the pub cache with each package; the native libraries'
are with their sources, linked below.

## Pub packages

| Package | Used for | Licence |
| --- | --- | --- |
| [`video_player`](https://pub.dev/packages/video_player) | Video on iOS, Android and macOS | BSD-3-Clause (the Flutter authors) |
| [`fvp`](https://pub.dev/packages/fvp) | Video and audio on Windows and Linux, through libmdk | BSD-3-Clause (Wang Bin) |
| [`just_audio`](https://pub.dev/packages/just_audio) and [`audio_session`](https://pub.dev/packages/audio_session) | Audio on iOS, Android and macOS | MIT (Ryan Heise) |
| [`pdfrx`](https://pub.dev/packages/pdfrx), [`pdfrx_engine`](https://pub.dev/packages/pdfrx_engine), [`pdfium_dart`](https://pub.dev/packages/pdfium_dart), [`pdfium_flutter`](https://pub.dev/packages/pdfium_flutter) | PDF, through PDFium | MIT (Takashi Kawasaki) |
| [`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus) and [`markdown`](https://pub.dev/packages/markdown) | Markdown | BSD-3-Clause (the Flutter and Dart authors) |
| [`two_dimensional_scrollables`](https://pub.dev/packages/two_dimensional_scrollables) | Tables | BSD-3-Clause (the Flutter authors) |

## Native libraries

### PDFium

`pdfrx` renders PDF with [PDFium](https://pdfium.googlesource.com/pdfium/),
which is licensed under the BSD-3-Clause licence (copyright the PDFium
authors, and Foxit Software). On Android, Windows and Linux it arrives
as a Dart native asset; on iOS and macOS as an XCFramework. PDFium
itself carries third-party code under its own licences, among them
FreeType (the FreeType licence), libjpeg-turbo (the IJG, BSD-3-Clause
and zlib licences), OpenJPEG (BSD-2-Clause), libpng (the PNG licence),
zlib (the zlib licence), Little-CMS (MIT) and ICU (the ICU licence):
see `third_party/` in PDFium's tree.

### libmdk, FFmpeg, libass and dav1d

`fvp` plays through [libmdk](https://github.com/wang-bin/mdk-sdk), the
"mdk-sdk" it downloads at build time for Windows and Linux (and for
every other platform where a host lets it register there). Its README
says: "Copyright (c) 2016-2025 WangBin (the author of QtAV). Free for
opensource softwares, non-commercial softwares, flutter, QtAV donors
and contributors." A Flutter app is covered by that line; a host that
is unsure should ask the author.

The SDK bundles:

- [FFmpeg](https://ffmpeg.org), under the GNU Lesser General Public
  License version 2.1 or later, as a shared library (`libffmpeg`) built
  by [avbuild](https://github.com/wang-bin/avbuild). The LGPL asks an
  app that ships it to carry FFmpeg's notice and to let its users
  replace the library, which a shared library allows; an FFmpeg built
  with GPL components would put the whole app under the GPL, so a host
  should check the build it ships. `fvp`'s README says how to drop the
  bundled FFmpeg for the system's, or one's own;
- [libass](https://github.com/libass/libass), under the ISC licence;
- [dav1d](https://code.videolan.org/videolan/dav1d), under the
  BSD-2-Clause licence.

### The platforms' own players

`video_player` and `just_audio` play through what the platform has:
AVFoundation on iOS and macOS, and on Android ExoPlayer from
[AndroidX Media3](https://github.com/androidx/media) (Apache-2.0), which
`just_audio` brings in.

## What this package does not bring

No image, network or storage library of its own: pictures are decoded
by Flutter, files are fetched through the host's transport, and
`path_provider` is used by `pdfrx` for a cache directory this package
points at the host's policy.
