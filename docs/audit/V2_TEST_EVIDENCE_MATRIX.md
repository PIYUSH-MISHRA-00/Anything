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

## Vision Milestone V2 — Autonomous Software Architecture Engine (new, 2026-08-02)

| File | Type | What it proves |
|---|---|---|
| `test/software_architect/requirement_extractor_test.dart` | UNIT | RequirementExtractor derives entity/field/relationship/view/action/capability/constraint/storage/state/navigation nodes structurally from a SemanticApp's shape; a dedicated test proves two SemanticApps identical in shape but different in every name produce identically-shaped graphs — the extractor never inspects names |
| `test/software_architect/knowledge_graph_test.dart` | UNIT | KnowledgeGraphBuilder preserves provenance/license/trust/relevance 1:1 from KnowledgeBundle; concept-based linking between resources is real and deterministic |
| `test/software_architect/architecture_planner_test.dart` | INTEGRATION | All 13 sub-planners (entity/field/relationship/state/navigation/interaction/capability/permission/security/offline/synchronization/storage/validation) produce real, justified decisions from one novel-domain SemanticApp ("Telescope Observation Log", zero footprint elsewhere in `lib/`); capability honesty verified (unimplemented capabilities reported, not fabricated); overall confidence proven to be a real computed value, not a constant |
| `test/software_architect/self_critic_and_refinement_test.dart` | UNIT | SelfCritic detects duplicate entities, dangling relationships, empty entities, disconnected navigation, unresolved capabilities, and low confidence at the correct severities; RefinementPlanner fixes auto-fixable critical issues and re-critiques; the loop is proven to terminate deterministically both by convergence and by a hard iteration cap even when the same defect would otherwise persist |
| `test/software_architect/kernel_integration_test.dart` | PRODUCTION-PATH | `AnythingKernel.processIntent` genuinely routes every `ReasoningReady` result through the full ASAE pipeline with no bypass; a dangling reference is provably dropped by refinement and the *final* generated blueprint reflects the fix (not the original broken reference); `ReasoningProviderRequired` still short-circuits before ASAE runs; a pathologically capability-heavy app with unimplemented capabilities fails closed rather than shipping a false success |
| `test/software_architect/performance_test.dart` | PRODUCTION-PATH | Real timings for extraction/planning/refinement/conversion/package-generation; see `docs/progress/V2_ASAE_PERFORMANCE.md` |

**Execution result (V2, 2026-08-02):** all 6 new files pass (39 tests, 0
skipped). Critical regression check:
`flutter test test/stage10 test/stage11` (388 tests, including M1's
`stage11_final_production_certification_test.dart`) re-verified passing
**unchanged** with ASAE now mandatory in the Kernel's reasoning-to-blueprint
path — proof that inserting a real, non-bypassed architecture-planning
stage did not alter the certified end-to-end behavior for a well-formed
generated app.

## Vision Milestone V1 — Real Knowledge Acquisition (new, 2026-08-01)

| File | Type | What it proves |
|---|---|---|
| `test/knowledge/search_provider_test.dart` | UNIT (fake HTTP client) | DuckDuckGoSearchProvider parses real result-link markup, decodes redirect-wrapped URLs, dedupes, respects maxResults, and fails gracefully (empty list, not an exception) on network failure or non-200 responses |
| `test/knowledge/webweavex_adapter_test.dart` | UNIT (real WebWeaveX parsing, fake HTTP fetch) | Real `extractSemanticHtml`/`extractSemanticContent` genuinely runs against canned HTML; unreachable pages, fetch exceptions, non-http URLs, and empty bodies all yield `null` rather than crashing; oversized content is truncated to the trusted ceiling |
| `test/knowledge/knowledge_acquisition_engine_test.dart` | INTEGRATION (fake search + fake-fetch/real-parse extraction) | Full orchestration: provider-unavailable reports unresolved without touching network; multiple search results are all acquired; duplicate content is deduplicated by hash; malformed/unreachable URLs never enter the bundle; a cached query is served without re-invoking the search provider (offline reuse); `KnowledgeCacheKey` is deterministic and language-sensitive |
| `test/knowledge/prompt_injection_test.dart` | INTEGRATION | A resource shaped exactly like real `WebWeaveXAdapter` output, containing injection phrases, cannot alter `ModelApplicationReasoner`'s behavior — delimiter markers present, injection phrases redacted in the actual prompt sent to the model; separately proves the extractor itself does not sanitize (that's the reasoner's job, not blurred across layers) |
| `test/knowledge/knowledge_pipeline_production_test.dart` | PRODUCTION-PATH (real network, self-skips if unavailable) | `KnowledgeAcquisitionEngine` with the real `WebWeaveXAdapter` genuinely fetches and parses a live page end-to-end; a second test exercises the full real default wiring (`DuckDuckGoSearchProvider` + real `WebWeaveXAdapter`) and degrades gracefully if the search step yields nothing |
| `test/knowledge/performance_test.dart` | PRODUCTION-PATH (real network, self-skips if unavailable) | Records real cache-miss vs. cache-hit vs. synthesis timings; see `docs/progress/V2_KNOWLEDGE_PERFORMANCE.md` |

**Execution result (V1, 2026-08-01):** all 6 new files pass (30 tests, 2
self-skippable if network is unavailable — both ran for real in this
environment). Pre-existing `test/stage10/stage10_3_test.dart` and
`stage10_4_test.dart` (Kernel knowledge-loop routing, multi-round
accumulation, dedup, round-limit enforcement — 40+ tests relying on the
pre-V1 `KnowledgeCache.store()`/fuzzy-match API) re-verified passing
unchanged against the rewritten `KnowledgeAcquisitionEngine`, via a
preserved legacy fallback lookup path (see
`docs/architecture/KNOWLEDGE_ENGINE.md` "KnowledgeCache").

## M2 — Security & Runtime Coverage Closure (new, 2026-08-01)

| File | Type | What it proves |
|---|---|---|
| `test/security/behavior_cycle_safety_test.dart` | ADVERSARIAL | A→A, A→B→A, A→B→C→A cycles each execute every node exactly once; per-event execution budget (100) holds at limit−1/limit/limit+1 and against a 5000-node malicious chain; a dangerous node wired past the budget never executes; state-write nodes cannot re-trigger event dispatch (structural re-entrancy proof) |
| `test/security/package_and_query_limits_test.dart` | ADVERSARIAL + INTEGRATION (real SQLite) | Screen count, behavior-node count, manifest field length, and component property text length budgets reject oversized packages; a real SQLite table with more rows than the trusted fetch ceiling never returns more than the ceiling from one `query()` call; requested limits are clamped, never raised |
| `test/security/http_capability_hardening_test.dart` | ADVERSARIAL | IPv6 loopback/unique-local/link-local/IPv4-mapped addresses denied; a declared host that resolves (via injected fake DNS) to a private IP is denied; DNS resolution failure fails closed; oversized response/request bodies rejected. No live network. |
| `test/security/modification_rollback_test.dart` | ADVERSARIAL | A modification spec engineered to blow the behavior-node budget produces a candidate the validator rejects, and the pre-existing package instance is proven byte-for-byte unchanged; experience ID is preserved across a successful modification |
| `test/security/kaalka_tamper_test.dart` | ADVERSARIAL + INTEGRATION (real Kaalka) | A bit-flipped persisted ciphertext fails closed with a redacted message (no raw crypto exception, no leaked ciphertext); a partial-write state (protection flag set, envelope missing) recovers the still-present plaintext when available and fails safely when not |

**Execution result (M2, 2026-08-01):** all 5 new files pass in full; see
`docs/audit/V2_SECURITY_AUDIT.md` for the complete narrative and the
production-code fixes each test certifies (unbounded-fetch DoS, dangling-
reference render crash, migration-identifier sanitization, HTTP IPv6/DNS-
rebinding gaps, AI capability input/output bounds).

**Pre-existing coverage relied on, not re-litigated:** `test/stage81`
(capability declaration/budget/ownership, credential vault shape,
modification data-preservation, Experience data isolation),
`test/stage82`/`test/stage83`/`test/stage84` (file/notification ownership,
capability escalation, migration malicious-identifier rejection,
migration transactional rollback) — all read in full this pass and cited
directly in the Security Audit rather than re-implemented.

## Stage 8.x / 8.1-8.4, 8.2, 8.3, 8.4

Not re-verified line-by-line in this pass (out of scope given session constraints — these predate the generated-UI work and were the subject of prior "closure" commits). `test/stage81/full_loop_test.dart` and `test/stage81/persistence_test.dart` are among the files with uncommitted edits (adjusting call sites for the now-`async` `closeSession()`); not independently re-run.

## Anti-pattern inventory (repo-wide, from direct grep + the completed test-audit research pass before the rate limit)

- Hand-authored `ExperiencePackage`/`InterfaceDefinition` in tests: present in ~8 files; acceptable where used for renderer/validator unit tests in isolation, a red flag specifically where a file also claims "certification" status without a corresponding real-pipeline test elsewhere.
- Direct `DataRuntime.insert/update/delete` bypassing generated UI: ~10 files; expected for CRUD unit tests (Stage 11 group H), a defect specifically in the one restart-proof test that should go through the UI (Group J above).
- Test-only Host/Runtime reimplementations: confined to `stage11_real_generated_app_test.dart`.
- Conditional/optional assertions on required features: concentrated almost entirely in `stage11_real_generated_app_test.dart` (16 instances); one lower-risk instance in `stage11_5_production_certification_test.dart`.
- No `router.push(...)`/`queryController.setSearch(...)` direct-call bypasses found — certification tests that do simulate user action go through real widget taps/text entry, not controller shortcuts. This is a genuine positive.

## Vision Milestone V3 — Application Engineering Engine (2026-08-02)

47 new tests across `test/application_engineering/` (11 files): every
Engineering module in isolation against real `ArchitecturePlanner`-produced
candidates for a novel domain ("Hive Inspection Log", zero footprint in
`lib/`), `EngineeringPlanner` assembly + real computed confidence,
`EngineeringReview` defect detection (dangling bindings, behavior
inconsistencies, low confidence) and `EngineeringRefinement`'s auto-fix/
termination behavior, `EngineeringToBlueprintAugmenter`'s compiled output
(explicitly guarding the `'text'` vs `'string'` `StateVariable` type-string
regression class already hit once in M2), full Kernel-to-Runtime
integration (`AnythingKernel.processIntent` produces an approved
`EngineeringPlan`, `CreationEngine` augments additively — byte-for-byte
identical output when no plan is supplied — and the real, unmodified,
M2-certified `BehaviorInterpreter` genuinely transitions a generated
entity's `<entity>_status` state variable when a real dispatched event
reaches it), and a second, unrelated novel domain ("Lighthouse Maintenance
Log") proving no domain name ever leaks into the fixed `GenericState`
vocabulary.

**Execution result:** all 47 pass in full. Full regression re-run
immediately after: `test/stage10` + `test/stage11` (388 tests, M1
certification, unchanged), full suite (727 tests, all green), `flutter
analyze` (71 issues, 0 errors — identical to the pre-V3 baseline).

## Vision Milestone V4 — Feature Discovery & Dependency Intelligence Engine (2026-08-02)

55 new tests across 10 files under `test/feature_discovery/`:
`FeatureDiscoveryEngine.discover()`'s structural rules (data/persistence/
relational/search/index/capability/navigation/validation/state/reporting/
offline/security features, tested against "Hive Inspection Log", zero
footprint in `lib/`), `plan()`'s full orchestration (real feature-to-feature
edges, real computed confidence, identical graph shape for two
structurally-identical differently-named apps), all 5 `DependencyResolver`s
+ `DependencyGraphBuilder` assembly, `FeaturePriorityAnalyzer` (all 5
priority levels reachable from real signals, including the honest
`experimental` case for an unimplemented capability), `FeatureComplexityAnalyzer`
(typed `ComplexityLevel` only, never a raw number), `FeatureClassifier`
de-duplication, capability discovery across the full known/unknown
capability split, `FeatureReviewer` defect detection (duplicate/dangling/
conflicting/impossible/low-confidence), `FeatureRefinement`'s auto-fix/
termination behavior, full Kernel integration (no bypass, `FeaturePlan`
reaches `ExecutionPlanReady`, Engineering's index/offline decisions are
genuinely corroborated end-to-end), a dedicated Engineering-integration
file proving the DataEngineering/OfflineEngineering cross-references are
additive-only, and a second, unrelated novel domain ("Lighthouse
Maintenance Log").

**Execution result:** all 55 pass in full. Full regression re-run
immediately after: `test/stage10` + `test/stage11` (388 tests, M1
certification, unchanged), full suite (782 tests, all green), `flutter
analyze` (71 issues, 0 errors — identical to the pre-V4 baseline).

## Vision Milestone V5 — Multi-Solution Reasoning & Architecture Selection Engine (2026-08-02)

38 new tests across 9 files under `test/solution_reasoning/`:
`SolutionExplorer`'s full orchestration (never exactly one candidate;
Flat Navigation/Offline First appear only when structurally applicable;
every candidate carries a complete 15-dimension tradeoff table),
`SolutionScorer` (richness/offline scoring rank correctly; every score is
a self-explaining `Confidence`; all 15 `TradeoffDimension` values present
exactly once), `SolutionComparison` (dominance/equivalence/alternative
edges computed from real score+complexity comparisons),
`SolutionSelector` (never "first candidate wins" — proven by placing the
objectively worse candidate first in the input list; Pareto-frontier
filtering; the full ordered tie-break cascade), `SolutionReviewer` (all
seven defect categories: duplicate/equivalent/impossible/contradictory/
weak/overEngineered/incomplete), `SolutionRefinement` (auto-fix/
termination, never drops every candidate), Engineering integration
(minimal vs. full richness produce genuinely different EventGraphs;
each candidate's own EngineeringPlan reflects its own architecture
variant), full Kernel integration (no bypass, the blueprint derives from
the selected solution, the EngineeringPlan is `identical()`-reused rather
than recomputed), and a second, unrelated novel domain ("Beekeeper's
Apiary Rotation Log").

Two real bugs were caught and fixed during development: (1) an
over-aggressive "contradictory" review check false-flagged any full-
richness candidate for an app with zero declared views (where
`supportsSearch` is legitimately always `false`) — fixed by skipping the
check when `NavigationGraph`'s decision id is the `'navigation:default'`
single-screen fallback; (2) a novel-domain test fixture requested the
`knowledge` capability without registering it in the test's
`CapabilityRegistry`, causing capability resolution to reject the
blueprint — fixed by registering it, matching the same class of fixture
bug already seen (and fixed the same way) in V4's own novel-domain test.

**Execution result:** all 38 pass in full. Full regression re-run
immediately after: `test/stage10` + `test/stage11` (388 tests, M1
certification, unchanged), full suite (820 tests, all green), `flutter
analyze` (71 issues, 0 errors — identical to the pre-V5 baseline).

## Vision Milestone V6 — Self-Critique & Autonomous Design Review Engine (SCARE) (2026-08-02)

42 new tests across 11 files under `test/design_review/`: every one of the
15 sub-reviewers against a real, approved design (no false positives) and
against a deliberately manufactured defect (correctly flagged) —
`ArchitectureReviewer`, `DependencyReviewer` (redundant/missing edges,
auto-fixable), `EngineeringReviewer`, `SpecificationReviewer` +
`NavigationReviewer` (including two dedicated regression fixtures,
`multiEntityApp()` and `dashboardApp()`) + `BehaviorReviewer`,
`CapabilityReviewer`/`SecurityReviewer`/`IntegrityReviewer` (including a
dedicated Kaalka-tamper regression guard), `AccessibilityReviewer`
(including a dedicated "never fabricate capability" regression guard),
`PerformanceReviewer`/`MaintainabilityReviewer`/`OfflineReviewer`/
`RuntimeReviewer`, `MigrationReviewer`/`ModificationReviewer`/
`ConsistencyReviewer`, `ReviewMemory`/`ReviewHistory` (fingerprint reuse,
nothing lost), `ReviewRefinement` (auto-fix applied and logged, never
silent), `DesignReviewEngine` end-to-end (approval, deterministic
fingerprint, concrete denial reasons), full Kernel integration (no bypass,
Review Memory reused across two structurally-identical requests, the
blueprint reaching Creation is the one Design Review actually approved),
and a second, unrelated novel domain ("Lighthouse Keeper's Fuel Log").

Four real bugs were caught and fixed during development, all via this
milestone's own full-regression run against `test/stage10`/`test/stage11`
(pre-existing, novel-domain-rich fixtures the initial narrow test fixtures
never exercised) — see `docs/architecture/DESIGN_REVIEW_ENGINE.md` for full
detail:

1. `EngineeringReviewer` false-flagged real search bindings as unused
   (assumed every `viewToState` edge was field-shaped; search bindings are
   not).
2. `ReviewRefinement`'s loop condition (`hasCriticalIssues`) never applied
   warning-severity auto-fixes, decoupled from approval-blocking logic.
3. `NavigationReviewer` false-flagged independent multi-entity list screens
   as unreachable, not knowing about `CreationEngine`'s real bottom-
   navigation reachability path. Fixed by cross-referencing
   `context.blueprint.views`.
4. `NavigationReviewer` correctly caught a genuine, pre-existing gap in
   `CreationEngine`: `dashboard`-type entry views never got the "Add
   \<entity\>" button that `list`-type views get, leaving a dashboard-only
   entity's form screen genuinely unreachable (caught by the pre-existing
   "OrbitMetrics" stage11 certification fixture). Fixed at the root in
   `CreationEngine._buildInterfaceFromBlueprint`, not by relaxing the
   reviewer.

**Execution result:** all 42 pass in full. Full regression re-run
immediately after: `test/stage10` + `test/stage11` (M1 certification,
unchanged), full suite (862 tests, all green — up from 820 pre-V6), `flutter
analyze` (71 issues, 0 errors — identical to the pre-V6 baseline). `flutter
build apk --debug` attempted; blocked by the same standing, pre-existing,
Anything-code-unrelated `KeytoolException: Failed to read key
AndroidDebugKey ... Tag number over 30 is not supported` JDK/keytool
incompatibility confirmed in every prior milestone.

## Vision Milestone V7 — Autonomous Evolution Engine (AEE) (2026-08-02)

48 new tests across 11 files under `test/evolution/`: `EvolutionObserver`
(every one of its 10 opportunity categories against real fixtures —
deferred FeatureGraph nodes become real missingCapability/missingWorkflow
opportunities in exact 1:1 correspondence; a low-field-count entity
correctly does NOT trigger missingSearch, proving the detector is a real
threshold; a multi-entity app with independent list screens produces zero
missingNavigation false positives; accessibility/performance/
maintainability opportunities trace to real, still-present SCARE
`ReviewIssue`s), `EvolutionEstimator` (every candidate's benefit bounded
0.0-1.0 and fully explained; offline/synchronization candidates carry
real migration/data risk; priority derived structurally, never a bare
number), `EvolutionReviewer` (every real, observed candidate accepted by
construction; a candidate whose sourceReviewIssueId no longer exists is
rejected; a candidate referencing a missing entity is rejected),
`EvolutionApprover` (only accepted candidates become proposals; none
pre-approved for execution), `EvolutionPlanner`/`EvolutionRoadmap` (every
roadmap owns all 6 phases even when empty; budget cap respected; a
conservative strategy never places more into "immediate" than an
aggressive one would for the same candidates), `EvolutionPrediction`
(every forecast carries a real confidence and named basis; a
multi-entity/multi-relationship app forecasts higher storage-evolution
likelihood than a single-entity app; capability-addition forecasts trace
only to real roadmap proposals), `EvolutionGraph` (every candidate
produces a real currentState->opportunity->candidate chain; a
synchronization candidate structurally requires its matching offline
candidate; every requires-edge verified to genuinely connect the claimed
categories), `EvolutionEngine` end-to-end (deterministic fingerprint;
memory/history recording and recall; `EvolutionMetrics.from` accounting),
`EngineeringMemory` (accepted/rejected ideas and tradeoffs sourced from
the real EvolutionMemory; architectural/security/performance history
verified as real filtered slices of ReviewHistory, not a separate
ledger), `EvolutionExecutor`/`EvolutionValidator` (an unapproved proposal
never compiles regardless of category; missingCapability compiles to a
real `requiredCapabilities` entry; missingWorkflow/missingNavigation/
missingSearch/missingFiltering compile to a real `addUiNode`
`ModificationOperation`; missingAccessibility/missingPerformance/
missingMaintainability/missingOffline/missingSynchronization are
honestly reported `EvolutionNotExecutable`, never a fabricated no-op;
executing a compiled proposal against a real golden-path package produces
a valid, updated package via the **existing** `ModificationEngine`),
`EvolutionCoordinator` end-to-end against a **real SQLite-backed
repository** (real file I/O, not a mock): applying a proposal persists a
new validated version; a user objective merges into the executed spec's
objective rather than being silently dropped; a not-yet-executable
proposal fails honestly; a nonexistent experience fails honestly), full
Kernel integration (Evolution Planning runs for every approved design,
never blocks creation, EvolutionMemory reused across two structurally-
identical requests), and a second, unrelated novel domain ("Community
Seed Library Exchange").

One real bug was caught and fixed during development, via this
milestone's own test-writing (not the full-regression pass, since AEE is
purely additive and could not regress any pre-existing suite):
`EvolutionReviewer`'s fallback branch assumed every non-feature,
non-review-issue-sourced opportunity was entity/interaction-shaped, but
offline/synchronization opportunities are architecture **posture**-shaped
(their evidence's `affectedNodeId` is a decision id like
`"synchronization:strategy"`, not an entity id) — the fallback's
`architecture.interactions.any((i) => i.entityId == entityId)` check
always failed for these, incorrectly rejecting every real
offline/synchronization opportunity. Fixed by adding a dedicated posture
branch that checks the candidate's evidence against the architecture's
current `offline.decision.id`/`synchronization.decision.id` instead.

**Execution result:** all 48 pass in full. Full regression re-run
immediately after: `test/stage10` + `test/stage11` (M1 certification,
unchanged), full suite (910 tests, all green — up from 862 pre-V7),
`flutter analyze` (71 issues, 0 errors — identical to the pre-V7
baseline). `flutter build apk --debug` attempted; blocked by the same
standing, pre-existing, Anything-code-unrelated `KeytoolException: Failed
to read key AndroidDebugKey ... Tag number over 30 is not supported`
JDK/keytool incompatibility confirmed in every prior milestone.

## Vision Milestone V8 — Runtime Intelligence Layer (RIL) (2026-08-02)

41 new tests across 10 files under `test/runtime_intelligence/`:
`ObservationEngine` (drives REAL `ExperienceRouter`/
`ExperienceQueryController`/`ExperienceStateEngine` instances — the same
objects the generated-app runtime uses — and proves captured records
never carry raw navigation-argument, search-term, filter-value, or
state-value content; `recordFailure`/`recordCapabilityUsage` structural;
`dispose()` genuinely cancels subscriptions), `UsageGraph`/
`PatternDetector`/`LearningEngine` (aggregation never crosses
experiences; all 4 pattern kinds detected — including the literal
"task app -> calendar -> reminder" 3-hop sequential-workflow example
from this milestone's own spec, detected purely structurally; explicit
false-positive proofs for below-threshold pairs and one-directional
navigation; determinism and versioning), `RecommendationEngine`/
`RecommendationReview` (every recommendation traces to a real, present
pattern; a recommendation rejected when its pattern is missing; Evolution
Integration: a recommendation already proposed by a real
`EvolutionRoadmap` is never duplicated), `AutomationPlanner`/
`AutomationExecutor`/`AutomationHistory`/`AutomationMemory`/
`BackgroundCoordinator`/`NotificationPlanner`/`ReminderPlanner`
(plans only automation/workflow-shaped recommendations; validation-only
executor never invokes anything; a step naming an unregistered
capability is honestly blocked; history/memory versioned and recallable;
background queue respects budget and policy), `PredictionEngine`
(frequency-ranked, deterministic, empty for an unvisited screen),
`InteractionGraph`/`ExperienceRelationshipGraph`/`CollaborationGraph`
(real followed-by chains; relationship inference proven both positive
and negative — zero structural overlap produces zero edges; collaboration
graph correctly requires 2+ independent signals), `RuntimeIntelligenceEngine`
end-to-end (deterministic; honest empty result for empty observations),
`RuntimeIntelligenceCoordinator` (real Runtime Integration via a real
`ExperienceRouter`; real `CapabilityRegistry` validation; a REAL
SQLite-backed `buildRelationshipGraph`/`buildCollaborationGraph` against
two real golden-path packages), a combined Kernel + Evolution Integration
test (a real `AnythingKernel.processIntent()` run's `evolutionRoadmap`
fed directly into `RuntimeIntelligenceEngine`, proving no recommendation
ever collides with a real Evolution proposal), and a second, unrelated
novel domain ("beekeeping apiary rotation") proving zero domain-specific
logic exists anywhere in the package.

No bugs were found this milestone (the design's heavy reuse of already-
certified V6/V7 patterns — evidence-verification review, dedup-by-
description, typed graph node/edge shapes — meant the areas most likely
to hide a defect were already proven correct elsewhere).

**Execution result:** all 41 pass in full. Full regression re-run
immediately after: full suite (951 tests, all green — up from 910
pre-V8), `flutter analyze` (71 issues, 0 errors, 0 new warnings —
identical to the pre-V8 baseline). `flutter build apk --debug` attempted;
blocked by the same standing, pre-existing, Anything-code-unrelated
`KeytoolException: Failed to read key AndroidDebugKey ... Tag number over
30 is not supported` JDK/keytool incompatibility confirmed in every prior
milestone.

## Vision Milestone V9 — World Model & Semantic Graph (WMSG) (2026-08-02)

48 new tests across 10 files under `test/world_model/`: `EntityIdentity`/
`EntityResolver`/`RelationshipIdentity` (structural fingerprints are
order-independent and cross-"experience" identical for identical shapes;
different shapes/kinds produce different identities), `WorldGraph`/
`GraphIndex`/`GraphResolver` (real typed lookups; `concat` never
deduplicates, proving `GraphMerge` is the only deduplication path),
`GraphTraversal` (bounded forward/reverse traversal; an explicit cyclic-
graph test proving termination; relation-kind filtering), `GraphSearch`/
`GraphQuery`/`SemanticQueryEngine` (typed query execution; a minimal
structural intent parser proven both for a recognized phrase and an
unrecognized one, never crashing), `GraphMerge`/`GraphConflict` (clean
dedup for identical identity+kind+label; a real, surfaced conflict for
identical identity with a different kind/label, never silently
overwritten; edge deduplication), `GraphConsistency`/`GraphValidation`
(a sound graph validates; a dangling edge is honestly reported),
`GraphProjection`/`GraphView`/`SemanticGraph.projectFrom` (real filtered
sub-graphs; `SemanticGraph` proven to exclude non-semantic kinds like
`review`), `ImpactAnalyzer`/`DependencyAnalyzer` (a synthetic "what
breaks if the http capability changes" scenario correctly names both
real consuming Experiences and excludes an unrelated third one),
`WorldPlanner`/`WorldModelEngine` (a clean update is approved and
versions the model; a dangling-edge update is honestly rejected and
leaves the model **completely unchanged** — proven directly), all 5
Bridges with real fixtures — Knowledge Integration (a real
`KnowledgeGraph` with `ResourceProvenance`/`LicenseMetadata`/
`TrustMetadata`), Experience Integration (a real golden-path
`ExperiencePackage`), Evolution Integration (a real `EvolutionRoadmap`),
Runtime Integration (a real `UsageGraph` and real `LearningRecord`s from
V8's own `LearningEngine`), Review Integration (a real SCARE
`ReviewSession` via `test/design_review/review_test_support.dart`) —
plus a combined-bridges consistency check, `WorldModelCoordinator`
end-to-end (deterministic versioning; Modification Integration via
`precheckModification`; a real SQLite-backed bulk ingestion of two real
golden-path Experiences proving capability-node deduplication across
Experiences), a combined Kernel + Evolution + Review Integration test
(a real `AnythingKernel.processIntent()` run's `reviewSession`/
`evolutionRoadmap` both ingested cleanly), and a second, unrelated novel
domain ("orchid cultivation").

No bugs were found this milestone — the design's heavy reuse of
already-certified V4/V6/V7/V8 patterns (the shared `{id,kind,label}`
node shape, evidence-verification review, deterministic fingerprinting
already proven in `ReviewMemory`/`EvolutionMemory`/RIL's fingerprints)
meant the areas most likely to hide a defect were already proven correct
elsewhere; the one known rough edge (evolution-affected-node ids not
always aligning with `ExperienceGraphBridge`'s structural fingerprints)
was designed around explicitly rather than discovered as a bug.

**Execution result:** all 48 pass in full, first run. Full regression
re-run immediately after: full suite (999 tests, all green — up from
951 pre-V9), `flutter analyze` (71 issues, 0 errors, 0 new warnings —
identical to the pre-V9 baseline). `flutter build apk --debug`
attempted; blocked by the same standing, pre-existing, Anything-code-
unrelated `KeytoolException: Failed to read key AndroidDebugKey ... Tag
number over 30 is not supported` JDK/keytool incompatibility confirmed
in every prior milestone.

## Documentation vs. reality

`docs/progress/V2_STAGE_11.md` (last touched at commit `68bf60f`, 2026-07-29) claims `Status: COMPLETE` and "119/All passing" — this predates all three untracked Stage 11 test files and the uncommitted production-code DI changes, and does not reflect the 194/199 result measured in this audit. It should be treated as historical, not current, until Stage 11 closure (Roadmap M1) actually lands and this doc is updated with a fresh, dated, execution-verified count.
