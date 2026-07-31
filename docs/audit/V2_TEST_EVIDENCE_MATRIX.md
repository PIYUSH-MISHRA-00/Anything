# Anything v2.0.0 — Test Evidence Matrix

Purpose: prevent future false certification by stating exactly what each major test claim proves and does not prove. Compiled from direct source reading and actual `flutter test` execution during this audit (not from doc/commit-message claims).

**Updated 2026-07-31 (M1 — Stage 11 Truthful Closure):** the Stage 11 section
below was rewritten after M1 closed the gap this doc originally flagged.
`stage11_5_production_certification_test.dart` and
`stage11_real_generated_app_test.dart` (both flagged below as false/weak
certifications) have been **deleted** — fully superseded by
`test/stage11/stage11_final_production_certification_test.dart`, the new
authoritative PRODUCTION-PATH CERTIFICATION. `stage11_user_path_certification_test.dart`
Group J has been relabeled to accurately describe its (narrower) scope. The
original rows are kept below, struck through in spirit but not in text, so
the history of what was wrong and why is not erased — see
`docs/progress/V2_STAGE_11.md`'s "M1 — Stage 11 Truthful Closure" section
for the full narrative.

## Stage 9.4 — Kaalka Protection

| Claim | Files | Type | What it proves | What it does NOT prove |
|---|---|---|---|---|
| Protect/unprotect roundtrip works with real Kaalka | test/stage94/protection_test.dart | INTEGRATION (real dependency) | `KaalkaProtectionProvider` correctly wraps real `package:kaalka` encrypt/decrypt with correct-time success and wrong-time rejection; survives repository recreation | Does not exercise the full UI (protection toggle screen), only the service layer |
| Trusted opening returns correct status codes | test/stage94/opening_test.dart | INTEGRATION | `OpenReady`/`OpenNotFound`/`OpenProtectionInputRequired`/`OpenFailed` all correctly returned; Activity events emitted exactly once (no duplicate emission bug) | Does not test through `ExperienceHostScreen` UI |
| Protection state independent of Activity log | test/stage94/identity_test.dart | INTEGRATION | Protection state survives Activity history clearing; opening a newly created experience B yields B, not a stale "most recent" A | — |

**Execution result (this audit):** 18/18 pass, real Kaalka (not mocked). High confidence.

## Stage 11 — "Universal Experience Runtime" Certification

| File | Type | What it actually does | What it claims | Gap |
|---|---|---|---|---|
| `stage11_core_test.dart` | UNIT/INTEGRATION | Component registry, query controller, router, form controller in isolation | — | Not a full-pipeline test, doesn't claim to be |
| `stage11_widget_runtime_test.dart` | INTEGRATION (widget) | Renders `ExperienceRenderer` against hand-built `InterfaceScreen`/`InterfaceDefinition` trees; verifies component→widget mapping including a "Novel Domain: reading collection" golden path | Component rendering correctness | Package is hand-authored in the test, not produced by the real synthesis pipeline — appropriate for a renderer unit test, **not** evidence of open-world synthesis |
| `stage11_end_to_end_certification_test.dart` | INTEGRATION, labeled "certification" | Exercises `IntentComposer` → coordinators → generated package for several domains (doc comments mention Equipment Lending, Fossil Catalog, OrbitMetrics) | End-to-end certification | Not independently re-verified this pass whether the widget-interaction portions bypass production widgets; known to have an "Unused import" set suggesting some of its scaffolding is currently dead |
| `stage11_proof_closure_test.dart` | INTEGRATION | Component-tree budget/form-validation/forbidden-component enforcement (a different, valid scope from lifecycle/restart) | "Final Proof Closure Certification" (self-labeled, for its own scope) | Does not claim restart certification; not in conflict with the new authoritative test |
| `stage11_security_certification_test.dart` | INTEGRATION | Component-tree budget limits, unknown-component-type safety | Security certification | Legitimate scope for what it tests; does not cover HTTP/AI/behavior-interpreter security (see Security Audit) |
| **`stage11_final_production_certification_test.dart`** (new, M1) | **PRODUCTION-PATH CERTIFICATION** | Full vertical slice for a novel domain (community garden plots, zero footprint in `lib/`, verified by an in-test automated scan), synthesized through the real `AnythingKernel`→`CompositeApplicationReasoner`→`CreationEngine` pipeline (only `ModelProvider` faked). Every mutation (create, edit, second create, search, delete) driven by real widget taps on real generated UI, backed by real SQLite (`databaseFactoryFfiNoIsolate` — genuine SQLite via FFI, not isolate-based, to avoid a `testWidgets`/FakeAsync deadlock). Restart boundary: closes Runtime A + Database A for real, fresh trusted reopen via a new `ExperienceOpeningCoordinator`, fresh `ExperienceDatabase` at the *same* file path, fresh `ExperienceDataRuntime`, fresh `AnythingRuntime`, fresh `ExperienceHostScreen`. Surviving edited record and absence of the deleted record asserted through generated UI first, real-SQLite query as secondary evidence. Includes a standalone `ExperienceResolver` regression test and a standalone novel-domain reasoner test. | Exactly what it does — no aspirational claims beyond the executed assertions | None known. Does not (and does not claim to) cover HTTP/AI capability security, migrations, or modification — those remain open per the Vision Gap Matrix (M2/M4) |
| ~~`stage11_5_production_certification_test.dart`~~ (deleted, M1) | Claimed CERTIFICATION, was actually **SIMULATION** for the write path | `test()` block did real SQLite create/insert/query/close/reopen. `testWidgets()` block used `_CachedDataRuntime`, an in-memory `Map`, for all CRUD triggered via UI interaction, explicitly to dodge FFI timing issues | "Writes still go through real ExperienceDatabase" (docstring) | **False claim, confirmed by execution** (also failed when run). Deleted — fully superseded by `stage11_final_production_certification_test.dart`. Root cause (isolate deadlock under FakeAsync) is now understood and fixed via `databaseFactoryFfiNoIsolate`; see `docs/progress/V2_STAGE_11.md` |
| ~~`stage11_real_generated_app_test.dart`~~ (deleted, M1) | Claimed vertical-slice proof, was actually **SIMULATION** | Defined `_InMemoryDataRuntime` + `_TestExperienceHost`/`_TestExperienceHostState` (test reimplementations of production `ExperienceHostScreen` behavior); 16 conditional assertions (`if (...evaluate().isNotEmpty)`) guarded checks that should have been mandatory | "generated UI: Add person -> ... -> restart persistence" | Deleted — fully superseded, kept as history in `docs/progress/V2_STAGE_11.md` rather than left in the tree as a misleading duplicate |
| `stage11_user_path_certification_test.dart` | Mixed — mostly genuine INTEGRATION | Groups A-D, F-I, K use real `ExperienceDataRuntime`/production widgets for individually-scoped behaviors (tap wiring, form submit, search, CRUD, router, dashboard metrics) — genuinely good production-path widget tests | Full user-path certification | **Group J**, relabeled (M1) from "Restart preserves data" to "Data runtime persistence (SQLite-level unit test, not a full-lifecycle restart certification)" — it still calls `ExperienceDataRuntime.insert()` directly (that's what it's now honestly scoped to test), and must not be cited as lifecycle proof; that role belongs solely to `stage11_final_production_certification_test.dart` |

**Execution result (M1, 2026-07-31):** `flutter test test/stage11` → **200 tests, 200 pass, 0 fail** (includes the new authoritative certification file; `stage11_5_production_certification_test.dart` and `stage11_real_generated_app_test.dart` no longer exist). The previously-observed `ink_sparkle.frag`/Vulkan-backend shader exception did not reproduce in this run — plausibly related to the switch to `databaseFactoryFfiNoIsolate` changing timing around Material ripple rendering, though this was not root-caused further since M1's scope was the restart certification, not the shader issue specifically; if it resurfaces, `docs/audit/V2_CURRENT_STATE_AUDIT.md` §7's original analysis and remediation options still apply.

**Bottom line:** `test/stage11/stage11_final_production_certification_test.dart` now truthfully proves create→real-SQLite-via-generated-UI→close→reopen→generated-UI-shows-data, with no faked DB layer, no UI bypass, and no optional assertions on required behavior. Stage 11's restart-certification gap, as documented in the original version of this matrix, is closed.

## Stage 8.x / 8.1-8.4, 8.2, 8.3, 8.4

Not re-verified line-by-line in this pass (out of scope given session constraints — these predate the generated-UI work and were the subject of prior "closure" commits). `test/stage81/full_loop_test.dart` and `test/stage81/persistence_test.dart` are among the files with uncommitted edits (adjusting call sites for the now-`async` `closeSession()`); not independently re-run.

## Anti-pattern inventory (repo-wide, from direct grep + the completed test-audit research pass before the rate limit)

- Hand-authored `ExperiencePackage`/`InterfaceDefinition` in tests: present in ~8 files; acceptable where used for renderer/validator unit tests in isolation, a red flag specifically where a file also claims "certification" status without a corresponding real-pipeline test elsewhere.
- Direct `DataRuntime.insert/update/delete` bypassing generated UI: ~10 files; expected for CRUD unit tests (Stage 11 group H), a defect specifically in the one restart-proof test that should go through the UI (Group J above).
- Test-only Host/Runtime reimplementations: confined to `stage11_real_generated_app_test.dart`.
- Conditional/optional assertions on required features: concentrated almost entirely in `stage11_real_generated_app_test.dart` (16 instances); one lower-risk instance in `stage11_5_production_certification_test.dart`.
- No `router.push(...)`/`queryController.setSearch(...)` direct-call bypasses found — certification tests that do simulate user action go through real widget taps/text entry, not controller shortcuts. This is a genuine positive.

## Documentation vs. reality

`docs/progress/V2_STAGE_11.md` (last touched at commit `68bf60f`, 2026-07-29) claims `Status: COMPLETE` and "119/All passing" — this predates all three untracked Stage 11 test files and the uncommitted production-code DI changes, and does not reflect the 194/199 result measured in this audit. It should be treated as historical, not current, until Stage 11 closure (Roadmap M1) actually lands and this doc is updated with a fresh, dated, execution-verified count.
