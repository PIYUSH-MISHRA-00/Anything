# IS-R58 — Canonical Certification Gate Framework

**Date:** 2026-08-08 · **Branch:** `v2.0.0` · `1617d29` → `8736ff3`
**Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

Before IS-R58 the repository had 89 architectural certification invariants and
40+ mutation proofs that **gated nothing**. CI's third step,
`dart format --set-exit-if-changed`, exited 1 against a repository where 424 of
668 Dart files were unformatted; the fourth step ran bare `flutter analyze`
under a name promising a baseline comparison it never performed, and also
exited 1. GitHub Actions halts a job at its first failing step, so
**`flutter test` had never executed in CI**.

IS-R58 changed no architecture. It made the existing architecture enforce
itself.

| | Before | After |
|---|---|---|
| `dart format --set-exit-if-changed` | **exit 1** (424/668 unformatted) | **exit 0** |
| Analyze step | bare `flutter analyze`, **could never pass** | `tool/analyze_gate.sh`, **passes at an explicit baseline** |
| Certification in CI | **never ran** | **its own named step** |
| Milestone guarantee suites in CI | never ran | own named step |
| Full suite in CI | **never reached** | runs with coverage |
| Invariants | 89 | **93** |
| Tests | 2,062 | **2,066** |
| Analyzer | 71 (0 err / 27 warn / 44 info) | **70** (0 / 27 / 43) |

**Four findings emerged that the audit had not seen, three of them larger than
what it reported.** They are in §17.

---

## 2. BEFORE / AFTER CI PIPELINE

**Before**
```
checkout → flutter pub get
  → dart format --set-exit-if-changed .     ← EXIT 1, job stops here
  → flutter analyze                          (never reached; would also exit 1)
  → flutter test --coverage                  (never reached)
```

**After**
```
checkout → flutter pub get
  → dart format --set-exit-if-changed .      exit 0
  → bash tool/analyze_gate.sh                explicit baseline; fails on any increase
  → flutter test <certification suite>       NAMED, independent step (93 invariants)
  → flutter test <R45–R57 guarantee suites>  NAMED, independent step
  → flutter test --coverage                  full suite
  → upload coverage
```

Certification is a **named** step on purpose: it previously would have been one
line inside a 2,000-test sweep.

---

## 3. COMMIT-BY-COMMIT CHANGE LOG

| Commit | Phase | Change |
|---|---|---|
| `199b471` | — | Record the two post-R57 audits (evidence base) |
| `964b47c` | 2 | Format 424 files + brace the 51 flow-control statements formatting splits |
| `778a5d0` | 3, 4, 6, 10 | `tool/analyze_gate.sh`; CI rewired; invariants I-81, I-82, I-83 |
| `aaa80b7` | 7 | Delete dead `contracts/knowledge_provider.dart` (+ barrel export, + its pin) |
| `5862145` | 7 | Delete `experience_spec_builder.dart`, `AcquisitionStatus`, `CreationPhase` |
| `140579d` | 8 | `SQLiteService.close()` + delegating `MemoryManager.close()` |
| `8736ff3` | 9 | Traceability map + invariant I-84 |

Each commit is independently reversible; each was validated before the next
began.

---

## 4. CERTIFICATION CHANGES

**89 → 93.** No invariant was weakened, removed or renamed.

| ID | Protects | Owning phase |
|---|---|---|
| **I-81** | CI runs formatting, the analyze gate, certification and the full suite — and certification is a *named independent step* | 10 |
| **I-82** | The analyze gate declares an explicit baseline, keeps errors at zero, and contains no `--no-fatal-*`, `exclude:` or `// ignore:` | 3 |
| **I-83** | Every declared type in `lib/` is declared once, or is a **pinned, individually justified** duplicate | 6 |
| **I-84** | Invariant IDs are traceable in **both** directions between source and the registry | 9 |

**I-83 replaced a check that scanned 13 of 1,263 types.** R47 built
`knownDuplicateDeclarations`, but the test consuming it iterated
`canonicalConstructionSites.keys`. I-83 scans every declared type and requires
each duplicate to carry a written reason.

---

## 5. NEW MUTATION PROOFS

| Probe | Target | Result |
|---|---|---|
| A — delete the certification step from `ci.yml` | I-81 | FAILED as required: *"without it, architectural certification does not run in CI at all"* |
| B — raise `BASELINE_ERRORS` above zero | I-82 | FAILED: *"the error baseline must be zero"* |
| C — add an 11th unpinned duplicate (`CommitResult`) | I-83 | FAILED: *"a type is declared in more than one file and is NOT pinned"* |
| D — register a non-existent `I-99` in the map | I-84 | FAILED: *"appear nowhere in certification … the map now protects nothing"* |

All four reverted; tree verified clean.

Two invariants also **fired on their own first run**, which is the practice
working rather than a defect:

- **I-83** found four collisions the post-R57 audit missed — `CapabilityCategory`,
  `NetworkMode`, `OfflineCapability`, `KnowledgeProvider` — because the audit's
  regex matched only `class` at line start and not enums or leading modifiers.
- **I-84** caught itself (unregistered) and a prose mention of a non-existent ID
  inside a code comment.

---

## 6. VALIDATION EVIDENCE

Run after every commit, never deferred.

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed .` | **exit 0** |
| `tool/analyze_gate.sh` | **exit 0** — 0 errors / 27 warnings / 43 infos, at baseline |
| Certification suite | **93 passed** |
| Full suite | **2,066 passed, 0 skipped** |
| `git status --porcelain` | empty |

---

## 7. ANALYZER BASELINE REPORT

**A correction that invalidates a claim in every report from R47 to R57 and in
both audits.** The baseline was never *"71 issues, all pre-existing
informational"*. Phase 1 re-measurement:

| Severity | Before R58 | After R58 |
|---|---|---|
| error | 0 | **0** |
| warning | **27** | **27** |
| info | 44 | **43** |
| **total** | **71** | **70** |

The 27 warnings: `unused_import` (11), `override_on_non_overriding_member` (7),
`unused_local_variable` (6), `unused_field` (2), `unused_element_parameter` (1).

The gate is built on the measured numbers. **Errors are gated at zero
absolutely.** Warnings and infos are gated at the documented counts; a drop is
reported but never fails, so fixing issues can never break the build.

---

## 8. DUPLICATE DECLARATION REPORT

**Thirteen pinned duplicates**, each with a written justification in
`pinnedDuplicateTypes`. Summary:

| Type | Why both exist |
|---|---|
| `NetworkMode` | **Different value sets** — `{none, optional, required, conditional}` (package manifest) vs `{none, restrictedHttps}` (architecture posture) |
| `OfflineCapability` | **Different value sets** — specification requirement vs architectural strategy |
| `ExperienceFingerprint` | R52 provenance digest vs a runtime-intelligence behavioural fingerprint |
| `ExecutionPlan` / `ExecutionStep` | Both live: contract version has 61 importers, planning version 7 — gap **G-44** |
| `ProtectionMetadata` | Contract version is a *suspected* dead duplicate — gap **G-46**. Not deleted, because *suspected ≠ proven* |
| `CapabilityCategory` | Contract vs registry enum — consolidation candidate, gap **G-47** |
| `AnythingPadding` | Same package, same concern — strongest merge candidate, gap **G-45** |
| `DependencyGraph`, `SemanticEntity`, `CreationFailed`, `CreationResult` | Genuinely different domains |

`KnowledgeProvider` was pinned in Phase 6 and **deleted in Phase 7**; its pin
was removed in the same commit, because I-83 fails on a stale pin.

**Pinning, not renaming, is deliberate:** renaming touches public API for types
with no proven defect, and R58 changes no architecture.

---

## 9. DEAD SURFACE REPORT

One item per commit, each proven before deletion.

| Item | Proof | Commit |
|---|---|---|
| `lib/core/contracts/knowledge_provider.dart` | Zero direct importers; both implementors resolve the capability declaration; nothing implements the contract version | `aaa80b7` |
| `lib/kernel/specification/experience_spec_builder.dart` | Entire file: 170 lines, one declaration, **zero importers, zero references** | `5862145` |
| `AcquisitionStatus` enum | One reference repository-wide: its own declaration | `5862145` |
| `CreationPhase` enum | Same | `5862145` |

**Four extensions were NOT deleted** despite a zero-name-reference count:
`BackendEngineeringPlanJson`, `CanonicalImplementationModelJson`,
`SemanticSolutionArchitectureJson`, `SolutionComponentJson`. Extensions are
invoked implicitly — `.toJson()` never names them. Proven **live** by a
different route: no receiver type declares its own `toJson`, and every
serialization file has real importers. Recorded so the correction is visible.

`knowledge_provider.dart` is the **third** dead contract removed from
`lib/core/contracts/` — after `runtime.dart` (R47) and `repository.dart` (R57).
The barrel now carries three comments explaining three identical removals.

---

## 10. LIFETIME VALIDATION

`SQLiteService` — owner of `anything_memory.db`.

- **Owner:** itself; it opens the handle lazily and is the only thing that may
  close it.
- **Disposal:** `close()`, idempotent, safe when no handle was opened.
- **Consumer:** `MemoryManager.close()` **delegates** rather than closing
  directly — disposal responsibility stays singular, no second closer.
- **Not composed**, per the phase instruction: no repository evidence requires
  it.

**All four database-handle holders now declare `close()`.**

---

## 11. ARCHITECTURAL DIFF — expected: none

**None.** Ownership, construction graph, lifetime graph, dependency graph,
capability graph, runtime graph, distribution, installation, commit, retention,
governance, trust, protection, repository composition, AI boundary, Kaalka and
WebWeaveX boundaries are **byte-for-byte unchanged in behaviour**. No subsystem
gained or lost a responsibility. The only deletions were proven-dead surfaces
that nothing referenced.

---

## 12. BEHAVIOURAL DIFF — expected: none

**None.** 2,062 pre-existing tests pass unchanged; the +4 are the new
invariants. Formatting was verified semantically neutral by an identical test
count immediately after it. The brace additions were applied by Dart's own
`dart fix`, not a hand-rolled transform.

---

## 13. API DIFF — expected: none

**None.** No public signature changed. `SQLiteService.close()` and
`MemoryManager.close()` are purely additive. `tool/analyze_gate.sh` is new
tooling, not API.

---

## 14. DOCUMENTATION DIFF

Only synchronisation; no prose rewritten, no wording modernised.

- **New:** `docs/audit/INVARIANT_TRACEABILITY.md` — the registry I-84 enforces.
- **New:** the two post-R57 audits committed as the evidence base.
- **Corrected:** the analyzer baseline claim (§7), in the commit that measured it.
- `contracts.dart` gained one comment recording the third contract removal.

---

## 15. RISK ASSESSMENT

| Risk | Status |
|---|---|
| Formatting churns 424 files, obscuring `git blame` | **Accepted**, isolated in one commit |
| The baseline (27/43) is hand-maintained | **Accepted** — same class as `currentRuntimeVersion`; one number in one file, versus a step that could never pass |
| CI may still go red on the pre-existing suite flakiness | **Reduced but unresolved** — see §17 |
| A future duplicate slips in | **Closed** by I-83 |
| Certification silently removed from CI | **Closed** by I-81 |
| The gate weakened by suppression | **Closed** by I-82 |
| The traceability map rots | **Closed** by I-84 |

---

## 16. ROLLBACK STRATEGY

Every commit is independently reversible and ordered so that later ones do not
depend on earlier semantics.

| To undo | Revert | Consequence |
|---|---|---|
| Traceability | `8736ff3` | 92 invariants; map removed |
| SQLite lifetime | `140579d` | `close()` removed; latent gap returns |
| Dead deletions | `5862145`, `aaa80b7` | dead surfaces return; `KnowledgeProvider` pin must be restored or I-83 fails |
| CI + invariants | `778a5d0` | CI returns to its unpassable form |
| Formatting | `964b47c` | 424 files unformatted; format gate fails again |

Reverting `964b47c` alone is safe. Reverting `778a5d0` while keeping `964b47c`
is also safe. **Reverting `aaa80b7` requires restoring the `KnowledgeProvider`
pin**, because I-83 fails on an unpinned duplicate — that coupling is
intentional.

---

## 17. REMAINING GAPS

Four findings emerged during implementation that the audit had not seen. Three
are larger than what it reported.

| # | Sev | Finding | Evidence |
|---|---|---|---|
| **G-48** | **HIGH** | **An entire parallel subsystem is unreachable.** 28 files import `flutter_riverpod`; a Riverpod provider resolves only inside a `ProviderScope`; **there is no `ProviderScope` anywhere in `lib/` or `test/`** — `main.dart` calls `runApp(const AnythingApp())` directly. `lib/screens/` (13 files, 2,335 lines) is entirely `ConsumerWidget`/`ConsumerStatefulWidget` and is referenced by **nothing** in `lib/features/`, `lib/app/` or `main.dart`. | measured Phase 8 |
| **G-49** | MEDIUM | **Traceability is ~4%.** 80 documented IDs; 15 appear in source; 3 tagged in test names. The audit called this "I-79 is documented but absent" — it understated it 68-fold. I-84 stops it growing; 68 IDs remain unregistered. | measured Phase 9 |
| G-44…G-47 | LOW–MED | Four pinned duplicates that are consolidation candidates: `ExecutionPlan`/`Step`, `ProtectionMetadata` (suspected dead), `CapabilityCategory`, `AnythingPadding` | §8 |
| **G-40** | — | **The suite flakiness did not reproduce.** Phase 5 measured **0 failures in 22 runs** of `r43`+`r44` with 6,189 test databases present, against 8 failures in 33 runs across R55/R57. **Per Phase 5's rule — fix only if measurable — NO FIX WAS IMPLEMENTED.** Why it stopped reproducing **cannot be established from the repository**. | measured Phase 5 |

Carried forward unchanged: G-35, G-38, G-39, G-41, G-42, G-43; four unused
dependencies (`url_launcher`, `shimmer`, `record`, `cupertino_icons`); 7 of 8
asset directories are empty placeholders.

---

## 18. RECOMMENDATION FOR IS-R59

### Resolve the unreachable Riverpod subsystem (G-48)

It is now the largest architectural question in the repository, and it is
exactly the "parallel implementation" that R46–R57 spent eleven milestones
eliminating elsewhere — hiding in plain sight because it is *unreachable* rather
than duplicated.

**Scope it as an audit-first milestone**, because the deletion set cannot be
proven from a single scan:

1. Prove reachability for every one of the 28 Riverpod files, individually.
2. Separate genuinely dead files from those a future `ProviderScope` would
   revive.
3. Delete only what is proven, one item per commit, as R58 Phase 7 did.
4. If any of it is *intended* to be live, the defect is the missing
   `ProviderScope` — and that is a different, smaller fix.

**Do not** attempt G-49's retro-tagging in the same milestone: 89 mappings
verified against 12 milestone reports is its own body of work, and a wrong
mapping is worse than none.

**Explicitly rejected for R59:** consolidating the four pinned duplicates
(public API churn, no proven defect), and re-attempting G-40 (not currently
measurable — re-open only if it recurs).

---

## CONCLUSION

IS-R58 increased architectural certainty without changing the architecture.

Ownership, behaviour and public API are unchanged. What changed is that the 93
invariants, the mutation proofs and the 2,066 tests **now run on every commit**,
and four new invariants make it impossible to quietly remove them, weaken the
gate, introduce an undocumented duplicate type, or let the invariant registry
rot.

The certification layer stopped being a convention with a test harness attached.
