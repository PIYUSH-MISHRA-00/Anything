# Troubleshooting Guide

## Android debug build fails with `KeytoolException: Tag number over 30 is not supported`

```
com.android.ide.common.signing.KeytoolException: Failed to read key
AndroidDebugKey from store "...\.android\debug.keystore": Tag number
over 30 is not supported
```

This is a JDK/keytool incompatibility with the auto-generated debug
keystore's format — **not** an Anything code or configuration issue. It
has reproduced identically across every Vision Milestone in this
repository (V6 through V10), unaffected by `flutter clean`/`flutter pub
get`.

**Workaround:** delete the existing debug keystore
(`%USERPROFILE%\.android\debug.keystore`) and let Gradle regenerate it
with a JDK/keytool version compatible with your current JDK, or generate
a fresh one explicitly with `keytool -genkey -v -keystore
debug.keystore -storepass android -alias androiddebugkey -keypass
android -keyalg RSA -keysize 2048 -validity 10000`. This has not been
verified in this environment (doing so would touch shared machine state
outside the repository) — treat it as the documented next step, not a
confirmed fix.

## `flutter test` hangs or deadlocks with `sqflite` under `testWidgets`

Use `databaseFactoryFfiNoIsolate` (not `databaseFactoryFfi`) when a test
uses `testWidgets`/`FakeAsync` and touches SQLite — the isolate-based
factory can deadlock under `FakeAsync`'s synchronous time control. Plain
`test()` functions with no `testWidgets`/`FakeAsync` can use either.

```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;
});
```

## SQLite tests collide with each other

Give every test its own database name, not a shared fixed one:

```dart
SqliteExperienceRepository(dbName: 'my_test_${DateTime.now().microsecondsSinceEpoch}.db')
```

## Never run more than one `flutter`/`dart` CLI process at a time

Concurrent `flutter clean` + `flutter test` (or any two SDK-tooling
invocations) against the same working directory can race on
`.dart_tool`/`build` file locks. If you see `"Failed to remove
build...A program may still be using a file in the directory"`, stop,
let the in-flight process finish, then re-run the second command
sequentially rather than assuming partial deletion succeeded silently.

## Analyzer shows more issues than expected

The current documented baseline is **71 issues, 0 errors** (unchanged
since Vision Milestone V2, re-verified through V10). If `flutter
analyze` reports more than 71, treat the delta as new and worth
investigating before merging — don't assume it's pre-existing noise.
