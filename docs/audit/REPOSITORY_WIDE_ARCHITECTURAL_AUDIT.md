# Repository-Wide Architectural Audit — Anything v2.0.0

**Date:** 2026-08-07 · **Branch:** `v2.0.0` @ `1617d29` (post-IS-R57)
**Mode:** Audit only. **No source file was modified.**

**Scope limit, stated first:** no ZIP archive was supplied in this session. This
audit covers the working repository at `C:\Projects\Anything` (1,147 tracked
files) and its git history (235 commits). Any archived branch, experiment or
generated artefact existing only inside an unsupplied ZIP **has not been
examined and no claim is made about it.**

---

## 1. EXECUTIVE SUMMARY

The architecture is in strong shape. Eleven milestones (R46–R57) eliminated
duplicate ownership across thirteen subsystems, and this audit confirms those
guarantees hold: 89 certification invariants pass, 2,062 tests pass, the
analyzer baseline is unchanged at 71, and 1,256 of 1,263 declared public types
are live.

**Three findings materially change the picture.**

**FINDING 1 — CRITICAL. Continuous integration cannot pass, and never could.**
`.github/workflows/ci.yml` runs `dart format --set-exit-if-changed` as step 3
of its main job. Measured: **exit code 1, 424 of 668 Dart files unformatted.**
Step 4 (`flutter analyze`) also exits 1 against the documented 71-issue
baseline. GitHub Actions halts a job at its first failing step, so **`flutter
test` has never executed in CI.**

The consequence is the single most important fact in this audit: **the entire
certification layer — 89 invariants, 40+ mutation proofs, eleven milestones of
mechanical enforcement — gates nothing.** It runs only when a developer runs it
locally. Every "certified" claim in every matrix is true of the code today and
enforced by nobody tomorrow.

**FINDING 2 — HIGH. The duplicate-declaration invariant covers 13 of 1,263
types, and 10 name collisions are live behind it.** R47 built
`knownDuplicateDeclarations` to prevent a second `AnythingRuntime`. The check
iterates `canonicalConstructionSites.keys` — thirteen pinned types — so 99% of
the type surface is unscanned. Ten classes are currently declared in two files
each, including `ExperienceFingerprint` (R52's canonical provenance digest).

**FINDING 3 — HIGH. `lib/core/contracts/` still holds a dead, colliding
contract — the third instance of a pattern already fixed twice.** R47 deleted
`contracts/runtime.dart`; R57 deleted `contracts/repository.dart`.
`contracts/knowledge_provider.dart` is the same shape: zero direct importers,
and both real implementors implement the *other* `KnowledgeProvider` from
`capabilities/builtin/knowledge_capability.dart`.

**Recommended next milestone (§14):** repair CI first. It is the highest
architectural value in the repository and the lowest risk, because it changes
no architecture at all.

---

## 2. REPOSITORY STATISTICS

| Metric | Value | Evidence |
|---|---|---|
| Tracked files | 1,147 | `git ls-files \| wc -l` |
| Dart files | 668 (`lib` 468, `test` 200) | `git ls-files` by extension |
| Dart lines | 121,655 (`lib` 65,246, `test` 56,409) | `xargs cat \| wc -l` |
| Markdown | 185 (`docs` 148, `lib` READMEs 25, other 12) | file index |
| Design assets | 163 (`design/stitch/`, 118 png + 80 html + DESIGN.md) | `git ls-files design` |
| Declared public types in `lib` | 1,263 | regex over class/enum/mixin/extension |
| Tests | **2,062 passing, 0 skipped** | `flutter test` |
| Certification invariants | **89** | certification suite run |
| Analyzer issues | **71** (baseline, unchanged) | `flutter analyze` |
| Commits on branch | 235 | `git rev-list --count HEAD` |
| Direct dependencies | 22 | `pubspec.yaml` |
| Test:source ratio | 0.86:1 by line | derived |

**Test-to-source ratio of 0.86:1 is unusually high and is a genuine strength.**

---

## 3. COMPLETE ARCHITECTURE GRAPH

```
AppComposition.production()                          ← the ONE composition root
  │
  ├── SqliteExperienceRepository ─┬─ WorldModelRepository
  │                               ├─ EngineeringMemoryRepository
  │                               └─ ExperienceCommitFramework   ← ONLY writer (R55)
  │                                      └─ RepositoryTransactionCoordinator
  │                                             ├─ ExperienceProtectionService (Kaalka)
  │                                             └─ ExperienceInstallationFramework (R54)
  │                                                    └─ ExperienceDistributionFramework (R53)
  ├── ActivityRepository ──┐
  ├── IntentRepository ────┤ (R57)   └─ DurableCollectionStore (R56) → SharedPreferences
  ├── KnowledgeRepository ─┴─ KnowledgeCache → RetentionPolicyEngine (R50)
  ├── CredentialVault → FlutterSecureStorage
  ├── CapabilityPlatform ← OperatingSystemGovernanceEngine (R51)
  │                      ← ExperienceTrustClassifier (R52)
  ├── ExperienceEntryPipeline (R45) → ExperienceActivationManager
  │                                 → WorkspaceSchedulingEngine → WorkspaceRuntimeSupervisor
  ├── AnythingKernel → ApplicationReasoner → ModelProvider   ← the ONE AI boundary
  └── EventBus

DataRuntime (per Experience) → ExperienceDatabase(experienceId)   ← per-Experience, by design
AnythingRuntime ← constructed in exactly ONE place (experience_host_screen.dart:205)
```

**Cycles: none.** Verified — no repository imports a coordinator, capability,
screen or the composition. Direction is strictly
`composition → coordinators/screens → frameworks → repositories → backends`.

**Cross-layer references found:** none outstanding. R57 removed the last five
(UI and runtime constructing repositories).

---

## 4. REPOSITORY OWNERSHIP AUDIT

| Repository | Composition owner | Write owner | Retention | Bare constructions |
|---|---|---|---|---|
| `SqliteExperienceRepository` | `AppComposition:238` | **`ExperienceCommitFramework` only** | — | 0 |
| `ActivityRepository` | `AppComposition` (R57) | itself via store | R50 engine | 0 *(was 9)* |
| `IntentRepository` | `AppComposition` (R57) | itself via store | R50 engine | 0 *(was 1)* |
| `KnowledgeRepository` | `AppComposition:256` | `KnowledgeCache` | R50 engine | 0 |
| `WorldModelRepository` | `AppComposition:242` | `WorldModelCoordinator` | — | 0 |
| `EngineeringMemoryRepository` | `AppComposition:371` | coordinators | — | 0 |
| `CredentialVault` | `AppComposition:239` | itself | — | 0 |
| `ExperienceDatabase` | **none — deliberate** | `DataRuntime` | — | 1 (per Experience) |
| `DurableCollectionStore` | **none — deliberate** | n/a (stateless) | — | n/a |

**Verdict: CANONICAL.** Every repository has one composition owner or a
recorded reason for not having one. This area needs no further work, and that
clean result is recorded rather than converted into invented scope.

---

## 5. LIFECYCLE AUDIT

| Lifetime | Repositories |
|---|---|
| Singleton (composition) | Sqlite, Activity, Intent, Knowledge, WorldModel, EngineeringMemory, CredentialVault |
| Per Experience | `ExperienceDatabase` |
| Stateless value (`const`) | `ActivityRepository`, `IntentRepository`, `DurableCollectionStore` |
| Disposable (holds an OS handle) | Sqlite, Knowledge, WorldModel, EngineeringMemory, ExperienceDatabase |

**No double-close hazard.** Verified: no screen disposes a repository it did
not create.

---

## 6. DEPENDENCY AUDIT

- **Cycles:** none.
- **Layer violations:** none outstanding (five fixed by R57, all
  mutation-proven).
- **Hidden dependencies:** one — `lib/core/contracts/contracts.dart` re-exports
  seven contract files, three of which declare types colliding with live
  implementations (§8). A barrel is the only path by which they are reachable.
- **External packages:** 22 direct. `package:kaalka` and `package:webweavex`
  remain behind their adapters (certified I-21a/b/c).

---

## 7. DEAD CODE REPORT

Scanned all 1,263 declared public types in `lib/`.

**Method correction, recorded because it changed the result.** A name-reference
count initially flagged 7 candidates. Four were **extensions**
(`BackendEngineeringPlanJson`, `CanonicalImplementationModelJson`,
`SemanticSolutionArchitectureJson`, `SolutionComponentJson`), which are invoked
*implicitly* — `.toJson()` never names them. Verified live by a different
route: none of their receiver types declares its own `toJson`, and each
serialization file has real importers (generators, artifact intelligence,
tests). **A name-reference count cannot decide an extension's liveness.**

**Three genuine candidates remain:**

| Symbol | Location | Verdict | Evidence |
|---|---|---|---|
| **`ExperienceSpecBuilder`** | `lib/kernel/specification/experience_spec_builder.dart` | **ENTIRE FILE DEAD** — 170 lines, sole declaration, **file imported by nothing** | zero importers of the file, zero references to the type |
| `AcquisitionStatus` | `lib/knowledge/knowledge_acquisition_engine.dart:32` | dead **enum** in a live file (448 lines, 4 declarations, heavily imported) | 1 reference: its own declaration |
| `CreationPhase` | `lib/creation/creation_engine.dart:14` | dead **enum** in a live file (1,062 lines, 7 declarations) | 1 reference: its own declaration |

**Also dead:** `lib/core/contracts/knowledge_provider.dart` — see §8.

**Assets:** 7 of 8 `assets/` subdirectories contain only `.gitkeep`
placeholders; `pubspec.yaml` should be checked against them before any release
claim. Not dead code, but declared-and-empty.

**0.24% dead type surface (3 of 1,263) is excellent.**

---

## 8. DUPLICATE OWNERSHIP REPORT

**Ten class names are declared in two files each.** None is caught by
certification (§9).

| Name | Location A | Location B | Classification |
|---|---|---|---|
| **`KnowledgeProvider`** | `core/contracts/knowledge_provider.dart:64` | `capabilities/builtin/knowledge_capability.dart:7` | **ARCHITECTURAL DEFECT — A is dead** |
| **`ProtectionMetadata`** | `core/contracts/experience.dart:234` | `creation/experience_package.dart:731` | **Suspected dead A** (A's file has 3 importers, all inside `contracts/`) |
| **`ExecutionPlan`** | `core/contracts/kernel.dart:19` | `kernel/planning/execution_plan.dart:14` | **Both live** — A has 61 importers, B has 7. Collision hazard. |
| **`ExecutionStep`** | `core/contracts/kernel.dart:45` | `kernel/planning/execution_plan.dart:68` | Both live. Collision hazard. |
| `ExperienceFingerprint` | `app/experience_provenance.dart:80` (R52) | `runtime_intelligence/experience_relationship_graph.dart:16` | Distinct domains, both live. Collision hazard. |
| `DependencyGraph` | `feature_discovery/dependency_types.dart:32` | `software_cognition/architecture_model.dart:52` | Distinct domains — acceptable |
| `SemanticEntity` | `synthesis/application_reasoner.dart:151` | `world_model/semantic_entity.dart:10` | Distinct domains — acceptable |
| `CreationFailed` | `app/creation_coordinator.dart:88` | `creation/creation_engine.dart:68` | Distinct result hierarchies — acceptable |
| `AnythingPadding` | `design_system/tokens/layout.dart:35` | `design_system/tokens/spacing.dart:56` | **Same package, same concern — suspected duplicate** |
| `CreationResult` | (base of the two `CreationFailed`s) | | acceptable |

**`KnowledgeProvider` is proven dead and is the third instance of a fixed
pattern.**

- `core/contracts/knowledge_provider.dart` has **zero direct importers**;
  reachable only via the barrel.
- Both real implementors —
  `KnowledgeAcquisitionProviderAdapter implements KnowledgeProvider`
  (production) and `FakeKnowledgeProvider` — resolve the type from
  `capabilities/builtin/knowledge_capability.dart` (the adapter imports
  `../builtin/knowledge_capability.dart`).

R47 deleted `contracts/runtime.dart` for exactly this. R57 deleted
`contracts/repository.dart` for exactly this. **The barrel still carries R47's
comment explaining its own deletion, four lines above two more instances.**

**Every collision is a latent compile break.** The first file to import both
declaring libraries fails with `ambiguous_import` — the trap R54 hit with a
duplicated `experiencePackageVersion` constant, and R57 hit with
`IntentRepository`.

---

## 9. CERTIFICATION AUDIT

**Strengths.** 89 invariants; every pinned allowlist path still exists (zero
stale entries); scanners strip comments *and* string literals while preserving
`${...}` interpolations (the R48 fix); import scans correctly run on **raw**
source; positive-presence checks assert non-empty before checking.

**BLIND SPOT 1 — the duplicate-declaration invariant covers 13 of 1,263
types.**

```dart
for (final type in canonicalConstructionSites.keys) {   // 13 entries
  ...expect(declaring.length, 1, ...)
}
```

`knownDuplicateDeclarations` is empty, and the documentation states "there are
no known duplicates" — **true only of the 13 pinned types.** Ten collisions
live outside the scan (§8). This is the clearest false-negative in the layer.

**BLIND SPOT 2 — deleted files are guarded by two different mechanisms.**
`removedDeadFiles` (R47) lists only `contracts/runtime.dart`. R57's deletions
are guarded by a separate hard-coded list inside I-80. Two mechanisms for one
job; a future deletion could plausibly be added to neither.

**BLIND SPOT 3 — invariant IDs are not traceable to tests.** 89 tests, but
`I-NN` appears 12 times in the file and almost always as a *range header*
(`I-61 … I-67`). No individual test carries its ID. Every matrix in `docs/`
references invariants by number, and a failing test cannot be mapped back
without counting positions in a comment. `I-79` appears in documentation and
**nowhere** in the test file.

**No obsolete or weakened invariants found.** All 86 pre-R57 invariants re-run
and pass.

**AST opportunity.** The scanner is textual (documented limitation L-01). The
collision scan in §8 was performed with regex in seconds; an `analyzer`-package
lint would make it exact — but that adds a dev dependency, and the regex is
sufficient for the collision check specifically.

---

## 10. MUTATION AUDIT

40+ probes across R46–R57. Reviewed for whether each still proves something.

**Verdict: sound, with two systemic observations.**

1. **Mutation testing has twice caught a defect in a brand-new invariant**, not
   just in code: R48 (scanner blind to string interpolation) and R56 (an
   ordering assertion that should have been a containment assertion). That is
   the practice working as intended.
2. **Positive-presence clauses are consistently un-probed**, and this is
   consistently disclosed (R53 I-59/I-60, R54 I-65, R55, R56, R57 I-79 clause
   3). The disclosure is honest; the coverage gap is real but low-risk, because
   such assertions fail by construction when the required thing is removed.

**No probe was found that proves nothing.**

---

## 11. DOCUMENTATION DRIFT REPORT

148 documentation files compared against source.

| Drift | Severity | Evidence |
|---|---|---|
| **CI documentation claims a baseline it does not enforce.** Step named *"Analyze (0 new errors, 0 new warnings beyond the documented baseline)"* runs bare `flutter analyze`, which exits 1 on the baseline itself. | **Critical** | `ci.yml:35-36`; measured exit 1 |
| `lib/features/experiences_screen.dart` cited; real path is `lib/features/experiences/experiences_screen.dart` | Low | `RELEASE_CANDIDATE_HARDENING.md:153` |
| `lib/webweavex.dart` cited; no such file — the adapter is `lib/knowledge/webweavex_adapter.dart` | Low | `SOFTWARE_COGNITION_ENGINE.md:52` |
| `I-79` referenced in matrices, absent from the test file | Low | §9 blind spot 3 |
| Certification docs state "no known duplicate declarations" | **High** | True of 13 pinned types; 10 collisions exist (§8) |

**Not drift:** 14 references to deleted files (`runtime.dart`,
`repository.dart`, `minimal_kernel.dart`, `local_database.dart`, ten
`rNN_mutation_probe.dart`) — every one appears in prose *describing the
deletion*. Correct historical record.

**Not drift:** varying test counts (1719 … 2062) across reports — each
milestone records its own count. Correct.

---

## 12. REMAINING GAP MATRIX (fresh — prior matrices ignored)

| # | Sev | Class | Gap | Evidence |
|---|---|---|---|---|
| **A-1** | **CRITICAL** | Tooling | **CI cannot pass; `flutter test` never runs there.** `dart format --set-exit-if-changed` exits 1 (424/668 files unformatted); `flutter analyze` exits 1 on the 71-issue baseline. Both precede the test step. **All 89 invariants gate nothing.** | measured exit codes; `ci.yml` step order |
| **A-2** | HIGH | Architectural | **10 live class-name collisions**, unscanned by certification | §8 |
| **A-3** | HIGH | Architectural | **`core/contracts/knowledge_provider.dart` is dead and colliding** — third instance of the R47/R57 pattern | zero importers; both implementors use the other type |
| **A-4** | HIGH | Certification | Duplicate-declaration invariant covers **13 of 1,263** types | §9 |
| **A-5** | MEDIUM | Testing | **Test-suite flakiness (`database is locked`)** — parallel files share one `anything_experiences.db`. Measured ~2–3 failures per 11 runs on both R55 and R57 | controlled comparison, R56/R57 |
| **A-6** | MEDIUM | Certification | Invariant IDs not traceable to tests; `I-79` documented but absent | §9 |
| **A-7** | MEDIUM | Dead code | `ExperienceSpecBuilder` — an entire 170-line dead file | zero importers |
| **A-8** | LOW | Dead code | `AcquisitionStatus`, `CreationPhase` — dead enums in live files | 1 self-reference each |
| **A-9** | LOW | Certification | Two mechanisms guard deleted files (`removedDeadFiles` + I-80) | §9 |
| **A-10** | LOW | Documentation | Two wrong file paths; one unenforced baseline claim | §11 |
| **A-11** | LOW | Tooling | Test databases regrow unbounded (24,699 / 1.8 GB cleared during R56) | R56 audit |
| **A-12** | LOW | Behavioural | Carried forward and re-verified: G-35 (atomicity stops at the repository), G-38 (at-most-once delivery), G-42 (constructor defaults permit multiple instances) | prior matrices, re-checked |

**Areas confirmed CANONICAL — no work recommended:** repository ownership,
commit ownership, runtime construction, AI boundary, protection boundary,
retention, governance, trust, distribution, installation, durable collections,
dependency direction (no cycles).

---

## 13. RISK ASSESSMENT

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Architectural drift ships unnoticed because CI never runs the invariants | **Certain today** | **Severe** — eleven milestones of enforcement are advisory | A-1 |
| A future file imports two colliding declarations and fails to compile | Moderate | Low (loud, immediate) | A-2/A-3 |
| A second `AnythingRuntime`-class duplicate appears outside the 13 pinned types | Moderate | High (silent) | A-4 |
| Full-suite results mistrusted or mis-attributed | **Observed twice** | Medium | A-5 |
| Formatting the repository churns 424 files and obscures history | High if done carelessly | Medium | do it in one isolated commit, no logic changes |

---

## 14. RECOMMENDED NEXT MILESTONE

### IS-R58 — Make the certification layer actually gate

**Justification, entirely from evidence:** the repository contains 89
invariants and 40+ mutation proofs whose sole purpose is preventing
architectural regression. Measurement shows CI halts two steps before the test
suite, so none of it has ever run there. **Repairing that is the largest
architectural value available and carries the least architectural risk, because
it changes no architecture at all.**

Everything else found by this audit is smaller, and two items (A-2, A-3) are
*only worth doing once a gate exists to keep them fixed*.

**Explicitly rejected as the next milestone:**
- *A new ownership milestone.* The audit found ownership canonical (§4). Inventing scope would violate the first principle.
- *An `analyzer`-package AST lint.* Adds a dependency to solve a problem regex already solves for the one check that needs it.
- *Reformatting alone.* Necessary but insufficient — it fixes step 3 and leaves step 4 failing.

---

## 15. DETAILED IMPLEMENTATION PLAN

**Phase 1 — Make CI green (the milestone's core).**
1. Run `dart format .` across the repository in **one isolated commit** with no
   logic change. Expect ~424 files. Verify `flutter test` count is unchanged at
   2,062 immediately after.
2. Replace the bare `flutter analyze` step with a **baseline-enforcing** step:
   fail on any *error* or *warning*, and on any increase in the info count above
   71. The step name already claims this behaviour; make it true.
3. Add `flutter test` failure visibility: keep `--coverage`, and run the
   certification suite as its own named step so a regression is legible in the
   job list.

**Phase 2 — Address the flakiness that would otherwise make CI red (A-5).**
4. Give `AppComposition.production()` an optional `dbName`, defaulted — the
   same additive seam R55 used for `DatabaseExecutor`. Widget suites pass a
   fresh name, as every R53–R57 suite already does.
5. Re-measure the 11-run flake rate. **If it does not improve, say so and stop**
   — do not iterate on an unproven hypothesis (the R57 lesson).

**Phase 3 — Close the certification blind spot (A-4).**
6. Extend the duplicate-declaration invariant to scan **all** declared types,
   with the ten current collisions **pinned and individually justified** in
   `knownDuplicateDeclarations`. Do not narrow the scan to make it pass.
7. Delete `core/contracts/knowledge_provider.dart` (A-3) and remove its barrel
   export in the same commit — R57's precedent, which avoided R47's dangling
   export.
8. Merge `removedDeadFiles` and I-80's list into one mechanism (A-9).

**Phase 4 — Dead code (A-7, A-8).** Delete `experience_spec_builder.dart` and
the two dead enums, each with proof recorded.

**Phase 5 — Documentation (A-10, A-6).** Fix the two paths; tag every
certification test with its `I-NN`.

**Out of scope, deliberately:** the four remaining acceptable collisions
(`DependencyGraph`, `SemanticEntity`, `CreationFailed`, `ExperienceFingerprint`)
— distinct domains, pinned rather than renamed. Renaming R52's
`ExperienceFingerprint` would be a public API change for no proven defect.

---

## 16. SUCCESS CRITERIA

- `dart format --set-exit-if-changed .` exits **0**.
- The analyze step fails on any new error/warning and on info count > 71, and
  **passes** at the current baseline.
- `flutter test` **executes in CI** and reports 2,062+ passing.
- Flake rate re-measured over ≥11 runs and reported, improved or not.
- Duplicate-declaration invariant scans **all** declared types; ten collisions
  pinned with individual justifications; mutation-proven by adding an
  eleventh.
- `core/contracts/knowledge_provider.dart` deleted, barrel export removed in
  the same commit, analyzer baseline still 71.
- Every certification test carries its `I-NN`; `I-79` reconciled.
- No invariant weakened or removed; no test skipped; behaviour unchanged.

---

## 17. BACKWARD COMPATIBILITY ANALYSIS

| Change | Compatibility |
|---|---|
| `dart format .` | **No semantic change.** Whitespace only. Verify by unchanged test count. |
| CI step changes | No source impact. |
| `AppComposition.production({String? dbName})` | **Additive and defaulted** — every existing caller unaffected, same pattern as R55's `using:`. |
| Delete `contracts/knowledge_provider.dart` | Zero direct importers; both implementors use the other declaration. **Barrel consumers**: 3 test files import the barrel — must be verified to compile, exactly as R57 did. |
| Delete `experience_spec_builder.dart` | Zero importers. |
| Delete two dead enums | Zero references. |
| Extend the duplicate invariant | Test-only. |

**No schema change. No migration. No public API break. No new dependency.**

---

## 18. ARCHITECTURAL TRADE-OFFS

**Formatting 424 files churns history.** Accepted: one isolated commit,
attributable and skippable in `git blame`. The alternative — leaving CI
permanently red — has already cost eleven milestones of enforcement.

**Pinning ten collisions rather than renaming them.** Renaming touches public
API for types with no proven defect. Pinning makes them *visible and
reviewable* and fails on an eleventh. This is the discipline R51/R52/R54 used
for sibling types; the cost is that four acceptable collisions remain
permanently.

**Baseline-enforcing analyze is a hand-maintained number (71).** Same class as
G-29's `currentRuntimeVersion`. Accepted: it is one number in one file, and
today's alternative is a step that can never pass.

**Not adopting an AST lint.** Loses exactness on reflection/aliasing; saves a
dev dependency and significant machinery for a pattern the codebase does not
use. Consistent with documented limitation L-01.

---

## 19. EVIDENCE APPENDIX

| Claim | Command / location | Result |
|---|---|---|
| CI format step fails | `dart format --set-exit-if-changed --output=none .` | exit 1; "Formatted 668 files (424 changed)" |
| CI analyze step fails | `flutter analyze` | exit 1; "71 issues found" |
| Test step never reached | `.github/workflows/ci.yml:32-39` | format (3) → analyze (4) → test (5) |
| 9 CI-required docs exist | file existence check | all 9 OK |
| 1,263 declared types | regex over `lib/**/*.dart` | — |
| 3 dead symbols | reference count ≤ 1 | `ExperienceSpecBuilder`, `AcquisitionStatus`, `CreationPhase` |
| 4 extensions live | receiver types declare no `toJson`; serialization files imported | corrected an initial false positive |
| 10 name collisions | duplicate class declarations in `lib` | §8 |
| `KnowledgeProvider` contract dead | zero direct importers; adapter imports `../builtin/knowledge_capability.dart` | §8 |
| Duplicate invariant scans 13 types | `for (final type in canonicalConstructionSites.keys)` | §9 |
| `knownDuplicateDeclarations` empty | certification source | §9 |
| Invariant IDs untraceable | 12 `I-NN` mentions across 89 tests, mostly range headers | §9 |
| No cycles | no repository imports a coordinator/capability/screen/composition | §6 |
| 2,062 tests pass | `flutter test` | "All tests passed!" |
| Repository ownership canonical | §4 census | 0 bare constructions |

---

## 20. FILES EXAMINED SUMMARY

| Area | Files | Depth |
|---|---|---|
| `lib/**/*.dart` | 468 | Indexed and scanned repository-wide (types, constructions, imports, collisions). Read in full: composition root, all 9 repositories, certification-relevant subsystems, contracts. |
| `test/**/*.dart` | 200 | Indexed; certification suite read in full; skip/weak-assertion/duplicate-name scans across all. |
| `docs/**` | 148 | Indexed; cross-referenced against source for drift. |
| `lib/**/README.md` | 25 | Indexed. |
| `.github/workflows/ci.yml` | 1 | **Read in full; every step executed locally.** |
| Root config (`pubspec.yaml`, `analysis_options.yaml`, `plan.md`, `README.md`, `.metadata`, `.gitignore`) | 7 | Read. |
| `design/stitch/**` | 163 | **Indexed and classified only** (design mockups: DESIGN.md + html + png). Not code; no architectural claim made. |
| `assets/**` | 8 | Indexed — 7 of 8 directories are `.gitkeep` placeholders. |
| Platform dirs (`ios`, `macos`, `android`, `windows`, `linux`, `web`) | 127 | **Indexed only.** Generated Flutter scaffolding; no architectural claim made. |
| **Total tracked** | **1,147** | Every tracked file classified. |

**Not examined, stated explicitly:** any content of an unsupplied ZIP archive;
`.dart_tool/` build output (gitignored scratch); remote CI run history (no
access — the conclusion that CI fails is derived from *executing its steps
locally*, not from observing a red build).

---

## CONCLUSION

The architecture is canonical where eleven milestones claimed it would be, and
this audit verified rather than assumed that. The significant discovery is not
in the architecture but in its **enforcement**: the mechanism built to protect
all of it has never run in CI.

**Fix the gate before adding anything else behind it.**
