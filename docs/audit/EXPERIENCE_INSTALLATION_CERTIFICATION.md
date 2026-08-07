# Experience Installation Certification — IS-R54

Enforced mechanically by `test/r46_architectural_integrity_certification_test.dart`
(68 → **76** tests).

## The eight invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-61 | Exactly ONE installation framework, ONE compatibility evaluator, ONE dependency planner | STATIC | CERTIFIED |
| I-62 | The installer never computes trust, enforces governance or performs distribution | STATIC | CERTIFIED |
| I-63 | The evaluator and the planner are PURE — they cannot install | STATIC | CERTIFIED |
| I-64 | INSTALL NEVER ACTIVATES | STATIC | CERTIFIED |
| I-65 | The transaction DELEGATES structural validation | STATIC | CERTIFIED |
| I-66 | No second migration engine; the installer executes none | STATIC | CERTIFIED |
| I-67 | DISTRIBUTION NEVER COMMITS | STATIC | CERTIFIED |
| — | The installer REQUESTS protection and never performs it (Task 7) | STATIC | CERTIFIED |

## I-57 tripped on its own, and was widened rather than narrowed

R53's I-57 pattern already included `Install`:

```
\w*(?:Distribution|Import|Export|Install)\w*(?:Framework|Engine|Pipeline|Manager|Service)
```

so `ExperienceInstallationFramework` failed it on its first run. **That is the
invariant working, not a false positive.** The pinned set was widened to three
with the reason recorded in the test itself; the regex was not touched, so a
fourth mover still fails.

This is the fifth time across R47–R54 that an "exactly one X" check has fired
first-run against a legitimate sibling. The discipline holds: **pin the real set
with rationale, never narrow the pattern until it passes** — that leaves an
invariant that looks green and checks nothing.

## I-61 — three clauses, each independently proven

Each clause pins the real, pre-existing set rather than excluding it:

- **Installers** — exactly one.
- **Compatibility** — four entries. `CompatibilityCheck`
  (`artifact_intelligence`) is a cross-artifact invariant record in the compiler
  pipeline, a genuinely different domain from Experience installability.
- **Dependencies** — nine entries. The eight pre-existing types expand a
  *feature candidate* into primitives during design, or analyse the world
  graph. Pinned so the distinction stays deliberate.

## I-63 — why a class-body check, not a file check

The framework, the evaluator and the planner live in one file, and the
framework legitimately holds a repository. A whole-file "must not contain
`SqliteExperienceRepository`" check would therefore be impossible to satisfy,
and a whole-file "may contain" check would be **vacuous**.

So certification extracts the evaluator's and the planner's own class bodies by
brace matching and asserts each holds no repository, no protection service, no
transaction and no `savePackage`/`saveMetadata`. The helper returns `''` when a
class is missing and the test asserts non-empty first, so a renamed class fails
loudly instead of certifying nothing.

## I-67 — the invariant that keeps the commit where R54 put it

R53 wrote both repository rows from the distribution framework. R54 took that
back. I-67 asserts `savePackage`, `saveMetadata` and `repository.delete` appear
nowhere in the distribution file, **and** that it names
`ExperienceInstallationFramework` — so the commit must go *through* the
installer rather than simply being deleted.

Note this runs on stripped source, so the doc comment in that file which
mentions `savePackage` does not trip it.

## Mutation evidence

Seven probes. Every one failed as required.

### Probe A — a parallel installer

```
lib/r54_mutation_probe.dart:  class ExperienceInstallPipeline {}

I-61  a second installer/updater appeared:
      [lib/app/experience_installation.dart:ExperienceInstallationFramework,
       lib/r54_mutation_probe.dart:ExperienceInstallPipeline]
```

### Probe A2 — a duplicate compatibility evaluator

Run separately, because `expect` short-circuits: if only the installer clause
had been probed, the other two clauses would be unproven.

```
lib/r54_mutation_probe.dart:  class ExperienceCompatibilityEngine {}

I-61  a second compatibility engine appeared: [… , lib/r54_mutation_probe.dart:ExperienceCompatibilityEngine]
```

### Probe A3 — a duplicate dependency planner

```
lib/r54_mutation_probe.dart:  class PackageDependencyPlanner {}

I-61  a second dependency planner appeared: [… , lib/r54_mutation_probe.dart:PackageDependencyPlanner]
```

### Probe B — the installer computing trust

```dart
ExperienceTrustLevel trustFor(String id) => ExperienceTrustLevel.imported;
```

```
I-62  Expected: false / Actual: <true>
      the installer commits only; referencing ExperienceTrustLevel would make
      it a second owner of that subsystem
```

### Probe C — the installer activating a runtime

First result: **would not compile** — `Navigator` is not imported, because it
must not be. The type system enforced the boundary before certification ran, as
it did for R53's probe B.

With `package:flutter/material.dart` added so the probe compiles:

```
I-64  Expected: false / Actual: <true>
      installing something must not run it; referencing Navigator would make
      install an activation path
```

### Probe D — the installer protecting directly

Also failed to compile first (`ProtectionProvider` not imported). With
`core/contracts/protection_provider.dart` added:

```
Task 7  Expected: false / Actual: <true>
        the installer requests protection; touching ProtectionProvider would
        open a second crypto path
```

### Probe E — distribution committing again

```dart
await repository.savePackage(distribution.package);   // restored in import()
```

```
I-67  Expected: false / Actual: <true>
      distribution moves experiences; calling savePackage would restore the
      second commit path R54 removed
```

## Cleanup

All probes removed; `git status --porcelain` shows only the intended R54
changes. **Applying the R53 lesson: everything was `git add`-ed BEFORE probing**,
so `git checkout --` could actually revert each probe — on R53 the target file
was still untracked and the revert silently no-opped, requiring manual cleanup.
Residue was verified absent by grep regardless.

## What this certification cannot catch

- **Whether an install is safe.** It proves ownership boundaries hold. Whether
  a package should be installed is R52's (trust) and R51's (policy) question.
- **Torn state after a crash.** The compensating transaction's weakness (G-28)
  is a runtime property no static check can see. `repair()` addresses it;
  certification cannot prove it was needed.
- **That `currentRuntimeVersion` is correct.** Nothing ties it to `pubspec.yaml`
  (G-29).
- **That the other four commit sites are wrong.** Creation, modification,
  evolution and protection still commit directly (G-30). Certification records
  that the installer exists and owns *its* path; it does not claim committing is
  unified, because it is not.
