# flutter_media_reader — Project Rules

An in-app reader for the files a host hands it: pictures, video,
audio with waveforms, PDF, Office documents (through the host's PDF),
text, tables and archives, on iOS, Android, macOS, Windows and Linux.
Each kind is shown by an engine, an adapter over a maintained plugin,
chosen per platform. Files never leave the app.

**Plan of record: [MEDIA_READER_PLAN.md](MEDIA_READER_PLAN.md).**
- §3: the decisions (MR1–MR14). Decided rows are binding;
  Recommended rows wait for the owner.
- §4: the phases.
- §5: the tracker. Update a phase's row in the same commit as its
  work. The owner checks each phase off.

## Environment

- Flutter 3.47.5 through fvm (`.fvmrc`). Always prefix commands with
  `fvm`:
  - `fvm flutter pub get` (and in `example/`);
  - `fvm flutter analyze --fatal-infos` (must be clean);
  - `fvm flutter test`;
  - `fvm dart format lib test example/lib`.
- **Example app:** `cd example && fvm flutter run -d <device>`.
  - iOS builds are run by the owner; ask for them.
  - The owner's Pixel is on `adb` for Android.
  - macOS runs here.
  - Windows and Linux: run them when a machine is available, and say
    when they were not.

## Rules

- **Host-agnostic.** Never import Tendvine or any app. Everything a
  host owns comes through the contract in §2.2 of the plan: chrome
  slots, actions, sources that resolve through the host, the policy.
- **Nothing leaves the app (MR8):**
  - no `url_launcher`, `open_filex`, `share_plus` or any other
    hand-off to another app in `lib/`;
  - engines write only where `ReaderPolicy` allows;
  - export is only ever a host action, shown when the policy allows.
- **Engines** are adapters over maintained plugins (MR2–MR5). Write
  no native code without an owner decision in the plan.
- **Dart 3.13 style, lint-enforced:** primary constructors
  (`class const Foo({...}) extends …`, `enum Bar() { … }`). Also:
  - records for tiny data, sealed classes for states, pattern matching
    over `is` chains;
  - no `print`; `unawaited(...)` for deliberate fire-and-forget.
- **Framework first:**
  - use `dart:core`, `dart:async`, `package:collection` and Flutter's
    own widgets before hand-rolling anything;
  - dispose every controller, subscription and timer;
  - check `mounted` after an `await` in a `State`.
- **Size:** `lib/` files stay at or under 400 lines; split by concern.
- **Tests:** every public behaviour has one, with fake engines and
  sources (MR14). No goldens until the chrome settles.
- **Documentation:** each phase updates the README section for its
  kind and the example app.
- **Language:** English only in code, comments and docs.

## Git

- Commit as `Thirdval Prime <dev@thirdval.com>`.
- No AI attribution: no `Co-Authored-By` trailer, and no "Generated
  with" footer.
- **Push only when the owner asks.** When the owner says CI is paused,
  the pushed tip's commit message carries `[skip ci]`; run analyze and
  the tests locally first.
- **Tags:** tag the end of a phase `v0.N.0`; Tendvine pins by git ref.

## The first host: Tendvine

- Tendvine is a separate repository and session. Its adoption is phase
  R9, done there against a tag.
- The asks for Tendvine's backend and app are in §6 of the plan (B1–B5,
  A1–A3). Those sessions own them. Here, build against the contract,
  with fakes.
