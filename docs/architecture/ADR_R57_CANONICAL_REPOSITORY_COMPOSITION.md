# ADR — IS-R57: Canonical repository composition

**Status:** Accepted · **Date:** 2026-08-07 · **Milestone:** IS-R57

## Context

R46–R56 canonicalised ownership across thirteen subsystems. R56's audit left
one repository without a composition owner — `ActivityRepository`, constructed
in nine places — and explicitly recommended fixing it next.

R57 is that milestone. Its own final principle: *if the audit proves a proposed
change unnecessary, do not implement it; record the clean result instead.*

## Decision 1 — Distinguish a defaulted SEAM from a bare CONSTRUCTION

The obvious reading of "no repository constructed outside approved locations"
would ban `activity ?? ActivityRepository()` in every coordinator.

**Rejected.** That pattern is the optional-injection seam this codebase has
used since R32. Removing it would:

- change public constructors (forbidden — backward compatibility is mandatory),
- break every test that relies on defaults,
- and gain nothing, because the composition now passes its instance, so the
  default never fires in production.

**Decision:** certification forbids a **bare** construction (no `??`, no
`const` default) and permits a defaulted seam. The nine `ActivityRepository`
sites split cleanly: six were already seams, three were bare. Only the bare
ones were defects.

This is the distinction that makes the invariant enforceable without an API
break, and it is why the rule is written in terms of *seams* rather than
*locations*.

## Decision 2 — Compose `IntentRepository` too, because the invariant found it

I wrote the invariant for `ActivityRepository`. On first run it failed on
`IntentRepository` in `HomeScreen` — a bare construction, and a repository with
no composition owner that R56's audit had not flagged.

**Decision:** compose it as well. The invariant found a real instance of the
same defect, and narrowing the rule to spare it would have been exactly the
"narrow until green" failure this project has refused since R47.

## Decision 3 — Do NOT compose `ExperienceDatabase` or `DurableCollectionStore`

`ExperienceDatabase` is **per Experience**, created by `DataRuntime` with the
Experience's id. Composing it would require a factory keyed by id — an
abstraction with one implementation, which this milestone forbids.

`DurableCollectionStore` is stateless and `const` (R56), so instances are
interchangeable. Composing a value object is ceremony, and R56's I-75 already
certifies that only one exists.

**Decision:** record both as deliberate non-owners in the ownership matrix,
with the reason, rather than composing them for symmetry.

## Decision 4 — Delete two dead files, not one

Phase 4 named `MinimalKernel`. The audit found it dead (2 references, both its
own declaration) — and found a second, larger case the specification did not
anticipate:

`lib/core/contracts/repository.dart` — **four abstract contracts, twenty
methods, ZERO implementations**, reachable only through a barrel re-export. One
of them, `IntentRepository`, **collided by name** with the live
`lib/storage/intent_repository.dart`, so any file importing both would have
failed with `ambiguous_import` — the same latent trap R54 hit with a duplicated
constant.

This is precisely the shape R47 deleted (`contracts/runtime.dart`), and the
barrel still carries R47's comment explaining that removal.

**Decision:** delete both, and certify they stay deleted plus that
`IntentRepository` now declares exactly once.

## Decision 5 — Keep the `HomeScreen` repository fix even though it fixed nothing measurable

`HomeScreen` built its own `SqliteExperienceRepository` while already holding
the composition. I hypothesised this was the mechanism behind G-40's
`database is locked` flakiness and measured it:

```
with the fix : 3 failures / 11 runs
before       : 3 failures / 11 runs   (R56), 2 / 11 (R55)
```

**Hypothesis disproved. No improvement.**

**Decision:** keep the change on ownership grounds — a screen holding the
composition must not build its own repository — and claim **nothing** about
G-40, which remains open and unexplained.

## Consequences

**Positive**
- Every repository now has exactly one composition owner, or a recorded reason
  for not having one.
- Three bare UI constructions and two rogue `HomeScreen` constructions removed.
- Two dead files deleted, one of which was a latent compile-breaking name
  collision.
- Three invariants, five mutation probes.
- Behaviour unchanged: 2059 pre-existing tests pass untouched.

**Negative / accepted**
- Constructor defaults remain, so multiple instances are still *possible* when
  a caller injects nothing. By design; see Decision 1.
- `EvolutionCoordinator` is not composed — nothing constructs it in `lib/` at
  all, so composing it would be speculative.
- G-40 remains open, and R57's attempt to explain it failed.
