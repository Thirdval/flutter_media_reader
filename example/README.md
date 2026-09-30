# flutter_media_reader_example

Runs flutter_media_reader on iOS, Android, macOS, Windows and Linux
with sample files of every kind. It grows with the plan: from R1 the
samples open in the reader, under a host's chrome or the package's
plain defaults, with export on or off. No engine exists before R2, so
every kind shows its card.

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
