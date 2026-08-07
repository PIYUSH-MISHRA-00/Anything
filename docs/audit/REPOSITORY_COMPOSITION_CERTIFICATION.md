# Repository Composition Certification — IS-R57

Enforced by `test/r46_architectural_integrity_certification_test.dart`
(86 → **89** tests).

## The three invariants

| # | Invariant | Mechanism | Status |
|---|---|---|---|
| I-78 | Every repository is constructed ONLY in its approved sites | STATIC | CERTIFIED |
| I-79 | `AppComposition` owns exactly ONE `ActivityRepository` and hands it out | STATIC | CERTIFIED |
| I-80 | The dead repository contracts and `MinimalKernel` are gone and stay gone | STATIC | CERTIFIED |

## I-78 — the rule is about SEAMS, not locations

A construction preceded by `??` or `const` is a **defaulted injection seam** —
the pattern this codebase has used since R32 — and is allowed. A **bare**
construction is not: it means production cannot share the composition instance
and a test cannot substitute one.

That distinction is what lets the invariant be enforced without an API break.
The nine pre-R57 `ActivityRepository` sites split six seams / three bare; only
the bare ones were defects.

**The invariant found a defect on its first run** that the R56 audit had not:
`IntentRepository` constructed bare in `HomeScreen`, with no composition owner
either. It was composed rather than excluded.

## I-79 — three clauses, because one would be decoration

1. the composition constructs **exactly one** `ActivityRepository`;
2. it **exposes** it as a field;
3. it **passes** it to at least four coordinators it builds.

Clause 3 matters: a composition could satisfy 1 and 2 and still hand nothing
out, leaving every consumer on its default. Ownership that nobody receives is
not ownership.

## I-80 — deletion that stays deleted

Deleted by R57:

- `lib/core/contracts/repository.dart` — 4 abstract contracts, 20 methods,
  **zero implementations**, reachable only via a barrel re-export.
  `IntentRepository` among them **collided by name** with the live storage
  repository, so importing both would have failed to compile.
- `lib/kernel/minimal_kernel.dart` — G-02, open since R47.

The invariant asserts both files are absent, that the barrel does not
re-export `repository.dart` again (the dangling-export mistake R47's deletion
made, which only the analyzer caught), and that `IntentRepository` now declares
**exactly once** repository-wide.

## Mutation evidence

Five probes, all failed as required.

### Probe A — a repository constructed from the UI, no seam

`ActivityScreen` restored to `final ActivityRepository _repository = ActivityRepository();`

```
I-78  Actual: ['lib/features/activity/activity_screen.dart:ActivityRepository']
      these construct a repository with NO injection seam, so production cannot
      share the composition instance and a test cannot substitute one
```

### Probe B — the repository registered twice in the composition

```dart
const activityRepository = ActivityRepository();
const secondActivityRepository = ActivityRepository();
```
```
I-79  Expected: <1> / Actual: <2>
      the composition must build exactly one activity repository; found 2
```

### Probe C — a repository constructed from the RUNTIME layer

`ExperienceHostScreen`'s seam removed.

```
I-78  Actual: ['lib/runtime/experience_host_screen.dart:ActivityRepository']
```

### Probe D — the composition registration removed

**RESULT: WOULD NOT COMPILE.**

```
lib/app/app_composition.dart:250:19: Error: 'activityRepository' isn't an
  instance field of this class.
lib/features/experiences/experiences_screen.dart:83:30: Error: The getter
  'activityRepository' isn't defined for the type 'AppComposition'.
lib/features/home/home_screen.dart:311:36: Error: same
```

Worth recording: removing the registration now breaks the build in **three
places**, precisely because consumers RECEIVE the instance instead of building
their own. The type system is the stronger guard, and it only became one once
the ownership was real — the same result R55 got when creation's repository
field was deleted.

### Probe E — a repository constructed from a CAPABILITY

```
I-78  Actual: ['lib/capabilities/builtin/notification_capability.dart:ActivityRepository']
```

## Cleanup

All probes reverted; residue verified absent by grep (`_rogue`,
`secondActivityRepository`, `probe:`). Everything was `git add`-ed before
probing, and re-staged after each revert — the R56 lesson, where a `stash pop`
between staging and probing silently invalidated the checkout.

## What this certification cannot catch

- **Multiple instances arising from constructor defaults.** By design
  (ADR Decision 1). A caller that injects nothing still gets its own.
- **Whether a repository SHOULD be composed.** `ExperienceDatabase` (per
  Experience) and `DurableCollectionStore` (stateless value) are deliberately
  uncomposed; that judgement is recorded in the ownership matrix, not tested.
- **G-40.** R57 hypothesised that `HomeScreen`'s own repository caused the
  `database is locked` flakiness, measured it, and **disproved it** — 3
  failures / 11 runs with and without the fix.
