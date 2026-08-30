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

## Target API level

Google Play enforces a **target API level floor** and raises it every year on
31 August. An app whose target is below the floor cannot be updated — not even
to fix a crash — until it is raised.

| Deadline | Floor |
|---|---|
| 31 Aug 2025 | API 35 (Android 15) |
| 31 Aug 2026 | API 36 (Android 16) |
| 31 Aug 2027 | API 37 (Android 17) |

`targetSdk` is **pinned** in `android/app/build.gradle.kts` rather than
inherited from `flutter.targetSdkVersion`, so a Flutter upgrade cannot move it
silently in either direction. It is currently **37**.

Target the newest stable level, not the floor. Targeting the floor buys twelve
months and another warning mail from Play; targeting the newest level buys two
years.

Raising it takes four things, all of which must move together:

1. Install the platform and build-tools:
   `sdkmanager "platforms;android-<N>.0" "build-tools;<N>.0.0"`.
   From API 37 onward Google ships **minor-versioned** platforms — the
   directory is `android-37.0`, not `android-37`.
2. Set both `compileSdk` and `targetSdk` in `android/app/build.gradle.kts`.
   `compileSdk` must be >= `targetSdk`, and Flutter's default lags the newest
   level, so both have to be pinned.
3. Use an **AGP that understands the level**. AGP 8.9 cannot resolve a
   minor-versioned platform directory and fails with
   `Failed to find Platform SDK with path: platforms;android-37`. AGP 8.13.2 +
   Gradle 8.14.3 + Kotlin 2.2.20 is the combination that works for API 37.
   AGP 9.x also works but requires migrating this file to the new DSL
   (`android.newDsl=true`, `kotlinOptions` -> `compilerOptions`).
4. Read the behaviour changes for every level you skipped and re-verify on a
   device. API 36 made edge-to-edge mandatory with no opt-out; API 37 keeps it.

## Shipping an update to a closed testing track

Closed testing has one rule that catches people out: **the 12-tester / 14-day
window does not reset when you upload a new build**, as long as the same
testers stay opted in on the same track. Uploading a fixed target API level
mid-test is safe.

1. Bump `version:` in `pubspec.yaml`. The `+BUILD` suffix is the Android
   `versionCode` and **must** increase — Play rejects a duplicate outright.
2. `flutter build appbundle --release` with `android/key.properties` present.
   Confirm the artifact is really release-signed before uploading:
   `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
   — the owner must be your release identity, never `CN=Android Debug`.
3. Play Console -> **Testing -> Closed testing** -> your track -> **Create new
   release**.
4. Upload `build/app/outputs/bundle/release/app-release.aab`. The target API
   level warning on the dashboard clears once a build above the floor is
   *released to a track*, not merely uploaded.
5. Write release notes, then **Save -> Review release -> Start rollout to
   Closed testing**.
6. Existing testers get the update automatically. Do not remove or re-add
   testers, and do not create a new track — either resets the continuous
   opt-in count the production-access review depends on.

Promoting to production afterwards: **Closed testing -> Releases -> Promote
release -> Production**, which is available once the 12/14 requirement is met
and Play has granted production access.

## Play Store checklist

- [x] Release signing configured
- [x] Permissions declared in the **main** manifest (`INTERNET`,
      `POST_NOTIFICATIONS`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE`)
- [x] R8 / resource shrinking enabled with rules
- [x] Release App Bundle builds, gated by CI
- [x] Crash boundary in `main.dart`
- [x] Adaptive launcher icon
- [x] Privacy policy hosted, and Data Safety form completed
- [x] Store listing: description, screenshots, feature graphic
- [x] Closed testing track
- [x] Play App Signing enrolment
- [x] Target API level at the newest stable level (37)
- [ ] Accessibility pass
- [ ] Production release

Live status: [`ROADMAP.md`](../ROADMAP.md).

## Troubleshooting

| Symptom | Cause |
|---|---|
| `KeytoolException: Failed to read key` | The keystore is missing, corrupt, or the password is wrong. If `key.properties` is absent this is your **debug** keystore — regenerate it with `keytool -genkeypair -keystore ~/.android/debug.keystore -storepass android -keypass android -alias androiddebugkey -dname "CN=Android Debug"` |
| Release build succeeds but the app has no network | Check the **merged** manifest, not the source. `debug/` and `profile/` manifests are not merged into release |
| Play rejects the upload as debug-signed | `key.properties` was absent at build time |
| `versionCode` rejected | Increment the `+BUILD` suffix in `pubspec.yaml` |
| `Failed to find Platform SDK with path: platforms;android-37` | AGP is too old to resolve a minor-versioned platform directory. Raise AGP — see **Target API level** |
| `Release app bundle failed to strip debug symbols` | Non-fatal. The bundle is still produced and uploadable; only the native debug symbols are missing |
