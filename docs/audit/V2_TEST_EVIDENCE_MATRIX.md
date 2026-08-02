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

## Documentation vs. reality

`docs/progress/V2_STAGE_11.md` (last touched at commit `68bf60f`, 2026-07-29) claims `Status: COMPLETE` and "119/All passing" — this predates all three untracked Stage 11 test files and the uncommitted production-code DI changes, and does not reflect the 194/199 result measured in this audit. It should be treated as historical, not current, until Stage 11 closure (Roadmap M1) actually lands and this doc is updated with a fresh, dated, execution-verified count.
