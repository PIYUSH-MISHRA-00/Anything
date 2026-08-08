# Release Guide

How to produce a publishable Anything build. Read this fully before your first
release — **a lost release keystore is unrecoverable**, and an app signed with a
new key cannot update an app signed with the old one.

---

## One-time: create the release keystore

```bash
keytool -genkeypair -v \
  -keystore ~/anything-release.jks \
  -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias anything
```

Then create `android/key.properties` (gitignored — never commit it):

```properties
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=anything
storeFile=/absolute/path/to/anything-release.jks
```

### Protect it

| Do | Do not |
|---|---|
| Back the `.jks` up somewhere you will still have in five years | Commit it. CI fails the build if any `*.jks`, `key.properties` or `.env` is tracked |
| Enrol in **Play App Signing** — Google holds the app signing key, you hold the upload key, and a lost upload key is recoverable | Rely on a single local copy |
| Store passwords in a password manager | Put them in CI logs or a shell history |

`android/app/build.gradle.kts` reads `key.properties` if present and **falls
back to debug signing if it is absent**, so a fresh clone still builds. A
debug-signed artifact is *not* publishable — Play rejects it.

## Verify signing is real

```bash
flutter build appbundle --release
```

If `key.properties` is missing you get a debug-signed bundle. To confirm which
key was used:

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | head -20
```

An `Android Debug` CN means the fallback was used and the artifact must not be
published.

## Cut a release

1. **Update the version** in `pubspec.yaml` — `version: X.Y.Z+BUILD`.
   `versionName` comes from `X.Y.Z`, `versionCode` from `BUILD`. **Play rejects
   an upload whose `versionCode` is not higher than the last one.**
2. **Update [`CHANGELOG.md`](../CHANGELOG.md)** — move `Unreleased` into a
   version heading.
3. **Run the full checks:**
   ```bash
   dart format --set-exit-if-changed .
   bash tool/analyze_gate.sh
   flutter test
   flutter build appbundle --release
   ```
4. **Tag and push:**
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
5. **Upload** `build/app/outputs/bundle/release/app-release.aab` to the Play
   Console.

## Versioning

[Semantic Versioning](https://semver.org/). While pre-1.0 the public surface is
the Experience package format and the capability contracts, not the Dart API.

| Bump | When |
|---|---|
| MAJOR | An existing Experience package stops loading |
| MINOR | New capability, new package field, new user-visible feature |
| PATCH | Fixes and internal work |

The package container carries its own `formatVersion` (`ExperiencePackageFormat`),
independent of the app version. A reader refuses a container newer than it
understands rather than parsing it hopefully.

## What CI does and does not do

| CI does | CI does not |
|---|---|
| format, analyzer baseline, 102 invariants, full suite with coverage | sign a publishable artifact — no keystore exists in CI, by design |
| build a release App Bundle (debug-signed) to prove it **packages** | upload to Play |
| assert the **merged release manifest declares `INTERNET`** | run on a real device |

That build gate exists because it did not for the project's first 62
milestones, during which the release build was broken and nobody could tell.

## Play Store checklist

Before a first submission — status as of IS-P01:

- [x] Release signing configured
- [x] Permissions declared in the **main** manifest (`INTERNET`,
      `POST_NOTIFICATIONS`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE`)
- [x] R8 / resource shrinking enabled with rules
- [x] Release App Bundle builds, gated by CI
- [x] Crash boundary in `main.dart`
- [ ] Adaptive launcher icon (still the Flutter default)
- [ ] Privacy policy hosted, and Data Safety form completed
- [ ] Store listing: description, screenshots, feature graphic
- [ ] Accessibility pass
- [ ] Closed testing track
- [ ] Play App Signing enrolment

Live status: [`ROADMAP.md`](../ROADMAP.md).

## Troubleshooting

| Symptom | Cause |
|---|---|
| `KeytoolException: Failed to read key` | The keystore is missing, corrupt, or the password is wrong. If `key.properties` is absent this is your **debug** keystore — regenerate it with `keytool -genkeypair -keystore ~/.android/debug.keystore -storepass android -keypass android -alias androiddebugkey -dname "CN=Android Debug"` |
| Release build succeeds but the app has no network | Check the **merged** manifest, not the source. `debug/` and `profile/` manifests are not merged into release |
| Play rejects the upload as debug-signed | `key.properties` was absent at build time |
| `versionCode` rejected | Increment the `+BUILD` suffix in `pubspec.yaml` |
