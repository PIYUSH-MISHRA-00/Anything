# Durable Collection Certification — IS-R56

Enforced by `test/r46_architectural_integrity_certification_test.dart`
(83 → **86** tests).

## The three invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-75 | Exactly ONE durable collection store, and nothing else imports `SharedPreferences` for a collection | STATIC | CERTIFIED |
| I-76 | Every durable collection mutates through the ONE store | STATIC | CERTIFIED |
| I-77 | `deliverDue` CLAIMS before it PRESENTS | STATIC | CERTIFIED |

## I-75 — pinned exclusion, and a scan that runs on RAW source

`ThemeProvider` is pinned rather than overlooked: it stores **one scalar key**
(the selected theme mode), performs no read-modify-write, and holds no
collection. There is nothing to serialise. Recorded as G-39.

The import scan runs on **raw** source, not stripped source, because import
URIs are string literals and would be blanked. This is the R46 lesson applied
by default — both of that milestone's boundary scans once reported ZERO sites
for exactly this reason, and would have passed vacuously forever.

The test also asserts the scan matched something, so a regex that stops
matching fails loudly rather than certifying an empty set.

## I-77 — THE INVARIANT THAT WAS WRONG FIRST, AND HOW MUTATION TESTING FOUND IT

This deserves recording in full, because it is Phase 4's "vacuous pass"
category occurring in R56's **own new work**.

**First attempt:**

```dart
expect(presentIndex, greaterThan(body.lastIndexOf('store.update')));
```

The intent was "presentation happens after the claim". The probe moved
presentation *inside* the mutation callback — the exact R49 defect — and the
test **passed**.

Why: the callback's text begins *after* `store.update(` starts, so
`indexOf(present) > lastIndexOf(store.update)` is trivially true when the call
is nested inside. Green, and checking nothing.

**The real property is containment, not ordering.** Rewritten to compute the
balanced-parenthesis span of every `store.update(...)` call and assert
`_presenter.present` lies outside all of them:

```dart
for (final range in _callRanges(body, 'store.update')) {
  expect(presentIndex >= range.$1 && presentIndex < range.$2, isFalse, ...);
}
```

The probe then failed as required.

**The lesson generalises:** an ordering assertion is not a containment
assertion, and text position is a poor proxy for scope. Any future invariant of
the form "X must happen after Y" should ask whether it really means "X must not
happen *inside* Y".

## Mutation evidence

Three probes. All failed as required — the first only after the invariant was
corrected.

### Probe A — presentation moved back inside the critical section

The R49 defect, restored:

```dart
final due = await store.update<...>(_storageKey, (current) async {
  ...
  for (final n in claimed) {
    await _presenter.present(n);      // <-- inside the claim
  }
  return (value: _encode(remaining), result: claimed);
});
```

Worth recording: **the probe cannot even await inside the mutation** any more.
`update`'s callback is a plain synchronous function, so the R49 shape does not
compile at all. The probe therefore calls `present` unawaited from inside the
critical section — the closest reachable form of the defect — and I-77 still
catches it. The type system removes the worst version; certification catches
the rest.

Against the ORIGINAL invariant: **PASSED** (false negative — see above).
Against the CORRECTED invariant:

```
I-77  Expected: false / Actual: <true>
      present() must run AFTER the claim commits, never inside the mutation
      that claims — presenting from inside the critical section is the R49
      double-delivery defect
```

### Probe B — a second durable collection store

```dart
lib/r56_mutation_probe.dart:  class DurableKeyValueCollectionStore {}
```
```
I-75  a second durable-collection owner appeared:
      [lib/r56_mutation_probe.dart:DurableKeyValueCollectionStore,
       lib/storage/durable_collection_store.dart:DurableCollectionStore]
```

### Probe C — a repository reaching past the store

`ActivityRepository.clearAll` restored to touch `SharedPreferences` directly:

```
I-76  Expected: false / Actual: <true>
      lib/storage/activity_repository.dart must not reach past the store to
      SharedPreferences — that is the unserialised path R56 removed
```

## Behavioural certification

Static invariants prove ownership; they cannot prove the race is gone. The
15 tests in `r56_durable_collection_store_test.dart` are the audit probes kept
permanently, and they assert the outcomes directly:

- ten concurrent `schedule()` calls all survive (was: 1 of 10)
- concurrent `deliverDue()` delivers exactly once (was: twice)
- three concurrent `deliverDue()` over three due notifications: each once
- the due set is already claimed while presentation is in flight
- concurrent `cancel()` + `schedule()` do not clobber each other
- 20 concurrent mutations of one key all apply; different keys do not block
- a throwing mutation fails only its caller and does not deadlock the key
- intent history is no longer truncated to 50 by `updateStatus`/`delete`
- retention bounds unchanged: 200 activity, 100 intents

## Cleanup

All probes removed; working tree shows only intended R56 changes. Everything
was `git add`-ed before probing — the R53 lesson, third milestone running — so
`git checkout --` reverted each one. Residue verified by grep: the only
remaining `SharedPreferences` mentions in the three repositories are doc
comments, and one that had gone stale was corrected rather than left.

## What this certification cannot catch

- **A race in a collection nobody routed through the store.** I-75 catches a
  new `SharedPreferences` importer, but a future collection persisted through
  some other backend would need its own invariant.
- **Whether at-most-once is the right delivery semantic.** That is a product
  judgement, recorded as G-38.
- **Cross-key atomicity.** The store serialises one key. Two keys cannot be
  made atomic with each other, and no static check can pretend otherwise.
