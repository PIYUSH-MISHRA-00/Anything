# Anything v2.0.0 — Test Evidence Matrix

Purpose: prevent future false certification by stating exactly what each major test claim proves and does not prove. Compiled from direct source reading and actual `flutter test` execution during this audit (not from doc/commit-message claims).

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
| `stage11_end_to_end_certification_test.dart` | INTEGRATION, labeled "certification" | Exercises `IntentComposer` → coordinators → generated package for several domains (doc comments mention Equipment Lending, Fossil Catalog, OrbitMetrics) | End-to-end certification | Not independently re-verified this pass whether the widget-interaction portions bypass production widgets; known to have an "Unused import" set suggesting some of its scaffolding is currently dead. One sub-test (`Widget Interaction Button tap fires action through ExperienceRenderer`) fails in this environment due to the ink_sparkle shader issue (see below) |
| `stage11_proof_closure_test.dart` | INTEGRATION | Predecessor "final proof" attempt (per commit `dbc52b8`) | Certification | Superseded in intent by the three newer untracked files; kept in tree, creating overlapping/competing "final" claims across files — a documentation-hygiene problem in itself |
| `stage11_security_certification_test.dart` | INTEGRATION | Component-tree budget limits, unknown-component-type safety | Security certification | Legitimate scope for what it tests; does not cover HTTP/AI/behavior-interpreter security (see Security Audit) |
| **`stage11_5_production_certification_test.dart`** (untracked) | Claims CERTIFICATION, actually **SIMULATION** for the write path | `test()` block does real SQLite create/insert/query/close/reopen. `testWidgets()` block uses `_CachedDataRuntime`, an in-memory `Map`, for all CRUD triggered via UI interaction, explicitly to dodge FFI timing issues | "Writes still go through real ExperienceDatabase" (docstring, line 10) | **False claim.** UI-driven Alice creation, edit, Bob creation, and delete never touch SQLite. Also **fails when run**: `CRUD: create Alice -> ...` throws (shader exception cascades into `expect(...'Edit'...)` failing because the async record load hadn't resolved) |
| **`stage11_real_generated_app_test.dart`** (untracked) | Claims vertical-slice proof, actually **SIMULATION** | Defines `_InMemoryDataRuntime` + `_TestExperienceHost`/`_TestExperienceHostState` (test reimplementations of production `ExperienceHostScreen` behavior); 16 conditional assertions (`if (...evaluate().isNotEmpty)`) guard checks that should be mandatory | "generated UI: Add person -> ... -> restart persistence" | Test-only host, not the real `ExperienceHostScreen`; optional assertions mean required features can silently regress without failing the suite. Also fails in this environment on the ink_sparkle shader issue |
| **`stage11_user_path_certification_test.dart`** (untracked) | Mixed — mostly genuine INTEGRATION, one gap | Groups A-D, F-I, K use real `ExperienceDataRuntime`/production widgets for individually-scoped behaviors (tap wiring, form submit, search, CRUD, router, dashboard metrics) — genuinely good production-path widget tests | Full user-path certification | **Group J ("Restart preserves data")** is a plain `test()` that calls `dataRuntime1.insert(...)` directly — bypasses `IntentComposer`/coordinators/`ExperienceHostScreen`/generated UI entirely for the one thing (restart) that most needs to be proven end-to-end |

**Execution result (this audit):** `flutter test test/stage11` → 199 tests, **194 pass, 5 fail**. Failures: `stage11_5_production_certification_test.dart` (1, real bug — see above), `stage11_end_to_end_certification_test.dart` (1), `stage11_real_generated_app_test.dart` (1), `stage11_user_path_certification_test.dart` (1), `stage11_widget_runtime_test.dart` (1) — the latter four all show the identical `ink_sparkle.frag`/Vulkan-backend exception, a local test-environment defect (see Current State Audit §7), not independently-confirmed production defects.

**Bottom line for anyone relying on "Stage 11 complete" claims:** no single test in the current suite proves create→real-SQLite-via-generated-UI→close→reopen→generated-UI-shows-data without either (a) faking the DB layer, (b) bypassing the UI for the write, or (c) making required assertions optional. This is the concrete, scoped gap — not a claim that the underlying runtime is broken (individual pieces of it are well-tested and passing).

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
