# ADR — IS-R59: Canonical runtime reachability

**Status:** Accepted · **Date:** 2026-08-08 · **Milestone:** IS-R59

## Context

IS-R58 found that no `ProviderScope` exists while 28 files import Riverpod, and
that `lib/screens/` is referenced by nothing in the live shell. It recorded this
as gap G-48 and recommended proving reachability per file.

R59 measured it: **110 of 466 `lib/` files (23.6%) were unreachable from
`main()`**, spread across 29 directories, with no classification at all.

## Decision 1 — Compute reachability, do not infer it

Reachability is established by **transitive import closure from the single
entry point**, implemented in `tool/reachability.py` and recomputed inside
certification by I-86. Nothing is classified by intuition or directory name.

**Rejected:** classifying by folder (`lib/screens/` = dead). It would have been
wrong — `lib/screens/app_shell.dart` has four importers and is EXPERIMENTAL,
not dead, while `lib/world_model/semantic_entity.dart` sits in a live directory
and is unreachable.

## Decision 2 — Five classes, no UNKNOWN

Every file is REACHABLE, DORMANT, EXPERIMENTAL, DEPRECATED or DEAD. I-86 fails
if any file falls outside, so the unknown state cannot return.

The discriminator that matters is **test references**: a file unreachable from
`main()` but imported by tests is DORMANT, not dead. 43 files are in that
position and deleting them would have destroyed covered behaviour.

## Decision 3 — Delete only what type-name analysis also confirms

Import closure identified 16 dead files. Type-name verification reduced that to
14 (later 15, via a cascade). The two excluded — `layout.dart` and
`semantic_entity.dart` — are unreachable and unimported, but the types they
declare collide by name with live declarations, producing 36 and 167
unattributable references.

**Decision:** do not delete them. Pin them in `pinnedUnreachableFiles` with the
reason, so I-86 keeps them visible instead of letting them sit unknown.

**Rejected:** deleting on import evidence alone. Import analysis said dead;
name analysis could not confirm. *Suspected ≠ proven*, and Phase 8 requires
proof.

**Rejected:** adding an AST/analyzer dependency to resolve two files. Not
justified for two files, and consistent with documented limitation L-01.

## Decision 4 — Certify the absence of a `ProviderScope`

I-85 asserts one entry point, one app widget, and **no `ProviderScope`
anywhere**.

The third clause is the load-bearing one. Adding a `ProviderScope` would revive
~50 disconnected files simultaneously — every unresolvable provider would start
resolving, and eleven milestones of composition ownership would suddenly have a
parallel dependency-injection graph beside it. That must be a deliberate,
reviewed act. It is now impossible to do silently.

**Rejected:** deleting the parallel subsystem. ~50 mutually-referencing files
meet no proof standard, and the ABSOLUTE RULES forbid migrating to or away from
Riverpod.

**Rejected:** adding a `ProviderScope` to "fix" it. That is a redesign, which
this milestone forbids, and would revive code nobody has reviewed.

## Decision 5 — Delete one group, validate, repeat

Four validated deletion commits rather than one batch. This surfaced a
**cascade**: removing `splash_screen.dart` made `onboarding_screen.dart` dead,
which a single batch pass would have missed.

## Consequences

**Positive**
- Zero unknown runtime states; 15 dead files removed with proof.
- Two new invariants, both mutation-proven.
- Reproducible tooling (`tool/reachability.py`, `classify_reachability.py`,
  `provider_census.py`) — the analysis can be re-run, not just re-read.
- A second entry point, second app widget, or stray `ProviderScope` now fails
  certification.

**Negative / accepted**
- ~50 EXPERIMENTAL files remain, carrying maintenance and analyzer weight.
- Two DEAD files remain, pinned, pending type-aware analysis.
- 43 DORMANT files are tested but unreachable — their tests assert behaviour no
  user can reach.
