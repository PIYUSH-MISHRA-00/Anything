# Installation

Anything is **pre-release**. There is no Play Store build yet — see the
[roadmap](/guide/roadmap). Today you run it from source.

## Prerequisites

- **Flutter 3.44 or newer** — [install guide](https://docs.flutter.dev/get-started/install)
- **An AI provider key** — currently [Groq](https://console.groq.com/keys),
  which has a free tier

Without a key, Anything still runs. It reports `ProviderRequired` rather than
crashing or inventing an answer — but it cannot generate an Experience.

## Run it

```bash
git clone https://github.com/PIYUSH-MISHRA-00/Anything.git
cd Anything
flutter pub get
flutter run
```

Then open **Settings → AI Provider** and paste your key.

## Verify your checkout

These three commands are exactly what CI runs. A green local run means a green
CI run.

```bash
flutter test                                                          # 2,141 tests
flutter test test/r46_architectural_integrity_certification_test.dart  # 102 invariants
bash tool/analyze_gate.sh                                             # analyzer baseline
```

If the 102 invariants fail on a clean checkout, **that is itself a bug** and
worth [reporting](https://github.com/PIYUSH-MISHRA-00/Anything/issues/new/choose).

## Platforms

| Platform | State |
|---|---|
| Android | Builds a signed release App Bundle; not published |
| Windows / macOS / Linux | Flutter targets exist, unexercised |
| iOS | Not attempted |
| Web | Flutter target exists, unexercised |

## Building a release

See the [release guide](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/RELEASE_GUIDE.md).
A release build needs a keystore; without one the build falls back to debug
signing, which produces an artifact Google Play will reject.
