# IS-R59 — Canonical Runtime Reachability Certification

**Date:** 2026-08-08 · `8736ff3` → `d806748` · **Status:** COMPLETE

---

## 1. EXECUTIVE SUMMARY

IS-R58 left one architectural uncertainty: whether the repository contained
runtime graphs disconnected from the canonical application. It did.

**Measured: 110 of 466 `lib/` files (23.6%) were unreachable from `main()`**,
across 29 directories, with no classification at all.

IS-R59 eliminated the unknown state. Every file now carries exactly one:

| Class | Count |
|---|---|
| REACHABLE | 356 |
| DORMANT (unreachable, but tested) | 43 |
| EXPERIMENTAL (unreachable, imported by other lib files) | 50 |
| DEPRECATED | 0 |
| DEAD (pinned, unprovable) | 2 |
| **TOTAL** | **451** |

**15 files were deleted**, each proven by two independent methods. **~50 were
deliberately kept** — a coherent parallel v1 application that meets no proof
standard. Two invariants make both outcomes permanent.

**Architecture unchanged. Ownership unchanged. Behaviour unchanged.**

| | Before | After |
|---|---|---|
| Unclassified files | **110** | **0** |
| `lib/` dart files | 466 | 451 |
| Invariants | 93 | **95** |
| Tests | 2,066 | **2,068** |
| Analyzer | 0/27/43 | 0/27/43 |

---

## 2. PHASE RESULTS

| Phase | Result |
|---|---|
| 1 — Runtime audit | 466 files indexed; import graph built |
| 2 — Reachability graph | `RUNTIME_REACHABILITY_GRAPH.md`; 356 reachable |
| 3 — Entry point certification | **Exactly one** `main()`, **one** `MaterialApp`, **no** `ProviderScope`, no `GoRouter`/`RouterConfig`/`ShellRoute` |
| 4 — Navigation audit | `SCREEN_REACHABILITY_MATRIX.md` |
| 5 — Feature audit | `FEATURE_REACHABILITY_MATRIX.md` — **`lib/features/` is 100% reachable**, a clean result |
| 6 — Provider audit | `PROVIDER_REACHABILITY_MATRIX.md` — 17 Riverpod providers, **all unresolvable**; 3 `ChangeNotifier`; no Bloc/Cubit/`InheritedWidget` |
| 7 — Parallel architecture | `PARALLEL_ARCHITECTURE_REPORT.md` — one parallel app graph found, nothing else |
| 8 — Dead subsystem | `DEAD_SUBSYSTEM_REPORT.md` — 15 deleted, 2 refused |
| 9 — Certification | I-85, I-86, both mutation-proven |
| 10 — Graphs | runtime / navigation / provider / feature / screen graphs |
| 11 — Validation | run after every commit |
| 12 — Documentation | this report + ADR + lessons + matrices |

---

## 3. COMMIT-BY-COMMIT

| Commit | Change |
|---|---|
| `debccd5` | Delete 4 proven-dead leaf files (group A) |
| `434652b` | Delete 5 proven-dead analysis leaves (group B) |
| `f40caf5` | Delete 5 proven-dead runtime leaves (group C) |
| `19c6bef` | I-85, I-86, reachability tooling, Phase 2–8 matrices |
| `d806748` | Brace the one flow-control statement I-86 introduced |

Group D (`onboarding_screen.dart`, the cascade) landed with `19c6bef`.

---

## 4. WHAT WAS DELETED, AND WHAT WAS REFUSED

**Deleted (15)** — each proven by import closure **and** type-name reference.
Full list in `DEAD_SUBSYSTEM_REPORT.md`.

**Refused (2).** `layout.dart` and `semantic_entity.dart` are unreachable and
unimported, but their type names collide with live declarations, producing 36
and 167 references a text search cannot attribute. Import analysis says dead;
name analysis cannot confirm. **Suspected is not proven** — pinned in
`pinnedUnreachableFiles`, and I-86 fails if a pin goes stale.

**Refused (~50).** The parallel v1 application. Its files import each other, so
none is individually orphaned. Deleting it is not a proof-driven deletion, and
the ABSOLUTE RULES forbid migrating to or away from Riverpod.

---

## 5. CERTIFICATION AND MUTATION

| ID | Protects | Probe | Result |
|---|---|---|---|
| I-85 | One entry, one app widget, no `ProviderScope` | E — a second `void main()` + `MaterialApp` | FAILED as required |
| I-86 | No file in an unknown runtime state | F — an unreachable, unpinned file | FAILED as required |

Both reverted; tree verified clean. Registered in
`INVARIANT_TRACEABILITY.md` (I-84 enforces that).

---

## 6. VALIDATION EVIDENCE

| Check | Result |
|---|---|
| `dart format --set-exit-if-changed .` | **exit 0** |
| `tool/analyze_gate.sh` | **exit 0** — 0 errors / 27 warnings / 43 infos |
| Certification suite | **95 passed** |
| Full suite | **2,068 passed, 0 skipped** |
| `git status --porcelain` | empty |

**The IS-R58 gate caught a regression in IS-R59's own code** — infos rose
43 → 44 from one unbraced `if` in the I-86 implementation. Fixed with
`dart fix`, not suppressed.

---

## 7. ARCHITECTURAL / BEHAVIOURAL / API DIFF — expected: none

**None.** No ownership moved, no subsystem gained or lost responsibility, no
public signature changed. The only removals were proven-dead files that nothing
referenced. 2,066 pre-existing tests pass unchanged; the +2 are the new
invariants.

---

## 8. REMAINING GAPS

| # | Sev | Gap |
|---|---|---|
| **G-50** | MED | ~50 EXPERIMENTAL files — the parallel v1 application, inert but present |
| G-51 | LOW | 2 DEAD files unprovable by text analysis; pinned |
| G-52 | LOW | 43 DORMANT files tested but unreachable — their tests assert behaviour no user can reach |
| **G-40** | MED | Suite flakiness **not resolved**; recurred twice in R59. My R58 "0 of 22" reading was too confident — that bounds a rate, it does not prove absence |
| G-44…G-47, G-49 | LOW–MED | Carried forward from R57/R58 |

---

---

## 10. G-40 SEVERITY ESCALATION — measured during R59's own deliverable build

While generating validation evidence I ran `flutter analyze`, the analyze gate,
the certification suite and the full suite in rapid succession, with a `dart`
process still alive from the previous command.

Result: **2,041 passed, 27 FAILED** — 79 `database is locked` occurrences and
59 `SqfliteFfiException`s.

A clean re-run with no concurrent process: **2,068 passed, 0 failed.**

**This is not a code regression.** It is G-40 under contention, and it is far
worse than the ~2–3 failures per 11 runs measured in isolation. The mechanism is
unchanged — every test building `AppComposition.production()` opens the same
default `anything_experiences.db` — but the failure rate is a function of
concurrent database access, not a fixed probability.

**Consequence for CI, stated plainly.** IS-R58 made CI run the suite. CI steps
are sequential, so this exact contention should not occur there — but the
`flutter test --coverage` step runs the same suite a second time after the
certification and milestone-suite steps, and any overlap or shared runner load
makes red builds likely.

**This raises G-40 from MEDIUM to the highest-priority remaining item**, ahead
of the parallel-application decision: a gate that is intermittently red trains
everyone to ignore it, which would undo IS-R58 entirely.

## 9. RECOMMENDATION FOR IS-R60

### Resolve the parallel v1 application (G-50)

It is now the last large architectural question, and R59 has made it tractable:
every file is classified, the graph is documented, and I-85 guarantees it cannot
revive by accident.

**Scope it as a decision milestone, not a deletion milestone.** The question is
not "is this dead" — R59 answered that it is *inert but internally coherent*.
The question is whether it is **intended**:

1. If the v1 shell is abandoned, delete it as one reviewed subsystem, with the
   ~50-file set enumerated in advance and I-86's pin table updated in the same
   commit.
2. If any of it is intended to live, the defect is the missing `ProviderScope`
   — a much smaller fix, and one that must be reviewed against
   `AppComposition` ownership before it is made.

**That decision cannot be made from repository evidence alone** — it is a
product intent question, and R59 states plainly that it cannot be established
from the repository which of the two is correct.

**DO G-40 FIRST.** Section 10 measured it at 27 failures under contention, not
2–3. It is now the highest-priority item in the repository: CI runs the suite as
of R58, and an intermittently red gate trains everyone to ignore it — which
would undo IS-R58 entirely. The fix is known and small: an injectable database
name on `AppComposition.production()`, or per-test databases in widget suites,
exactly as every R53–R57 suite already does.

**Explicitly rejected for R60:** deleting the two pinned DEAD files without
type-aware analysis; consolidating the pinned duplicate types (public API churn,
no proven defect).
