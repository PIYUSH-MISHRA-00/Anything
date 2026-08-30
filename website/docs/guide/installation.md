# Installation

Anything is complete and running on real devices. There are two ways to get it:
the Google Play closed test, or a build from source.

## From Google Play (closed testing)

The signed App Bundle is live on Google Play's **closed testing** track while the
required tester period completes. A public listing follows.

1. Ask for a place on the tester list in
   [Discussions](https://github.com/PIYUSH-MISHRA-00/Anything/discussions) —
   include the Google account email you use on the Play Store.
2. Once you are added, opt in at
   [play.google.com/apps/testing/com.anything.anything](https://play.google.com/apps/testing/com.anything.anything).
3. Install from Google Play as normal. Updates arrive the usual way.

Requires Android 7.0 (API 24) or newer. The build targets Android 17 (API 37).

## From source

### Prerequisites

- **Flutter 3.44 or newer** — [install guide](https://docs.flutter.dev/get-started/install)
- **An AI provider key** — currently [Groq](https://console.groq.com/keys),
  which has a free tier

Without a key, Anything still runs. It reports `ProviderRequired` rather than
crashing or inventing an answer — but it cannot generate an Experience.

### Run it

```bash
git clone https://github.com/PIYUSH-MISHRA-00/Anything.git
cd Anything
flutter pub get
flutter run
```

Then open **Settings → AI Provider** and paste your key.

### Verify your checkout

These three commands are exactly what CI runs. A green local run means a green
CI run.

```bash
flutter test                                                          # 2,350+ tests
flutter test test/r46_architectural_integrity_certification_test.dart  # 102 invariants
bash tool/analyze_gate.sh                                             # analyzer baseline
```

If the 102 invariants fail on a clean checkout, **that is itself a bug** and
worth [reporting](https://github.com/PIYUSH-MISHRA-00/Anything/issues/new/choose).

## Platforms

| Platform | State |
|---|---|
| Android | **Shipped** — signed App Bundle on Google Play closed testing, targeting API 37, device-verified |
| Windows / macOS / Linux | Flutter targets exist, unexercised |
| iOS | Not attempted |
| Web | Flutter target exists, unexercised |

## Building a release

See the [release guide](https://github.com/PIYUSH-MISHRA-00/Anything/blob/v2.0.0/docs/RELEASE_GUIDE.md).
A release build needs a keystore; without one the build falls back to debug
signing, which produces an artifact Google Play will reject.
