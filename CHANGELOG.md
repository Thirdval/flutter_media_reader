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
