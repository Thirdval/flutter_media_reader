# flutter_media_reader_example

Runs flutter_media_reader on iOS, Android, macOS, Windows and Linux
with sample files of every kind. The samples open in the reader, under
a host's chrome or the package's plain defaults, with export on or
off. It grows with the plan: a kind gets a bundled sample when its
engine arrives, and shows its card until then.

Above the list a voice note stands in a bubble, as a chat shows one:
play it there, open the same file in the list, and the reader goes on
with the same player.

Two PDFs are in the list. `Rota_October.pdf` has 300 pages and is
fetched a range at a time; its first line is a link, which the app is
handed and shows in a dialog. `Accounts_2025.pdf` is protected: the
reader asks the app, the app asks you, and the password is `harvest`.
Both are written by `tool/make_pdfs.py`.

`Budget 2026.xlsx` is shown through a PDF, as a host's server would
make one: the rota stands in for it. `Minutes.docx` is being prepared
until the switch on the samples page says the server is done; turn it
on while the reader shows the file, and the card gives way to the PDF.

The texts, the table and the archives are written by
`tool/make_texts.py`: a sermon, a README with a link and an image,
JSON on one line, a log of thirty thousand lines, a table of a hundred
thousand rows, a zip with folders and a zip inside it, and a gzipped
tar. Nothing in them is anyone's but the example's.

The bundled samples are served by a small server inside the app, on
the device's loopback: it signs URLs that expire, honours byte ranges
and refuses what is expired, as a host's CDN would. The example needs
no network and no account.

That server speaks plain HTTP, so the example allows it on each
platform: cleartext traffic on Android, local networking in the
Info.plist on iOS and macOS, and the network entitlements of the macOS
sandbox. An app whose files come over HTTPS needs none of these.

```sh
fvm flutter run -d <device>
```

The same app runs as a test on a device, for the plan's platform
matrix:

```sh
fvm flutter test integration_test -d <device>
```

On a desktop, keep the example's window in front while it runs: the
keyboard steps need its focus, and a hidden window draws no frames.
