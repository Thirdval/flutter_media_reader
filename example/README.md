# flutter_media_reader_example

Runs flutter_media_reader on iOS, Android, macOS, Windows and Linux
with sample files of every kind. The samples open in the reader, under
a host's chrome or the package's plain defaults, with export on or
off. It grows with the plan: a kind gets a bundled sample when its
engine arrives, and shows its card until then.

The bundled samples are served by a small server inside the app, on
the device's loopback: it signs URLs that expire, honours byte ranges
and refuses what is expired, as a host's CDN would. The example needs
no network and no account.

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
