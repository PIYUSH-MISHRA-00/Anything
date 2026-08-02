# Testing Guide

## Running tests

```
flutter test                    # full suite (1035 tests as of Vision Milestone V10)
flutter test test/world_model   # one directory
flutter test --coverage         # generates coverage/lcov.info
```

## Conventions used throughout this codebase

**SQLite in tests** — always fake via `sqflite_common_ffi`, never a real
device/emulator database:

```dart
setUpAll(() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate; // required under testWidgets/FakeAsync
});
```

Use a unique `dbName` per test (`'...${DateTime.now().microsecondsSinceEpoch}.db'`)
to avoid cross-test collisions — see `docs/TROUBLESHOOTING_GUIDE.md`.

**Widget accessibility assertions** require activating the semantics
tree explicitly:

```dart
final handle = tester.ensureSemantics();
// ... pump widget, interact ...
expect(tester.getSemantics(find.byType(Switch)).label, 'My Label');
handle.dispose();
```

**Novel-domain proof pattern** — every Vision Milestone that touches
synthesis/reasoning includes at least one test built around a domain
with zero footprint elsewhere in `lib/` (e.g. "Telescope Observation
Log", "Hive Inspection Log", "Lighthouse Maintenance Log") to prove no
domain-specific logic leaked into the implementation. When adding a new
structural engine, follow this pattern rather than testing only against
a domain the implementation might have been tuned for.

**Stress tests** report real `Stopwatch` timings via `print`, never an
asserted SLA number — see `test/world_model/stress_test.dart`. Assert on
correctness (counts, structural properties); report timing for
visibility only.

**Production-path vs. unit tests** — this codebase distinguishes
sharply between hand-authored fixture packages (fine for isolated
renderer/validator unit tests) and tests that drive the real
`AnythingKernel`/`CreationEngine`/`ExperienceHostScreen` pipeline
end-to-end. A file claiming "certification" status must be the latter —
see `docs/audit/V2_TEST_EVIDENCE_MATRIX.md` for the history of tests
that got this wrong and were rewritten or deleted.

## Regression discipline

Every Vision Milestone re-runs the full suite after its own new tests
pass, and reports the before/after total in
`docs/audit/V2_TEST_EVIDENCE_MATRIX.md`. When adding a new module,
follow the same pattern: new tests pass in isolation first, then the
full suite, then `flutter analyze`, before considering the change done.
