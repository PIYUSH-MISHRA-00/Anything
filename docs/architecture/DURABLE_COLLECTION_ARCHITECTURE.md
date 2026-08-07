# Durable Collection Architecture — Implementation Specification IS-R56

## WHAT THIS MILESTONE ACTUALLY IS

IS-R56 is titled "Canonical Runtime Import Framework". **The audit disproved
that target.** Runtime creation is already singular — `AnythingRuntime` is
constructed in exactly one place — and import ownership was settled in R53/R54.

The specification's own first principle says repository evidence overrides it,
so R56 implements what the evidence showed instead: **one owner for
read-modify-write against a durable collection**, driven by a measured data-loss
defect.

Full audit, including every axis that came back clean, in
`docs/audit/R56_REPOSITORY_AUDIT_REPORT.md`.

## THE DEFECT, MEASURED

Three collections implemented the identical shape with nothing serialising it:

```
read the whole list  ->  change it in memory  ->  write the whole list
```

A probe run **before any code was written**:

```
ACTIVITY:      recorded 10 concurrently, stored 10        <- NOT lost
SCHEDULE:      scheduled 10 concurrently, pending  1      <- NINE LOST
NOTIFICATIONS: 1 scheduled,  presented 2 time(s)          <- exactly-once broken
```

The first line **disproved half the hypothesis**. Activity survives, by an
accident of await ordering that nothing asserts. R56 therefore claims a proven
defect only for the notification paths, and routes the other two through the
same owner to remove the duplicated pattern rather than to fix a bug it cannot
demonstrate.

### Reachability

Not a test artefact. `NotificationCapability` exposes `schedule`/`cancel` to any
running Experience, `BackgroundCoordinator` polls `deliverDue`, and the
workspace runs several Experiences at once (R39/R45).

## THE OWNER — AND HOW IT FIXES THE RACE

`DurableCollectionStore.update(key, mutate)` resolves `SharedPreferences`
**first**, then runs the caller's mutation and the write with **no `await` in
between**.

Dart is single-threaded. With no yield point inside the critical section, two
concurrent callers cannot interleave: the race is made *structurally
impossible* rather than guarded against.

```dart
final prefs = await SharedPreferences.getInstance();
// ── critical section: no await from here to the write ──
final outcome = mutate(prefs.getString(key));
final write = outcome.value == null
    ? prefs.remove(key)
    : prefs.setString(key, outcome.value!);
// ── end critical section ──
await write;
```

`SharedPreferences` updates its in-memory cache **synchronously** when
set/remove is called, so the new value is visible to any concurrent caller
before this method yields again. That is measured, not assumed: twenty
concurrent mutations of one key all apply.

### The type system is the enforcement

`mutate` is a **plain synchronous function**, not a `FutureOr`. Code that tries
to await inside the critical section **does not compile**. The guarantee is not
a convention a future edit can quietly break.

### A REJECTED DESIGN, RECORDED SO IT IS NOT RETRIED

The first implementation used a **static per-key future chain** to serialise
callers, with an async mutation callback.

**It deadlocked.** `flutter_test` tears down a zone between tests; a chain entry
left behind by one test was awaited forever by the next. Widget tests that
record activity hung — a single 14-test file ran past ten minutes instead of
five seconds.

Two lessons, both recorded in the store's own doc comment:

- Static cross-test state plus cross-zone futures is a trap.
- The lock existed to survive a yield that only the async callback
  reintroduced. Removing the yield removed the need for the lock. The heavier
  design was **causing** the problem it was built to solve.

### What it does NOT own

It knows nothing about notifications, activity, intents, retention, or what any
collection means. Each repository keeps its own types, its own JSON and its own
semantics. The store owns exactly the critical section they were all missing,
and holds **no state of its own**.

## CLAIM FIRST, PRESENT SECOND

The single most important change in the milestone.

R49's `deliverDue` presented and **then** persisted the remainder. `await
present(...)` is a yield point, so a second caller entered while the due set was
still stored and delivered it again.

The due set is now **removed inside the serialised critical section** and
returned to the method, which presents **outside** it. A second caller arriving
afterwards finds nothing due.

### The trade, stated plainly

This makes delivery **at-most-once**, not at-least-once. If the process dies
between the claim and the presentation, that notification is not delivered and
will not be retried.

That is the correct trade here: the method's documented contract is *exactly
once*, a duplicate alarm is worse than a missed one, and the previous behaviour
was neither. Recorded as **G-38** rather than left implicit.

## A SECOND, UNRELATED DEFECT FIXED

`IntentRepository.updateStatus` and `.delete` read through `list()` — **default
limit 50** — and wrote the result back as the whole history. Retention allows
100. So with 51–100 intents stored, any status update silently discarded
everything past the 50th.

Nothing to do with concurrency; found because consolidating the pattern put
every read and write of that key side by side. Fixed by mutating the full stored
list inside the critical section.

## WHAT WAS DELETED

`lib/storage/local_database.dart` — `AnythingLocalDatabase` and
`AnythingPreferences`, **zero references** in `lib/` or `test/`.
`AnythingPreferences` also duplicated theme-mode persistence that
`ThemeProvider` really owns: a dead parallel implementation of a live feature.

Deleted, following R47's precedent for the dead runtime contract (G-01).

## OWNERSHIP AFTER R56

```
RealNotificationService ─┐
ActivityRepository      ─┼──> DurableCollectionStore ──> SharedPreferences
IntentRepository        ─┘         (ONE owner)

ThemeProvider ──────────────────────────────────────────> SharedPreferences
                            (one scalar key, no collection, PINNED — G-39)
```

Certified (I-75…I-77): exactly one store; the three collections may not name
`SharedPreferences` at all; presentation may not occur inside the critical
section.

## BACKWARD COMPATIBILITY

- Every new constructor parameter is optional and defaulted.
- No public method changed signature or observable single-threaded behaviour.
- Retention bounds unchanged and still owned by R50's engine — asserted (200
  activity, 100 intents).
- No schema change, no migration, no new dependency.
- All 2040 pre-existing tests pass unchanged.

## KNOWN LIMITATIONS

1. **The store serialises ONE KEY, not a transaction.** Two different keys
   mutate independently and cannot be made atomic with each other. Nothing
   currently needs that; inventing it would be speculative. Sibling of G-35.

2. **Delivery is at-most-once** (G-38). See the trade above.

3. **`ActivityRepository` still has no composition ownership** (G-37) — nine
   construction sites. R56 makes the lock instance-independent so this is not a
   correctness problem, but it remains the only repository that cannot be
   injected in production.

4. **`ThemeProvider` writes directly** (G-39). Pinned in certification with its
   reason: one scalar key, no read-modify-write, nothing to serialise.

5. **Only notifications were PROVEN defective.** Activity and intent were routed
   through the store to remove a duplicated pattern. R56 does not claim they
   were losing data, because the probe showed they were not.
