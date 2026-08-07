# Experience Commit Certification — IS-R55

Enforced by `test/r46_architectural_integrity_certification_test.dart`
(76 → **83** tests).

## The seven invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-68 | Exactly ONE commit framework and ONE transaction coordinator | STATIC | CERTIFIED |
| I-69 | **NOBODY outside the commit framework writes to the Experience repository** | STATIC | CERTIFIED |
| I-70 | EVERY write inside the commit framework runs in a transaction | STATIC | CERTIFIED |
| I-71 | The commit framework persists and does nothing else | STATIC | CERTIFIED |
| I-72 | Exactly ONE rollback owner — every other rollback delegates | STATIC | CERTIFIED |
| I-73 | Exactly ONE repair owner — the installer requests | STATIC | CERTIFIED |
| I-74 | The repository stores only and does not know the framework exists | STATIC | CERTIFIED |

## I-69 — the invariant this milestone exists for

This is what closing G-30 actually means: not "a commit framework exists" but
**"nothing else can write"**.

It scans every file in `lib/` except the framework and the repository for calls
to `savePackage`, `saveMetadata`, `deletePackage`, `saveProtectedEnvelope`,
`deleteProtectedEnvelope` and `updateProtectionState`, plus any `delete(`
called on something named like the Experience repository.

`delete(` is deliberately not scanned bare — it is far too common a word, and a
pattern that matched `list.delete(` everywhere would be noise, not enforcement.

### `touchLastUsed` is pinned, not omitted

It is excluded **in the test, with the reason written there**: it stamps an
access time on an existing row, persists no package or metadata record, and
holds no state a rollback could need. Four call sites routed through a commit
framework to bump a timestamp is ceremony without benefit.

Recorded as **G-34** so the exclusion is reviewable. The discipline is the same
one that has applied since R47: pin the real set with rationale, never narrow
the pattern until it passes.

## I-70 — the invariant that keeps Task 7 honest

A write inside the framework that forgot `using:` would silently fall back to
the raw database and reopen G-28's crash window **for that path only** — the
hardest kind of regression to notice, because every test would still pass and
the architecture documents would still be accurate about intent.

So certification extracts each `repository.<write>(...)` call in the framework
and asserts its arguments contain `using:`. It first asserts the scan found at
least seven sites, so a regex that stopped matching fails loudly instead of
certifying nothing.

It also requires `db.transaction` to appear — the coordinator must use
sqflite's own transaction rather than a hand-rolled one.

## I-72 / I-73 — "exactly one owner" without deleting useful API

There are four `rollback` methods and two `repair` methods in `lib/`, and that
is correct: the extras are façades in installation, modification and
transaction vocabulary.

An invariant demanding literally one method would have forced deleting API that
callers legitimately use. Instead:

- the set of **files** declaring each is pinned, so one appearing somewhere new
  fails;
- each façade is required to reach the commit framework;
- and I-69 already guarantees none of them can write.

Combined, "exactly one owner" is mechanically true: only one file can write, so
only one file can actually roll back or repair anything.

## Mutation evidence

Five probes. Every one failed as required.

### Probe A — a second commit framework

```dart
lib/r55_mutation_probe.dart:  class ExperiencePersistenceCommitEngine {}
```
```
I-68  a second commit framework or transaction coordinator appeared:
      [..., lib/r55_mutation_probe.dart:ExperiencePersistenceCommitEngine]
```

### Probe B — creation committing directly again

Restoring `await _repository.savePackage(package);` in the creation coordinator.

**RESULT: WOULD NOT COMPILE.**

```
lib/app/creation_coordinator.dart:459:13: Error: The getter '_repository'
isn't defined for the type 'ExperienceCreationCoordinator'.
```

This is the strongest result in the milestone and worth stating plainly:
**creation can no longer write even if someone tries.** Its repository field
was removed once the writes moved, so a direct commit is not merely forbidden
by certification — it does not typecheck. Certification is the guard for paths
that still legitimately hold a repository for reads; the type system is the
guard here.

### Probe B2 — protection committing directly

Protection *does* still hold a repository (for reads), so this is the probe that
exercises I-69 rather than the compiler.

```dart
await _repository.deletePackage(experienceId);   // restored before the commit
```
```
I-69  gap G-30 reopened — these write Experience state without going through
      the ONE commit owner: [lib/security/protection_service.dart:deletePackage@7971]
```

### Probe C — the UI write restored

The site the audit found, put back:

```dart
await _repo.delete(exp.id);
```
```
I-69  gap G-30 reopened — these write Experience state without going through
      the ONE commit owner: [lib/features/experiences/experiences_screen.dart:delete@9989]
```

### Probe D — a write escaping its transaction

The subtlest possible regression: one `using: txn` dropped inside the framework.

```dart
if (metadata != null) await repository.saveMetadata(metadata);   // no `using:`
```
```
I-70  Expected: contains 'using:'
        Actual: 'metadata'
      commit-framework write "saveMetadata" does not pass a transaction
      executor; it would fall back to the raw database and reopen G-28 for
      that path
```

Note what this probe proves that a behavioural test could not: the code still
*works*, both rows still land, and every functional test still passes. Only the
atomicity guarantee is gone. Without I-70 this would have shipped silently.

## Cleanup

All probes removed; `git status --porcelain` shows only the intended R55
changes. Everything was `git add`-ed **before** probing (the R53 lesson, applied
for the second milestone running), so `git checkout --` reverted each probe
properly. Residue verified absent by grep.

## What this certification cannot catch

- **Whether a commit *should* have happened.** It proves only one thing writes.
  Whether creation was right to create is not a persistence question.
- **Atomicity beyond the repository.** World Model ingestion and
  engineering-memory persistence remain separate and best-effort. No static
  check can make them atomic with a repository write, and R55 does not claim
  they are.
- **A torn database that R55 did not cause.** Repair exists for exactly that
  and cannot be proven necessary by a static scan.
- **The `touchLastUsed` exclusion being the right call.** That is a judgement,
  recorded as G-34 for review rather than settled by a test.
