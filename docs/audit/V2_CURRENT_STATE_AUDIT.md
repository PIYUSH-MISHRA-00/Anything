# Anything v2.0.0 — Current State Audit

**Date:** 2026-07-30
**Method:** Direct repository inspection (git, source, tests) plus targeted parallel research agents. Several parallel research agents were terminated mid-task by an account-level session rate limit before delivering complete reports; where that happened, findings below were reconstructed by direct inspection instead and the doc says so explicitly. This document reports only what was directly observed in source/tests/execution, not what documentation claims.

## 1. Executive Summary

The v2 architecture is real and substantially implemented, not a facade: intent → kernel → synthesis → CreationEngine → ExperiencePackage → AnythingRuntime → generated UI → SQLite is a genuine, generically-implemented pipeline with no arbitrary code execution, a real Kaalka protection boundary (18/18 Stage 9.4 tests pass against real Kaalka), a single clean WebWeaveX import site, and solid HTTP/SSRF defenses. `flutter analyze` is clean (0 errors). Working-tree (uncommitted) changes to the runtime/creation layer are legitimate, well-targeted production fixes (correct DI ownership semantics in `ExperienceHostScreen`, generic event-to-behavior-node resolution, edit-screen generation, search wiring) — not test-cheating.

However, **Stage 11's "final certification" claim is not true.** The newest certification test (`stage11_5_production_certification_test.dart`, untracked) explicitly fakes its write path with an in-memory cache while its own docstring claims real SQLite writes, and it fails when actually executed. Other Stage 11 "certification" files bypass the production host/UI for the restart proof, or use test-only host/runtime reimplementations with optional assertions. A separate, independent, real architectural defect was also found and fixed during this audit: `ExperienceResolver` (wired live into `AnythingKernel`) hardcoded a `'calculator'` keyword match that could hijack any user expression containing "calc"/"math"/"arithmetic" — a direct violation of the no-domain-branching principle, and a dangling reference since nothing ever populated real entries.

**Verdict: ARCHITECTURE HEALTHY — CRITICAL PRODUCT GAPS REMAIN.** The foundation (security boundary, persistence, DI, generic renderer/behavior wiring) is sound. What's missing is not architecture but a *truthful, passing* end-to-end certification, plus release-readiness scaffolding (no LICENSE, no CI, stale README, Android signing unverified).

## 2. Git State

- Branch: `v2.0.0`, tracking `origin/v2.0.0`, HEAD `68bf60f` ("Stage 11.2: Final proof closure...").
- Working tree was dirty at session start: 13 modified files (all in `lib/runtime`, `lib/creation`, `lib/storage`, and 5 test files) + 4 untracked paths (`.mimocode/`, 3 new `test/stage11/*.dart` files).
- The modified production files are genuine, coherent, in-progress Stage 11 closure work (see §7). They were **not** written by this session prior to this audit — they existed in the working tree already. This audit treats them as the authoritative current state per instructions.
- `main` is a separate, far older branch (1 commit ahead of `ede3b1c`/README updates) — not part of v2 development.

## 3. Environment

- Flutter 3.44.8 (stable), Dart 3.12.2, at `D:\flutter\bin\flutter.bat`.
- Dart SDK standalone at `C:\tools\dart-sdk\bin\dart.exe`.
- Disk: only **~8 GB free of 220 GB (97% used)** — a real constraint; flag before any large builds/artifact generation.
- `flutter pub get`: succeeds cleanly (69 packages have newer versions available but nothing broken).

## 4. Repository Map (verified structure)

`lib/` subdirectories and their actual role (verified by reading representative files, not inferred from names):

| Dir | Role |
|---|---|
| `kernel/` | `AnythingKernel.processIntent` — classification → existing-experience resolution → understanding → reasoning orchestration |
| `synthesis/` | `ApplicationReasoner` / archetypes — turns understood intent into an `AppBlueprint` |
| `creation/` | `CreationEngine` — turns `AppBlueprint` into `ExperiencePackage` (interface screens, state, data schema, behavior graph) |
| `runtime/` | `AnythingRuntime`, `ExperienceRenderer`, `BehaviorInterpreter`, `ExperienceDataRuntime`, `ExperienceRouter`, `ExperienceHostScreen`, component registry — the trusted execution engine for a package |
| `storage/` | `ExperienceDatabase` (real SQLite via `sqflite`) |
| `security/` | `KaalkaProtectionProvider` (kaalka adapter), protection service |
| `legacy/` | Despite the name, contains the **live** canonical Kaalka adapter (`kaalka_adapter.dart`, imported by `security/protection_service.dart`) — misleading directory name, not actually legacy |
| `capabilities/` | `PlatformCapability` framework; `builtin/http_capability.dart` has real SSRF defenses |
| `knowledge/` | `webweavex_adapter.dart` — the single, sole `package:webweavex` import site in all of `lib/` |
| `app/` | Coordinators (`ExperienceCreationCoordinator`, `ExperienceModificationCoordinator`, etc.) |
| `tools/` | Dead code — `ToolRegistry`/`CalculatorTool` are v1-era, not imported from anywhere else in `lib/` |

## 5. Canonical Creation & Runtime Flow (verified via source)

`AnythingKernel.processIntent` (lib/kernel/anything_kernel.dart:82):
1. `IntentClassifier.classify` — IMPLEMENTED
2. `ExperienceResolver.resolve` — IMPLEMENTED but was structurally broken (see §8, now fixed)
3. `_understandingService.understand` (model-backed) — IMPLEMENTED
4. Ambiguity/clarification gate — IMPLEMENTED
5. → `CompositeApplicationReasoner` → `AppBlueprint` — IMPLEMENTED
6. → `CreationEngine` → `ExperiencePackage` (interface/state/data/behavior) — IMPLEMENTED, generic (see §9)
7. → package validation → `ExperienceRepository` persistence — IMPLEMENTED
8. → `ExperienceOpeningCoordinator` / trusted opening → `ExperienceHostScreen` — IMPLEMENTED
9. `ExperienceHostScreen` → `AnythingRuntime.openExperience` → `ExperienceRenderer` + `RuntimeComponentContext` + `BehaviorInterpreter` + `ExperienceDataRuntime` — IMPLEMENTED

Generated-UI action chains (verified against current working-tree source):
- **Add** → renderer emits `_findFormScreenForAction`-routed navigation to `${entity}_form` screen (experience_host_screen.dart) — IMPLEMENTED
- **Save/Create** → form submit → `submitForm` event → `BehaviorInterpreter._resolveGenericEvent` maps generic event to entity-specific behavior node → `dataRuntime.insert` (awaited) → real SQLite `records` table — IMPLEMENTED
- **Edit** → detail screen's Edit button (experience_renderer.dart:610-623, hardcoded into `_renderEntityDetail`, not a generated node) → navigate to `${entity}_edit` screen (auto-generated by `CreationEngine`, working-tree diff) → `submitForm` with `mode: edit` → `BehaviorInterpreter` routes to `update` — IMPLEMENTED
- **Delete** → confirm dialog → `deleteRecord` event → generic resolution → `dataRuntime.delete` — IMPLEMENTED
- **Search** → `TextField.onChanged` in component registry → `searchChanged` event → `stateEngine.write('searchTerm', ...)` → `StreamBuilder` in renderer filters the query result client-side — IMPLEMENTED, but filtering happens in Dart over the full result set post-query, not as a SQL predicate (fine at current scale, a scale risk later)
- **Detail/Navigation** → `RuntimeComponentContext.navigate` with `recordId` argument, loaded via `runtimeContext.readRecord` — IMPLEMENTED

All of the above are **generic** — no per-entity or per-domain code paths; entity/field identity flows through as data (`entityId`, `screenId` string conventions), not through switch/if branches on domain name.

## 6. Persistence

- `ExperienceDatabase` (lib/storage/experience_database.dart): real `sqflite`-backed SQLite, one generic `records(id, entity, data JSON, created_at, updated_at)` table per Experience database file (`experience_<experienceId>.db`), indexed on `entity`. Per-Experience isolation is by filename, not by schema-per-entity — deliberately generic.
- Working-tree changes add `customPath` (for test injection) and constructor-level DI of the database/dataRuntime through `AnythingRuntime(dataRuntime: ...)` → `ExperienceHostScreen(runtime: ...)`, with **correct ownership semantics**: `ExperienceHostScreen.dispose()` only closes the runtime it created itself (`if (widget.runtime == null) unawaited(_runtime.closeSession())`), leaving caller-injected runtimes to the caller — this is exactly the ownership contract Part XXI of the audit brief asked for, and it is already correctly implemented.
- `AnythingRuntime.closeSession()` is now correctly `async` and awaits `_dataRuntime.dispose()`, which awaits `_database.close()` — a real, ordered SQLite close, not fire-and-forget.
- **Nobody in the current test suite exercises this real DI path end-to-end through the actual generated UI for a restart proof** — see §7.

## 7. Stage 11 Certification — NOT TRUTHFULLY COMPLETE

Directly verified (source read + actual `flutter test` execution, not just static review):

- **`test/stage11/stage11_5_production_certification_test.dart`** (untracked, self-labeled "Stage 11.6 — Final certification... Writes still go through real ExperienceDatabase"): **False.** `_CachedDataRuntime.insert/update/delete` (lines ~250-279) write only to an in-memory `Map`, with the code comment "real DB writes deferred to avoid FFI hangs in testWidgets." Running this file directly (`flutter test test/stage11/stage11_5_production_certification_test.dart`) **fails**: `CRUD: create Alice -> detail -> edit -> create Bob -> search -> delete` throws, first hitting an environment-level shader exception (see below) and then failing `expect(... 'Edit' ...)` because the async record load hadn't resolved before the assertion ran — a real fragility in the test's pump sequencing, not a missing feature (the Edit button code itself is present and correct in `experience_renderer.dart`).
- **`test/stage11/stage11_user_path_certification_test.dart`**: has good, real, individually-scoped production-path widget tests for tap-wiring, form submit, search, CRUD — but its restart proof (`group('J. Restart preserves data')`, a plain `test()`, not `testWidgets()`) calls `dataRuntime1.insert(...)` **directly**, bypassing `IntentComposer` → coordinators → `ExperienceHostScreen` → generated UI entirely. This is exactly the Part X-described defect ("restart proof queried fresh DataRuntime directly instead of reopening through trusted opening + production host + generated UI") and it is still present.
- **`test/stage11/stage11_real_generated_app_test.dart`** (untracked): defines `_InMemoryDataRuntime` and `_TestExperienceHost`/`_TestExperienceHostState` — test-side reimplementations of production behavior — and contains 16 conditional assertions (`if (...evaluate().isNotEmpty)` etc.) guarding checks that should be mandatory. This is the older, weaker pattern the brief warned about, still committed to the tree alongside the newer attempts.
- Running the whole `test/stage11` directory: **199 tests, 194 pass, 5 fail.** Of the 5 failures, 4 are attributable to a **local environment defect** — `Exception: Asset 'shaders/ink_sparkle.frag' does not contain appropriate runtime stage data for current backend (SkSL). Found stages: Vulkan` — triggered by any widget test that taps a Material button/list tile with the default Material 3 ink-sparkle splash (`useMaterial3: true`, no `splashFactory` override, in `lib/design_system/theme/anything_theme.dart`). This is a Flutter/engine-artifact backend mismatch in this specific Windows test environment, not a source-code defect; a `flutter precache --force` was attempted to resolve it (did not complete within this session — background/disk-constrained). It should be re-attempted in CI/a clean environment, and independently, setting an explicit `splashFactory` (e.g. `InkRipple.splashFactory`) in the app theme would likely make widget tests robust to this class of environment issue regardless.
- **No dedicated novel-domain certification test exists as a clean, single-purpose artifact.** The closest candidates are domain names mentioned inside `stage11_end_to_end_certification_test.dart`'s doc comments (Equipment Lending, Fossil Catalog, OrbitMetrics) but these need to be confirmed as flowing through real synthesis rather than hand-authored packages — not independently re-verified in this pass.

**Conclusion:** Stage 11 is architecturally very close — the production DI/ownership plumbing needed for a truthful test now exists — but no single current test proves the full vertical slice (create → real SQLite via generated UI → close → reopen → generated UI shows persisted data → edit persists → delete persists) without either faking the write path, bypassing the UI, or depending on optional assertions. See the roadmap for the concrete closure task.

## 8. Universal Synthesis — one real violation found and fixed

- `lib/kernel/resolution/experience_resolver.dart`'s `ExperienceResolver`, constructed by default inside `AnythingKernel` (kernel/anything_kernel.dart:59-72) and called as **step 2** of every `processIntent` call (line 88), hardcoded a `'calculator'` fixture matching keywords `['calculator', 'calc', 'math', 'arithmetic']` against every user expression. `registerExperience` (the intended real-data path, presumably meant to be fed from `ExperienceRepository`) is **never called anywhere** in `lib/` or `test/` — confirmed by repo-wide grep. This meant: (a) it was a literal `if prompt contains "calculator"` domain branch in the live kernel path, directly violating the no-domain-branch principle; (b) it was also a functional bug, since `exp-calculator-001` was never created through the real creation pipeline, so matching expressions would have been routed to `OpenExistingExperience` for an experience that does not exist in the real repository.
- **Fixed this session** (see §12): removed the hardcoded seed; `ExperienceResolver` now starts empty and only ever matches experiences explicitly registered via `registerExperience` (i.e., real ones). No test depended on the old hardcoded id (grep-verified). This is a minimal, generic fix — it does not add any new domain awareness, it removes the only one that existed.
- No other production hardcoding was found: `grep` across `lib/` for calculator/habit/people/contact/equipment/loan/book/expense/workshop/fossil/notes/weather turned up only (a) this now-fixed fixture, (b) `lib/runtime/golden_paths/*` (calculator/habit-tracker fixture *packages*, used exclusively by `test/stage81`, `test/stage94`, `test/runtime` — confirmed via grep that no production `lib/` file imports `golden_paths`; legitimate test fixtures, not production hardcoding), (c) `lib/tools/calculator_tool.dart` — dead v1-era code, not imported by any current v2 module.
- No `CalculatorScreen`/`PeopleScreen`/domain-specific screen classes exist in production.
- No arbitrary-execution primitives found: `grep` for `Process.run`, `Process.start`, `dart:mirrors`, `eval(` across `lib/` returned zero hits.

## 9. Security Boundary (partial verification — see gaps below)

- **Kaalka**: pinned exact version `5.0.0` (pubspec.lock). Single canonical adapter chain: `lib/legacy/kaalka_adapter.dart` (`KaalkaProtectionProvider`) ← imported only by `lib/security/protection_service.dart`. `test/stage94/*` (18 tests) pass against the **real** Kaalka package (not a mock) — protect/unprotect roundtrip, wrong-time rejection, trusted-opening statuses, Activity independence, restart persistence all verified passing.
- **WebWeaveX**: pinned exact version `3.0.0`. Single import site in all of `lib/`: `lib/knowledge/webweavex_adapter.dart`. This matches the intended boundary (no scattered UI/runtime imports).
- **HTTP capability** (`lib/capabilities/builtin/http_capability.dart`): blocks `localhost`/`127.0.0.1`/`::1`/`0.0.0.0`, blocks the full `172.16.`–`172.31.` and `192.168.` private ranges, and enforces `https://`-only URLs (rejects with `'Only HTTPS is allowed'`). This is real, non-trivial SSRF defense, not a stub. (10.x range coverage, redirect handling, and timeout/size-limit enforcement were not independently re-verified in this pass — flagged for the security-focused follow-up in the roadmap.)
- **Arbitrary execution**: none found in generated-Experience execution paths (§8).
- Deeper coverage of `BehaviorInterpreter` execution-budget/cycle handling, `RuntimeComponentRegistry` component-tree limits, and `ExperienceQueryController` query budgets was **not completed** in this pass (the dedicated security research agent was cut off by the account rate limit before reporting) — flagged as open in the Vision Gap Matrix, not claimed as verified.

## 10. Secrets / Repo Hygiene

- `.gitignore` covers `.dart_tool/`, `/build/`, `/coverage/` at repo root; `android/.gitignore` covers `local.properties`, `key.properties`, `**/*.keystore`, `**/*.jks`.
- `.mimocode/` (an unrelated local automation-tool config directory, untracked per `git status`) is **not** covered by any `.gitignore` — low risk (it's a scheduler config, not observed to contain credentials) but should be added to `.gitignore` to prevent accidental `git add -A` commits.
- No `.env`, no committed keystores, no obvious credential files found in the tracked tree.

## 11. OSS / Release Readiness — NOT STARTED

Directly verified: **no** `LICENSE`, **no** `CONTRIBUTING.md`, **no** `CODE_OF_CONDUCT.md`, **no** `SECURITY.md`, **no** `CHANGELOG.md`, **no** `.github/` directory (no CI, no issue/PR templates) anywhere in the repository. `README.md` is a stale v1 description (references "Groq Integration," "AUIL," `gpt-oss-120b`/`gemma2-9b-it` specifically, a "Context Engine" — none of which match the current v2 kernel/synthesis/runtime architecture, and it presents Groq as a required dependency, contradicting the BYOK vision). This is expected pre-release state, not a regression, but it means OSS readiness is 0%, not partial.

## 12. Changes Made This Run

| File | Change | Reason | Test |
|---|---|---|---|
| `lib/kernel/resolution/experience_resolver.dart` | Removed hardcoded `'calculator'` fixture seed from constructor | Live domain-branch violation + dangling-reference bug in the production kernel path (§8) | Verified no test depends on the old id (grep); kernel/creation/stage10 suites re-run to confirm no regression (see §22) |

No Stage 11 test files were modified or weakened in this pass — the certification gap is documented as the concrete next-milestone target (roadmap §M1) rather than papered over.

## 13. Baseline Validation Results

- `flutter pub get`: clean.
- `dart format --set-exit-if-changed lib test`: 11 files need formatting (4 inside the already-modified working-tree set, 7 pre-existing in `test/stage10` and one new stage11 file) — cosmetic only, not run as a fix in this pass to avoid unrelated diff noise on files this audit didn't otherwise touch.
- `flutter analyze`: **0 errors**, 70 issues, all `info`/`warning` (deprecated `withOpacity`, unused test locals/imports, style lints). No production-blocking issues.
- `flutter test test/stage94`: **18/18 pass** (real Kaalka).
- `flutter test test/stage11`: **194/199 pass**, 5 fail — see §7 for root causes (1 real test-fragility bug in a fake-cache cert test, 4 environment shader issue).
- Full `flutter test` suite and `flutter build apk --debug` were not completed in this pass (time/session constraints) — see Remaining Limitations in the final report.

## 14. Known Defects (this audit)

1. **[FIXED]** `ExperienceResolver` hardcoded calculator domain branch + dangling reference (§8, §12).
2. **[OPEN, HIGH]** No truthful Stage 11 restart certification exists (§7) — this is the concrete Stage 11 closure target.
3. **[OPEN, MEDIUM]** Local test environment cannot reliably run Material-ripple widget-tap tests (`ink_sparkle.frag`/Vulkan backend mismatch) — blocks clean CI signal on affected tests until resolved (try `flutter precache --force` in a clean environment, or set an explicit non-sparkle `splashFactory` in the app theme).
4. **[OPEN, LOW]** `.mimocode/` untracked and not gitignored.
5. **[OPEN, LOW]** `lib/tools/` (ToolRegistry/CalculatorTool) is dead v1 code, not wired into v2 kernel/capabilities — candidate for removal.
5b. **[OPEN, LOW]** `lib/screens/*` (12 files: app_shell, workspace(s), templates, memory_dashboard, ai_settings, groq_settings, groq_webview, kaalka_security, onboarding, personal_context, skills_marketplace, splash) is dead v1 code, unreachable from the live `lib/app/app_shell.dart` (verified by import-graph tracing) — includes Groq-hardcoded screens contradicting the BYOK vision. Candidate for removal; likely explains why the README is stale.
6. **[OPEN, HIGH — expected/pre-release]** Zero OSS/release scaffolding (§11).

See `V2_VISION_GAP_MATRIX.md`, `V2_SECURITY_AUDIT.md`, `V2_RELEASE_READINESS.md`, and `V2_COMPLETION_ROADMAP.md` for the structured follow-through.
