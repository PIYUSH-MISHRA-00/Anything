# Anything v2.0.0 — Completion Roadmap

Built from the gaps documented in `docs/audit/V2_CURRENT_STATE_AUDIT.md`, `V2_VISION_GAP_MATRIX.md`, `V2_TEST_EVIDENCE_MATRIX.md`, `V2_SECURITY_AUDIT.md`, `V2_DESIGN_PARITY.md`, and `V2_RELEASE_READINESS.md` — not from historical stage numbering. Six milestones, ending at v2.0.0 Release Candidate.

**Note on numbering:** "Vision Milestone V1 — Real Knowledge Acquisition &
Autonomous Generation" (2026-08-01), "Vision Milestone V2 — Autonomous
Software Architecture Engine" (2026-08-02), "Vision Milestone V3 —
Application Engineering Engine" (2026-08-02), "Vision Milestone V4 —
Feature Discovery & Dependency Intelligence Engine" (2026-08-02), and
"Vision Milestone V5 — Multi-Solution Reasoning & Architecture Selection
Engine" (2026-08-02), "Vision Milestone V6 — Self-Critique & Autonomous
Design Review Engine (SCARE)" (2026-08-02), and "Vision Milestone V7 —
Autonomous Evolution Engine (AEE)" (2026-08-02), and "Vision Milestone V8 —
Runtime Intelligence Layer (RIL)" (2026-08-02), and "Vision Milestone V9 —
World Model & Semantic Graph (WMSG)" (2026-08-02) are a separate, product-capability
track from the M1-M6 hardening/readiness milestones below. V1 converted the knowledge-
acquisition pipeline from a stub to real `package:webweavex`-backed
retrieval; V2 inserted a real, typed, self-critiquing architecture-
planning stage between reasoning and blueprint conversion; V3 inserted a
real, typed Engineering stage between architecture approval and
blueprint/spec/plan conversion, compiling a generic per-entity state
machine into the existing BehaviorGraph/StateSchema vocabulary so the
unmodified BehaviorInterpreter executes it; V4 inserted a real, typed
Feature Discovery stage between requirement extraction and Architecture
Planning, surfacing cross-cutting features and their dependencies
structurally; V5 replaced the single-candidate architecture stage with
genuine multi-solution reasoning — 2-4 real architecture variants
generated, scored across 15 tradeoff dimensions, reviewed, refined, and
selected via an ordered tie-break cascade rather than "first candidate
wins," with Engineering now consuming the selected SolutionCandidate
exclusively; V6 inserted a mandatory Design Review gate (15 sub-reviewers,
conservative auto-fix, Review Memory/History) between Solution Reasoning
and blueprint consumption, failing closed if approval isn't reached; V7
inserted a mandatory Evolution Planning stage (EvolutionEngine: Observe ->
Estimate -> Review -> Approve -> Plan -> Predict) between Design Review
and blueprint-to-spec conversion, producing a real, reviewed, ranked
roadmap for every approved design without ever auto-executing anything,
plus a separate EvolutionCoordinator extending the existing
ModificationEngine pipeline for Modification Integration; V8 added a
Runtime Intelligence Layer (ObservationEngine subscribing to the
Runtime's own real navigation/query/state streams, LearningEngine/
PatternDetector finding real structural usage patterns, Recommendation
Engine reusing Evolution's roadmap for dedup, and 100% declarative
Automation Planning/Scheduling) as a separate, application-facing
RuntimeIntelligenceCoordinator — not a new Kernel pipeline stage, since
Observation is inherently post-Runtime; V9 unified every existing graph
(DependencyGraph/EvolutionGraph/KnowledgeGraph/RIL's graphs) into one
typed, versioned WorldGraph via 5 pure-translation Bridges, introducing
the first stable, cross-Experience EntityIdentity (a deterministic
structural fingerprint, never a database) and graph-based Impact/
Dependency Analysis — again via a separate WorldModelCoordinator, not a
new Kernel stage. None of the nine map onto this M-series sequencing;
the M1/M2 rows below remain accurate and unaffected. See
`docs/progress/V2_KNOWLEDGE_PERFORMANCE.md` /
`docs/architecture/KNOWLEDGE_ENGINE.md` (V1),
`docs/progress/V2_ASAE_PERFORMANCE.md` /
`docs/architecture/SOFTWARE_ARCHITECT_ENGINE.md` (V2),
`docs/architecture/APPLICATION_ENGINEERING_ENGINE.md` (V3),
`docs/architecture/FEATURE_DISCOVERY_ENGINE.md` (V4),
`docs/architecture/SOLUTION_REASONING_ENGINE.md` (V5),
`docs/architecture/DESIGN_REVIEW_ENGINE.md` (V6),
`docs/architecture/EVOLUTION_ENGINE.md` (V7),
`docs/architecture/RUNTIME_INTELLIGENCE_LAYER.md` (V8),
`docs/architecture/WORLD_MODEL_AND_SEMANTIC_GRAPH.md` (V9),
`docs/architecture/RELEASE_CANDIDATE_HARDENING.md` (V10), and
`docs/architecture/SOFTWARE_COGNITION_ENGINE.md` (V11) for closure
evidence. V10 — Release Candidate Engineering & Production Hardening —
resolved every V9-documented persistence limitation (World Model/Runtime
Intelligence memory now survive process restart via the existing SQLite
architecture), wired `precheckModification()` into the real Modification
production path, unified Evolution/World identities for blueprint-matched
entities, added the repository's first structured logging/diagnostics
module and CI/CD pipeline, and closed a real SQLite migration gap. V11 —
Software Cognition & Universal Software Acquisition Engine — is complete:
it gives Anything the ability to understand existing repositories/
packages/APIs/components/architecture (via a pure typed translation of
WebWeaveX's own already-computed deterministic repository IR — never a
second acquisition/parsing engine), reason about them across multiple
independently-acquired sources (never adopting a pattern from a single
source), enforce a real copyright/attribution boundary, and feed that
understanding into the existing, unmodified LLM-reasoning prompt pathway
via a real `KnowledgeResource` — all while keeping the generated
application fresh and never assembled from copied source. Per its own
instructions, V12 awaits external architectural review before starting.

**V10's relationship to M3/M5/M6 below:** V10 made real, scoped progress
on ground these M-series milestones also cover — a real (but partial,
not full-retrofit) accessibility fix (M3), a real (but unexecuted-in-CI)
GitHub Actions workflow (M6) — without closing either milestone outright.
M3/M5/M6 remain open for the reasons stated in their own sections below;
V10's `V2_VISION_GAP_MATRIX.md` rows reflect the partial status honestly
rather than claiming closure.

---

## M1 — Stage 11 Truthful Closure (S/M) — ✅ COMPLETE (2026-07-31)

**Closure evidence:** `test/stage11/stage11_final_production_certification_test.dart`
(new, 5/5 pass) proves the full slice named in the objective below, for a
real novel domain (community garden plots — zero footprint in `lib/`,
verified by an automated in-test scan), with only the `ModelProvider`
faked. Full `test/stage11` suite: 200/200 pass, 0 failures (was 194/199,
5 fail). Full repo `flutter test` (no exclusions): 575/575 pass. Getting
there required 3 production fixes beyond the expected "none required" —
see `docs/progress/V2_STAGE_11.md` ("M1 — Stage 11 Truthful Closure") and
`docs/audit/V2_CURRENT_STATE_AUDIT.md` §7 for the full account: a router
validation bug (empty-string `targetScreenId` silently rejected pop
actions), a missing router-history seed (broke pop-to-root on first
navigation), and a missing widget key (edit forms discarded async-loaded
record data). `stage11_5_production_certification_test.dart` and
`stage11_real_generated_app_test.dart` were deleted (superseded, actively
misleading); `stage11_user_path_certification_test.dart` Group J was
relabeled to its true, narrower scope. All acceptance-gate items below are
met.

**Objective:** One real, passing, end-to-end certification test proving: user expression → `IntentComposer` → production creation pipeline → generated `ExperiencePackage` → package validation → Experience persistence → trusted opening → production `ExperienceHostScreen` → real SQLite → generated Add/Save/Edit/Search/Delete through the actual generated UI → Runtime+Database close → fresh trusted reopen of the same SQLite file → fresh Runtime → fresh production host → edited record survives → deleted record stays absent. No cached/in-memory write path, no direct `DataRuntime` bypass for the restart proof, no test-only host, no optional assertions on required behavior.

**Why it exists:** this is the one concrete, high-confidence gap blocking every downstream claim about the product working. The production DI plumbing needed already exists (verified this audit) — `AnythingRuntime(dataRuntime: ...)`, `ExperienceDataRuntime(database: ...)`, `ExperienceDatabase(customPath: ...)`, and `ExperienceHostScreen(runtime: ...)` with correct ownership semantics. What's missing is a test that actually uses that plumbing honestly through `tester.runAsync()` for the real async SQLite calls triggered by widget interaction, instead of caching writes or bypassing the UI.

**Dependencies:** none blocking — can start immediately.

**Production changes:** likely none required (the DI surface is already correct); if the shader/environment issue turns out to be reproducible outside this specific machine, consider setting an explicit `splashFactory` (e.g. `InkRipple.splashFactory`) in `lib/design_system/theme/anything_theme.dart` for robustness, independent of whether it's the actual root cause here.

**Tests:** one new test file (or a rewritten `stage11_5`) using `tester.runAsync()` to wrap every real-SQLite-triggering interaction; retire or clearly relabel `stage11_real_generated_app_test.dart` (drop the 16 optional assertions or make them mandatory) and fix `stage11_user_path_certification_test.dart` Group J to go through the UI instead of calling `DataRuntime.insert` directly. Add one dedicated novel-domain synthesis test (a domain with zero footprint in `lib/`, e.g. "community garden plot tracker") as a clean, standalone artifact proving open-world synthesis, separate from the restart certification.

**Security considerations:** none — this is a test-truthfulness fix, not a boundary change.

**Design requirements:** none.

**Acceptance gate:** the new certification test passes in a clean environment (confirm the shader issue isn't masking it); `docs/progress/V2_STAGE_11.md` updated with a dated, execution-verified test count; no remaining "certification" test in `test/stage11/` contains a false claim about what it proves.

---

## M2 — Security & Runtime Coverage Closure (M) — ✅ COMPLETE (2026-08-01)

**Closure evidence:** `docs/audit/V2_SECURITY_AUDIT.md` (fully rewritten),
`docs/security/TRUST_BOUNDARIES.md`, `docs/security/CAPABILITY_SECURITY_MATRIX.md`,
`docs/security/RUNTIME_LIMITS.md` (all new), plus five new adversarial test
files under `test/security/` (behavior cycle/budget safety, package/query
structural limits, HTTP SSRF hardening, modification rollback, Kaalka
tamper resistance). Every security-relevant UNKNOWN in the pre-M2 audit is
now VERIFIED. Concrete production fixes made: an unbounded-SQLite-fetch
DoS vector, a dangling-reference render crash, a latent DDL-identifier-
injection path in an unused migration module, HTTP IPv6/DNS-rebinding/
response-size gaps, AI capability input/output bounds, and new
package-level structural budgets (screens, behavior-node count, property
text length, package size), all centralized in
`lib/security/runtime_security_limits.dart`. Master finding: the
`CapabilityPlatform` (Clock/Notifications/HTTP/AI/Knowledge/File) is fully
built and well-tested but not yet wired into the live
`AnythingRuntime`/`BehaviorInterpreter` dispatch path — only Clock is
reachable from a running Experience today. This narrows today's real
attack surface while the capability code has still been hardened ahead of
that integration, which is out of M2 scope by design. Zero critical,
currently-exploitable vulnerability found. M1's certification
(`test/stage11/stage11_final_production_certification_test.dart`) remains
green throughout, unweakened.

**Objective:** Close every UNKNOWN in `V2_SECURITY_AUDIT.md`: behavior-graph cycle safety under a malicious/malformed graph, component-tree budget enforcement (verify it's the production validator under test, not a reimplementation), query-controller budgets/pagination/allowed-fields, per-capability audit for Clock/Notifications/AI/Knowledge/File (registration, ownership, budget, permission model), HTTP capability gaps (10.0.0.0/8 coverage, redirect re-validation, size/timeout enforcement), migration system audit (stable IDs, transactional, malicious-identifier defense), modification engine audit (data preservation, versioning, rollback), relationship referential-integrity-on-delete behavior, secure-storage usage pattern for API keys.

**Why it exists:** these aren't known holes, but "unknown" is not an acceptable state to ship on for a security boundary that generated, LLM-produced applications run inside of.

**Dependencies:** none blocking; can run in parallel with M1.

**Production changes:** fix whatever the audit finds; expect this to be mostly verification with a handful of small hardening fixes, not a redesign (per repo evidence, the boundary architecture is already sound).

**Tests:** one regression test per confirmed gap; a dedicated malicious-behavior-graph test (cycle, oversized graph) if not already covered.

**Acceptance gate:** every row in `V2_SECURITY_AUDIT.md` and the security-related rows of `V2_VISION_GAP_MATRIX.md` reads VERIFIED, not UNKNOWN.

---

## M3 — Design Parity & Accessibility Pass (M) — NEXT (not started)

M2 is complete. Per the standing priority rule, M3 is now the approved
next milestone — not started as part of M2's closure, consistent with M2's
explicit stop condition (audit/harden only, no design/accessibility work).

**Objective:** Establish a definitive mapping of which ~10-15 Stitch screens (of the ~85 in `design/stitch/product_foundation/`) are canonical for v2.0.0 scope, then do a real screen-by-screen comparison against the four live screens (Home, My Apps, Activity, Preferences) plus creation/birth flow, Experience host, and empty/error states. Follow with an accessibility pass (semantic labels, touch targets, text scaling, contrast, reduced motion) and confirm tablet/responsive behavior. Resolve the ink-sparkle/theme question from M1 as part of this (does the design call for Material sparkle ripple or not).

**Why it exists:** the vision brief is explicit that design is a product requirement, not decoration, and this was the one area this audit could not verify at all due to the research-agent cutoff.

**Dependencies:** benefits from M1's theme decision but isn't blocked by it.

**Production changes:** UI/theme adjustments as gaps are found; move search filtering into the query layer if scale testing during this pass shows it's needed (currently client-side over the full result set).

**Design requirements:** the mapping doc itself (extend `docs/design/STITCH_IMPLEMENTATION_MAP.md`).

**Acceptance gate:** a completed, evidence-based `V2_DESIGN_PARITY.md` with no UNKNOWN rows for the in-scope screens; accessibility checklist passes on the four live screens.

---

## M4 — Knowledge & Modification Depth (M)

**Objective:** Verify and, where needed, harden: (a) WebWeaveX-retrieved content is treated as untrusted data in the synthesis/reasoning prompt pipeline, never as instructions that can alter trust decisions (Part LIX's prompt-injection concern); (b) the modification engine's full path (scoped modification intent → reasoning → candidate package → validation → migration → activation → rollback) preserves data and correctly versions, with a real test exercising it end-to-end through production coordinators, not hand-authored packages; (c) model-output robustness (schema validation, malformed/hallucinated component or capability types, oversized output) is handled as untrusted input throughout.

**Why it exists:** these are the two "AI is doing the generating, and the internet is feeding it knowledge" trust boundaries the vision brief calls out explicitly (Parts LVI, LVIII, LIX) and that weren't independently re-verified this audit.

**Dependencies:** benefits from M1 (shares certification-test patterns) and M2 (shares security-audit methodology).

**Production changes:** expected — this is the most likely milestone to surface a real gap requiring new code, since modification/knowledge-trust wasn't confirmed working at all in this pass, only confirmed to architecturally exist.

**Acceptance gate:** one production-path modification test proving data preservation across a real NL-driven modification; documented, verified answer to "is retrieved knowledge ever treated as authority" with evidence either way.

---

## M5 — Android / Play Store Readiness (S/M)

**Objective:** Verify and close: application ID, versionName/versionCode, min/target/compile SDK, declared permissions match actual capability usage, network security config, signing configuration (verify configured without exposing secrets), adaptive icon, `flutter build apk --debug` and (where a signing environment is available) release build both succeed.

**Why it exists:** not independently checked at all in this audit pass; unknown is not the same as ready.

**Dependencies:** none blocking.

**Acceptance gate:** debug build succeeds; readiness checklist in `docs/release/PLAY_STORE_READINESS.md` updated with verified (not aspirational) status.

---

## M6 — OSS & Release Engineering (M)

**Objective:** Add `LICENSE` (pick and confirm a license — user decision, not a default to assume), `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, `.github/workflows` (at minimum: format check, analyze, test on push/PR), issue and PR templates. Rewrite `README.md` to describe the actual v2 architecture (kernel/synthesis/creation/runtime, BYOK providers, Kaalka/WebWeaveX roles) instead of the stale v1 Groq/AUIL description. Remove the dead `lib/screens/*` (12 files) and `lib/tools/*` v1 code identified in this audit so a new contributor doesn't mistake it for live code. Verify `docs/oss/THIRD_PARTY_NOTICES.md` is current against the actual dependency list.

**Why it exists:** zero OSS scaffolding exists today; this is expected at this stage of development but is real, non-trivial work standing between the current repo and a public release.

**Dependencies:** should come after M1-M5 substantively land, since the README and CI gates should describe/enforce a codebase that's actually in the state being claimed.

**Acceptance gate:** a first-time contributor can clone, read CONTRIBUTING.md, run the documented setup steps, and open a PR that passes CI, without needing any context from this audit.

---

## MIS-1 Implementation Track (R1-R9) — separate from the M-series above

Following the Vision Milestone track (V1-V11) and the four MIS-1
audit/design documents (Repository Audit, Architecture Map, Integration
Blueprint, Canonical Engineering Specifications — all Desktop
deliverables, not tracked in this repo), a third, parallel implementation
track (R1-R9) executes MIS-1 Part 3's Implementation Roadmap. This is
distinct from the M-series (M1-M6) above, which predates MIS-1.

### R1 — Canonical Composition Root — ✅ COMPLETE (2026-08-02)

**Closure evidence:** `docs/architecture/PRODUCTION_COMPOSITION_ROOT.md`
(new). A single `AppComposition` (lib/app/app_composition.dart) now holds
one shared `WorldModelCoordinator`/`CapabilityPlatform`/`CredentialVault`/
`AnythingProviderRegistry`/`AnythingKernel`, threaded to
`HomeScreen`/`ExperiencesScreen`/`ExperienceHostScreen`. `AnythingKernel`
gained an optional `WorldModelCoordinator?` parameter (auto-ingests
`ReviewSession`/`EvolutionRoadmap` when present, best-effort, never
failing generation). `ExperienceServiceResolver` now dispatches
`httpClient`/`notifications`/`fileAccess`/`knowledgeRetrieval`/
`aiInference` through the real `CapabilityPlatform` (real backing for
http/ai/knowledge via new thin adapters over already-canonical systems;
notifications/files remain Fake-backed, honestly documented). BYOK
credential storage now routes through `CredentialVault` instead of raw
`FlutterSecureStorage`. Software Cognition gained an optional,
purely-additive `referenceUrl` creation-pipeline hook. 9 new integration
tests (`test/app/r1_composition_root_test.dart`). Full regression: see
`docs/audit/V2_TEST_EVIDENCE_MATRIX.md`'s R1 section for exact counts;
zero pre-existing test modified. `flutter analyze`: 71/0, unchanged
baseline.

**Known limitations carried to R2+:** `ingestKnowledge` still unreached
(no clean `KnowledgeBundle` → `KnowledgeGraph` conversion point scoped
this milestone); `NotificationCapability`/`FileCapability` have no real
production backing service; no UI entry point yet for the Software
Cognition `referenceUrl` hook; `RuntimeIntelligenceCoordinator`/
`ObservationEngine.attachSession()` remain unwired (explicitly out of
R1's scope — see MIS-1 Part 3's roadmap for R2+).

---

### R2 — Knowledge Intelligence / World Knowledge Integration — ✅ COMPLETE (2026-08-02)

**Closure evidence:** `docs/architecture/KNOWLEDGE_ENGINE.md`'s "World
Graph ingestion (Implementation Milestone R2)" section (new). Closed
R1's `ingestKnowledge` limitation — investigation found both
`KnowledgeGraphBuilder.build(KnowledgeBundle)` and
`KnowledgeGraphBridge.bridge(KnowledgeGraph)` already existed as real,
general implementations (not test-only fixtures), and Kernel Step 5.5
already built a real `KnowledgeGraph` for Feature Discovery — R2 reused
that same value and passed it to
`_worldModel?.ingestKnowledge(knowledgeGraph)` via R1's existing
`_ingestIntoWorldModelSafely` helper. A real bug was found and fixed in
the process: `KnowledgeGraphBridge` resolved World Graph identity from
the acquisition-timestamp-based `KnowledgeResource.id`, so every
re-fetch of the same URL previously minted a brand-new, never-deduped
node — fixed by resolving identity from `sourceUri` instead. 9 new
tests (`test/world_model/knowledge_ingestion_test.dart`): identity
stability, real dedup, real conflict-rejection (the existing,
unmodified `WorldPlanner` all-or-nothing gate — not changed by R2), full
Kernel wiring (with/without a `WorldModelCoordinator`, and with one that
throws, proving generation can never fail because of a World Graph
error), Knowledge + Software Cognition sharing one graph, and a real
300-resource performance measurement. Full regression: 1121/1121 (up
from 1112), zero pre-existing test modified; `flutter analyze`: 71/0,
unchanged baseline.

**Known limitation carried forward:** conflict representation stays
surface-and-reject, not "represent both sides with confidence for later
reasoning" — `WorldNode`'s minimal `{identity, kind, label}` shape
(shared identically by all 6 Bridges) has no field for confidence or
freshness. Extending it is a real, legitimate, additive schema change,
but touches all 6 Bridges and the persisted schema — a properly scoped
migration in its own right, not folded into this wiring milestone.

---

## R3 — Deterministic Engineering Pipeline (Implementation Milestone) — ✅ COMPLETE

**Closure evidence:** `docs/architecture/DETERMINISTIC_ENGINEERING_PIPELINE.md`.
Investigation confirmed the AI boundary (one mandatory LLM call),
Architecture Graph (`ArchitectureCandidate`), and Engineering Graph
(`EngineeringPlan`) all already existed and needed no new parallel
system — only verification. Real new work: Knowledge/Software Cognition
and World Model (capability-familiarity) now structurally enrich Feature
Discovery confidence (`FeatureConfidenceAnalyzer`, bounded ±0.1/+0.05,
never overriding the base per-feature analysis), and a new, real,
deterministic `RequirementGraphDiff`/`RequirementGraphDiffer`
(`lib/software_architect/requirement_graph_diff.dart`) — planning-only,
mirroring `GraphMerge`'s established structural-comparison shape.
Engineering Cache investigated and deliberately not built (near-zero
real-world hit rate for LLM-derived, request-unique input — YAGNI).
Full regression: 1136/1136 (up from 1121), zero pre-existing test
modified; `flutter analyze`: 71/0, unchanged baseline.

**Known limitations carried forward:** only `RequirementGraphDiff` was
built; Architecture/Engineering/Experience Diff are a real, scoped R4+
candidate. The diff chain is not wired into any UI/modification flow yet
— a real, tested, standalone capability. World Model read-enrichment is
scoped to capability familiarity only, not the full "user preferences/
learned patterns" ambition.

---

## Implementation Milestone R4 — Incremental Software Evolution — ✅ COMPLETE (2026-08-03)

**Closure evidence:** `ArchitectureDiff`/`EngineeringDiff`/`ExperienceDiff`
(new) extend R3's `RequirementGraphDiff` pattern; composed into
`EvolutionDiffPlan`, deliberately not a duplicate of V7's
`EvolutionRoadmap`/`EvolutionProposal` after direct investigation (see
`docs/architecture/INCREMENTAL_EVOLUTION_DIFFING.md` for the full
rationale). `ExperienceModificationCoordinator.planEvolution()` is real,
planning-only, and never persists; World Model ingestion on acceptance
(closing MIS-1 Part 2's `ingestExperience` finding) is proven never to
fire on rejection. 17 new tests, full suite 1153/1153 (up from 1136),
`flutter analyze` 71/0 unchanged. Runtime patching remains explicitly
out of scope, confirmed via `git diff` showing zero changes to
`AnythingRuntime`/`ExperienceRenderer`.

**Known limitation carried to R5+:** `planEvolution` only populates
`ExperienceDiff` in practice, since `RequirementGraph`/
`ArchitectureCandidate`/`EngineeringCandidate` are transient,
Kernel-internal artifacts never persisted per Experience —
`EvolutionDiffPlanBuilder` accepts the other three diffs when a future
caller has both instances, but no such caller exists yet.

---

## Implementation Milestone R5 — Engineering Memory — ✅ COMPLETE (2026-08-03)

**Closure evidence:** new `EngineeringMemoryRepository`
(`lib/storage/engineering_memory_repository.dart`) persists
`RequirementGraph`/`ArchitectureCandidate` per Experience with full,
real `toJson()`/`fromJson()` fidelity, and `EngineeringPlan` as a real,
honest `EngineeringMemorySummary` — the same "summary, not full
fidelity" call V10 already made for `LearningRecord`/`AutomationRecord`,
applied here because `EngineeringCandidate`'s real type tree spans
~1700 lines across 10 files. Shares `SqliteExperienceRepository`'s
connection exactly like `WorldModelRepository` (no new storage layer).
Wired at creation time (`ExperienceCreationCoordinator`, via
`AppComposition`) and read at `planEvolution()` time
(`ExperienceModificationCoordinator`), both optional/null-by-default —
fully backward compatible, proven by a real test that a pre-R5
Experience (no engineering memory row) degrades gracefully. `AnythingKernel`'s
`ExecutionPlanReady` gained one additive `requirementGraph` field
(previously computed and discarded). Full suite: **1168/1168** (up from
1153, +15, zero regressions). `flutter analyze`: 71/0, unchanged.

**Known limitation carried to R6+:** `EngineeringDiff` still cannot be
populated with real historical state (a persisted summary can't satisfy
`EngineeringDiffer.diff()`'s full-`EngineeringCandidate` signature).
`requirementDiff`/`architectureDiff` remain `null` in `planEvolution()`'s
output — no genuine "after" Requirement/Architecture state is derivable
without re-running Kernel-level planning (would need either a new LLM
call or new inference machinery, both out of scope); real historical
"before" state is surfaced instead via
`EvolutionDiffPlan.historicalEngineeringMemory`, honestly not a diff.

---

## v2.0.0 Release Candidate

**Objective:** All of M1-M6 acceptance gates met; `flutter analyze` clean; full `flutter test` suite passes (not just the subsets exercised in this audit); `flutter build apk --debug` succeeds and release build succeeds where a signing environment is available; no UNKNOWN rows remain in `V2_VISION_GAP_MATRIX.md` for anything in v2.0.0 scope; `docs/progress/V2_STAGE_11.md` and other stage docs reflect actual, dated, execution-verified state; CI is green on the release branch.

**Acceptance gate:** this document's own checklist, re-run and all green, immediately before tagging.

## Implementation Milestone R6 — Deterministic Runtime Patching — COMPLETE (2026-08-03)

Closes R4's deferred "runtime application" scope. `ExperienceModificationCoordinator`
gained `applyEvolutionPlan()`/`rollback()` — real validate-persist-reload
through the existing, unmodified `AnythingRuntime`/`ExperienceRenderer`,
real deterministic rollback via a held pre-apply package snapshot (no
repository version history exists, confirmed by source read), World
Model ingestion on accepted evolution only. No new patch-operation
vocabulary — the existing `ModificationType` enum already covered it.
No granular in-place widget patching (MIS-1 already flagged this as
high-risk/not-recommended-near-term) — full reload through the existing
renderer is the real, honest, low-risk scope achieved instead.
Regression: 1177/1177 (+9). Analyzer: 71/0, unchanged.

**Recommendation for R7**: (1) wire `applyEvolutionPlan()`/`rollback()`
into the actual `ExperienceHostScreen` UI (currently only
`modifyExperience()` is UI-wired; the richer plan-based path is real,
tested, and available but not yet the UI's default) — mirrors the same
"real, available, not yet composition-root-wired" pattern several prior
milestones' new coordinators started with; (2) decide whether
navigation/scroll/form-state preservation across a patch-triggered
reload is worth pursuing, given it's a real, named, pre-existing
limitation this milestone did not attempt to fix.

## Implementation Milestone R7 — Runtime Experience Integration (2026-08-03) — ✅ COMPLETE

Closed R6's own recommendation directly: `ExperienceHostScreen`'s live
modification flow now calls `planEvolution()` → `applyEvolutionPlan()`
(documented routing decision: `modifyExperience()` itself unchanged,
still real/tested/available for other callers — only the UI's call site
changed, since only the plan-based path returns a real `previousPackage`
for genuine Undo). Real single-level Undo via `SnackBarAction` +
`rollback()`. Real Evolution History reusing the existing
`ActivityRepository` (no new repository), enriched with a real
diff-derived summary and a real measured `durationMs` (new, optional,
backward-compatible field on `ActivityEvent`). Real progress
announcements at genuine await boundaries. Honest, scoped state
preservation (current tab/screen only — scroll/focus/text-field
contents explicitly NOT preserved, named as a real limitation, not
attempted). Zero changes to `AnythingRuntime`/`ExperienceRenderer`/
`BehaviorInterpreter` (confirmed via `git diff`).

Two real bugs found and fixed via this milestone's own widget testing:
`ExperienceHostScreen` had no way to inject a test-seeded modification
coordinator (added a `modificationCoordinator` DI parameter, matching
the existing `runtime`/`worldModel`/`engineeringMemory` convention); a
rollback confirmation snackbar was silently queued behind the original
update snackbar (fixed with `ScaffoldMessenger.hideCurrentSnackBar()`).

Regression: 1185/1185 (+8). Analyzer: 71/0, unchanged.

**Recommendation for R8**: (1) decide whether scroll-position/focused-
widget/text-field-content preservation across a reload is worth the
larger `ExperienceRenderer`/`ExperienceRouter` work required — a real,
still-open limitation across R6 and R7; (2) consider whether Evolution
History should surface `EngineeringMemoryRepository`'s persisted
Requirement/Architecture "before" snapshots (R5) alongside the
Experience-level summary, for a richer per-entry explanation; (3) the
standing Capability Platform / BYOK-provider-count / localization gaps
from MIS-1/V10 remain open and unrelated to the R-series' own scope.

## Implementation Milestone R8 — Full-Stack Autonomous Engineering (2026-08-03)

**Closure evidence**: `lib/backend_engineering/` (9 files) extends the
deterministic engineering pipeline into real Database Schema/API
Specification (genuine depth) plus honestly-minimal Authentication/
Storage/Background-Jobs/Deployment specification — never generated SQL,
backend source, or deployment config, purely typed data. Wired into
`AnythingKernel.processIntent` (additive Step 7.8, zero new AI call,
proven deterministic via a real double-run test), `EngineeringMemoryRepository`
(R5, additive column + migration, integrity-hash formula deliberately
left unchanged for backward compatibility), and World Model (`WorldNodeKind.backendEndpoint`,
database tables unify with the existing `entity` kind). 19 new tests,
full regression 1204/1204 (up from 1185). `flutter analyze`: 71/0,
unchanged baseline.

**Recommendation for R9**: (1) an actual implementation-generation
milestone consuming these specifications (still out of scope for R8 by
design); (2) richer Authentication modeling once/if a real upstream
signal for end-user identity requirements is introduced elsewhere in
the pipeline; (3) the standing Capability Platform / BYOK-provider-count
/ localization gaps from MIS-1/V10 remain open and unrelated to the
R-series' own scope.

## Implementation Milestone R9 — Canonical Implementation Model — ✅ COMPLETE (2026-08-03)

**Closure evidence**: `lib/implementation_model/` (3 files) unifies
frontend Engineering (`EngineeringCandidate`, R3) and backend
Engineering (`BackendEngineeringPlan`, R8) into one real, typed,
mechanically-verified LANGUAGE-INDEPENDENT `CanonicalImplementationModel`
covering 20 implementation concepts with honestly-uneven depth (real
depth for Entity/Repository/Controller/DTO/Validator/Service/
StateContainer/NavigationHandler/CapabilityAdapter; thin real wrappers
for Authentication/Storage/BackgroundWorker; Realtime/Configuration/
Serialization/Error-Handling/Logging/Monitoring deliberately not
modeled). Wired into `AnythingKernel.processIntent` (additive Step 8.5,
zero new AI call, proven deterministic via a real double-run test
through the full Kernel path), `EngineeringMemoryRepository` (additive
column + migration, integrity-hash formula deliberately left
unchanged), and World Model (`ImplementationGraphBridge`, narrowly
contributing entity-to-capability dependency edges only — a
dangling-edge bug was found and fixed by this milestone's own test).
15 new tests, full regression 1219/1219 (up from 1204). `flutter
analyze`: 71/0, unchanged baseline.

**Recommendation for R10**: (1) an actual language generator consuming
`CanonicalImplementationModel` to produce real target-language source
(still out of scope for R9 by design — the model is structurally ready
but not yet validated by a real consumer); (2) per-entity capability
dependency attribution once/if a real upstream signal ties a resolved
capability to one specific entity, replacing the current `'app'`
pseudo-node; (3) Realtime Channel/Configuration/Serialization/Error-
Handling/Logging/Monitoring modeling once/if a real upstream engineering
decision for any of these appears elsewhere in the pipeline; (4) the
standing Capability Platform / BYOK-provider-count / localization gaps
from MIS-1/V10 remain open and unrelated to the R-series' own scope.

## Implementation Milestone R10 — Universal Generator Framework (2026-08-03) — ✅ COMPLETE

**Closure evidence**: `lib/generator_framework/` — a real, language-
independent `Generator` interface plus one intentionally minimal
reference generator (`SummaryManifestGenerator`), proving R9's
`CanonicalImplementationModel` has a real, deterministic, working
consumer. Investigation confirmed `GenericPackageBuilder` (a test-only,
Anything-internal, Flutter-`ExperiencePackage`-specific helper explicitly
marked "DO NOT use in production code") was the only prior candidate and
is categorically different from a pluggable multi-target generator
interface — no duplication, genuinely new work. Zero new LLM calls (a
real double-run determinism test proves it). Engineering Memory and
World Model integration were both investigated and deliberately declined
this milestone, with real, documented rationale (generation output is a
cheap, reproducible function of already-persisted data; nothing durable
is produced yet to bridge into the World Graph) — see
`docs/architecture/GENERATOR_FRAMEWORK.md`. 8 new tests, full regression
1227/1227 (up from 1219). `flutter analyze`: 71/0, unchanged baseline.

**Recommendation for R11**: (1) a real target-language generator — the
natural next step, and the first real test of whether the `Generator`
interface's shape holds up under genuine complexity (this may motivate
extending `Generator.generate()` to async, and giving `GeneratorOptions`
real typed fields); (2) revisit Engineering Memory/World Model
integration once a real generator's actual cost/persistence needs are
known; (3) the standing Capability Platform / BYOK-provider-count /
localization gaps from MIS-1/V10 remain open and unrelated to the
R-series' own scope.

## Implementation Milestone R11 — Universal Build Graph (2026-08-03)

`UniversalBuildGraph` (`lib/build_graph/`) closes R10's own "no real
dependency ordering yet" gap: a real, deterministic, language-independent
graph derived from `CanonicalImplementationModel`, mirroring — never
reusing directly — the World Graph's proven `{id, kind, label}` node
shape (World Graph's own vocabulary is whole-application-scoped;
Build Graph's is generation-scoped). Real DFS cycle detection and real
Kahn's-algorithm topological ordering were both genuinely new,
necessary algorithmic work (`GraphTraversal`'s existing bounded BFS
answers a different question and cannot itself distinguish "fully
explored" from "mid-exploration," which cycle detection requires).
`GeneratorContext`/`GenerationPipeline` (R10) were updated to consume
the graph instead of the model directly, retaining `sourceModel` so
`SummaryManifestGenerator`'s real logic needed only a one-line read-path
change. Engineering Memory and World Model integration were both
investigated and declined again, for the same real reason R10 already
established: the graph is a free, deterministic re-derivation of
already-persisted, already-ingested data, not new durable knowledge.
12 new tests, full regression 1239/1239 (up from 1227, R10's own 8 tests
updated to the new API and re-verified, not weakened). `flutter analyze`:
71/0, unchanged baseline.

**Recommendation for R12**: (1) a real target-language generator now has
both a typed model AND a dependency-ordered graph to consume; (2) revisit
incremental/partial-build support once a real, measurably-expensive
generator exists with real numbers to justify it; (3) the standing
Capability Platform / BYOK-provider-count / localization gaps from
MIS-1/V10 remain open and unrelated to the R-series' own scope.

## Implementation Milestone R12 — Canonical Generation Specification (2026-08-03)

`lib/generation_specification/` (`PathTemplate`/`ArtifactMapping`/
`GenerationRule`/`GenerationSpecification`) closes R10's own "generators
hardcode their own path/naming decisions" gap: a real, typed,
language-independent contract for how a `BuildGraphNode` (R11) becomes a
generated `Artifact` (R10), moving that decision out of generator code
and into real, inspectable rule data. `SummaryManifestGenerator` (R10)
was genuinely refactored — not given new, unused sibling types — to
resolve its entity-artifact and manifest paths through an injected
specification, defaulting to `GenerationSpecification.defaultReference`
(proven byte-for-byte equivalent to the exact pre-R12 hardcoded paths by
a dedicated regression-equivalence test). A second test proves a
genuinely different specification measurably changes real output paths
while content assembly — deliberately left as real generator logic,
since forcing it into "specification" data would mean fabricating a
template engine — stays correctly field-derived. Investigation found no
reusable mapping/template concept anywhere in the codebase;
`RuntimeComponentRegistry` informed only the DESIGN shape (closed,
typed, kind-to-output), never reused directly. Engineering Memory and
World Model integration were investigated and declined again, for a new
reason specific to this milestone: a `GenerationSpecification` is a
fixed, `const`, generator-owned ruleset — architecturally CODE, not
per-Experience durable knowledge. 8 new tests, full regression 1247/1247
(up from 1239). `flutter analyze`: 71/0, unchanged baseline.

**Recommendation for R13**: (1) a real target-language generator remains
the highest-value next step — the first real pressure-test of whether
`GenerationSpecification`'s current path/naming-only rule shape is
sufficient, or whether genuine content-template needs motivate extending
it with real, justified depth; (2) revisit the deferred mapping types
(Module/Package/Resource/Capability/Dependency/Lifecycle/Configuration/
Build/Validation Mapping, named in R12's own spec but not modeled) once
a real generator actually needs them — never speculatively; (3) the
standing Capability Platform / BYOK-provider-count / localization gaps
from MIS-1/V10 remain open and unrelated to the R-series' own scope.

**DO NOT START R13 — per this milestone's own stop condition, wait for
external architectural review.**

## Implementation Milestone R13 — Runtime Experience Generator (2026-08-03)

`RuntimeExperienceGenerator`
(`lib/generator_framework/reference/runtime_experience_generator.dart`)
is R13's real generator recommendation, delivered: the first
substantial `Generator` (R10) implementation, consuming a real
`CanonicalImplementationModel` (via `UniversalBuildGraph.sourceModel`,
R9/R11) and producing a real, valid `ExperiencePackage` that the
EXISTING, unmodified `ExperienceRenderer`/`BehaviorInterpreter`/
`AnythingRuntime`/`ExperienceHostScreen` render and execute
immediately — not Flutter/Dart source generation, not recompilation.
Screen/behavior/state shape deliberately mirrors `CreationEngine`'s own
blueprint-driven conversion (same screen-id/event-id conventions the
Runtime already parses), sourced from `CanonicalImplementationModel`'s
entities/controller-operations instead of `AppBlueprint`'s
entities/views. `list`/`get`/`search` operations produce no behavior
node (the renderer already queries live); only `create`/`update`/
`delete` do, matching `CreationEngine`'s own scope. The generator's own
`GenerationSpecification` (R12) supplies only a `manifestPathTemplate`
— `rules` stay genuinely unused, a structural consequence of emitting
one aggregate artifact rather than per-node files. DTOs/Validators/
Services/`StateContainerSpec`/`NavigationHandlerSpec` routes/
authentication/background-worker requirements are honestly reported as
`skippedFeature` diagnostics, never fabricated into package structure.

The centerpiece test proves the full loop for real: a hand-built
`CanonicalImplementationModel` -> real `BuildGraphBuilder` -> real
`GenerationPipeline` -> decoded `ExperiencePackage` -> the real
`ExperiencePackageValidator` -> the real `ExperienceHostScreen` mounted
over real SQLite -> a full create/search/detail/edit/delete cycle
driven by real widget taps, verified against real SQLite state
throughout (same discipline as Stage 11's own certification test).
Writing this test surfaced one real, pre-existing `ExperienceHostScreen`
characteristic (a single-entity app's detail screen does not re-fetch
its cached record after an edit-then-pop-back to the same screen ID) —
named, documented, deliberately not fixed (out of scope: this
milestone's own "existing, unmodified Runtime" framing). 7 new tests,
full regression 1254/1254 (up from 1247). `flutter analyze`: 71/0,
unchanged baseline.

**Recommendation for R14 (if resumed)**: (1) fix the
`ExperienceHostScreen` detail-cache characteristic named above, as its
own, independently-scoped, honestly justified change — not silently
folded into a future generator milestone; (2) a second, genuinely
different real generator would be the strongest remaining test of
`Generator`'s "one interface, many implementations" claim (today proven
by exactly `SummaryManifestGenerator` + `RuntimeExperienceGenerator`);
(3) the standing Capability Platform / BYOK-provider-count /
localization gaps from MIS-1/V10 remain open and unrelated to the
R-series' own scope.

**DO NOT START R14 — per this milestone's own stop condition, wait for
external architectural review.**

## Implementation Milestone R14 — Software Cognition Engine, Semantic Software Understanding (2026-08-03)

Investigation (the milestone's own mandatory first step) confirmed
Vision Milestone V11's `lib/software_cognition/` (23 files) already IS
the Software Cognition Engine the milestone asked for — real,
tested, WebWeaveX-consuming, copyright/attribution-bounded — but two of
its own key application-facing methods
(`SoftwareCognitionCoordinator.syncToWorldModel`/
`syncPackageToWorldModel`) had zero production callers (MIS-1 Part 2's
finding, re-confirmed by grep before writing any code). R14 is
therefore an EXTENSION milestone, not a new-engine milestone, matching
the milestone's own "Nothing may be duplicated" rule.

**Wired (real production callers, R14):** `ExperienceCreationCoordinator
._acquireSoftwareCognitionSeed` (`lib/app/creation_coordinator.dart`)
now calls `syncToWorldModel` best-effort whenever a sound acquisition
and an injected `WorldModelCoordinator` are both present — the same
non-blocking, accept-only contract every other `ingest*` call site in
this codebase already uses.

**Extended (real, tested, honestly-scoped additions):**
`AuthenticationPatternAnalyzer`/`NavigationPatternAnalyzer`
(`lib/software_cognition/architecture_analyzer.dart`) fill the two real
gaps found auditing Software Cognition's output taxonomy against the
milestone's own requested categories — same documented substring-match
convention as the existing `StorageAnalyzer`; two new `SoftwareNodeKind`
values, unified into the World Graph's existing `softwareComponent`
catch-all, no new World Graph node kind needed.
`CanonicalImplementationContext.corroboratingRecommendations` /
`CanonicalImplementationModel.corroboratedPatterns` (new, additive)
carry real, multi-source-corroborated `SoftwareRecommendation`s
verbatim into the implementation model — proven correct at the planner
boundary, full-fidelity serialized, backward-compatible with pre-R14
persisted rows.

**Deliberately declined (investigated, found to require fabrication,
matching R3/R10/R11/R12's own "decline with a documented reason"
precedent):** an automatic capability-id cross-reference between
acquired Software Cognition understanding and this generation's
resolved capabilities. Investigation found `CapabilityRegistry`
(`lib/capabilities/registry/`, the Kernel Step 8 registry
`resolvedCapabilities` is sourced from) has ZERO production callers
registering any `CapabilityDescriptor` — the join key this
cross-reference would need is unpopulated in every real generation
today (confirmed via repo-wide grep; only test fixtures construct one).
Building a matcher against permanently-empty production data would be
the same kind of vacuous integration this investigation explicitly
avoided elsewhere — named as a separate, pre-existing structural
finding instead, unrelated to Software Cognition itself.

**Also deliberately not done:** threading
`corroboratingRecommendations` through `AnythingKernel.processIntent`'s
own signature. The only real production caller
(`ExperienceCreationCoordinator.createFromIntent`) acquires at most ONE
reference repository per creation, and `SoftwareReasoner`'s real,
deliberate `minSupportingCandidates: 2` acceptance gate can therefore
never produce an accepted recommendation from today's only production
entry point — adding a Kernel parameter that is always empty in every
real invocation would not be honest, tested integration work. The hook
is real and proven correct at the planner boundary; Kernel wiring is a
named, scoped recommendation for whenever multi-reference acquisition
exists.

18 new tests, full regression 1272/1272 (up from 1254). `flutter
analyze`: 71/0, unchanged baseline. Zero new LLM calls anywhere in the
diff. `lib/generator_framework/`/`lib/build_graph/` (the compiler,
R10-R13) untouched.

**Recommendation for R15 (if resumed)**: (1) multi-reference Software
Cognition acquisition (a real caller that acquires 2+ repositories per
creation) would make `corroboratingRecommendations` non-vacuous in
production and complete the CanonicalImplementationModel enrichment
loop this milestone only proved at the planner boundary; (2) the
`CapabilityRegistry`-has-zero-production-callers finding deserves its
own architectural review — independent of Software Cognition; (3) the
R13 `ExperienceHostScreen` detail-cache characteristic and the
"second, genuinely different generator" recommendation remain open from
R13.

## Implementation Milestone R15 — Multi-Source Software Cognition, Evidence Corroboration Engine (2026-08-03)

Closes exactly R14's own named gap: `corroboratingRecommendations`/
`corroboratedPatterns` were real and tested at the planner boundary but
unreachable from production because the only real caller acquired at
most one reference source per creation, permanently failing
`SoftwareReasoner`'s `minSupportingCandidates: 2` gate. Investigation
(re-confirmed by reading the reasoner directly, not assumed) found the
multi-source reasoning math itself — `reasonAboutRepositories`/
`reasonAboutPackages` — was already fully real and tested since V11;
only the acquisition boundary needed to grow.

**Wired:** `ExperienceCreationCoordinator.createFromIntent`/
`createFromExpression` gained an additive `List<String>? referenceUrls`
(the existing single `referenceUrl` still works unchanged; the one real
production call site in `lib/features/home/home_screen.dart` passes
neither and is unaffected). Every URL is acquired through the same,
unchanged `understandRepositoryFromUrl` (still the only, WebWeaveX-gated
path); every sound source's graph is synced into the World Model (not
just the first); every sound `RepositoryModel` is passed together to the
reasoner (a new `SoftwareCognitionCoordinator.reasoner` getter, mirroring
the existing `engine` getter, reuses the identical instance
`suggestEvolutionOpportunities` already uses). `AnythingKernel.processIntent`
gained an additive `corroboratingRecommendations` parameter, threaded
into Step 8.5 — the one line R14 documented as missing.

**New:** `CorroborationSummary` (`lib/software_cognition/software_reasoner.dart`)
— a small, deterministic aggregate ("Consensus Metadata") over an
already-returned recommendation list. "Conflicts" is honestly
operationalized as single-source, uncorroborated claims — not a
contradiction detector, since no concern taxonomy exists to determine
two sources are really disagreeing rather than just each mentioning
something different.

**Verified, not assumed:** a real test proves two distinct sources
reporting the same real-world package collapse into ONE World Model node
(`GraphMerge`'s existing identity-keyed dedup, V9, unchanged); a real
test creates via the Kernel with two corroborating sources and reads a
populated `corroboratedPatterns` back from `EngineeringMemoryRepository`
— the first genuinely non-vacuous, production, end-to-end proof of R14's
hook.

10 new tests, full regression **1283/1283** (up from 1273). `flutter
analyze`: 71/0, unchanged baseline. Zero new LLM calls. `lib/generator_framework/`/
`lib/build_graph/`/`lib/runtime/` untouched.

**Recommendation for R16 (if resumed)**: (1) a real UI affordance for
supplying multiple reference sources in `lib/features/home/home_screen.dart`
— the pipeline is now real end-to-end, only the UI entry point is
missing; (2) `CapabilityRegistry`'s zero-production-callers finding
(named by R14, still unaddressed) deserves independent architectural
review; (3) the R13 `ExperienceHostScreen` detail-cache characteristic
and R10's "second, genuinely different generator" recommendation remain
open.

**DO NOT START R16 — per this milestone's own stop condition, wait for
external architectural review.**

## Implementation Milestone R16 — Autonomous Knowledge Acquisition Planner, Intent-Driven Software Discovery (2026-08-03)

Closes R15's own "no UI yet" limitation from a different angle: instead
of a human supplying reference URLs, the Kernel can now autonomously
discover what to search for. Investigation found two already-real
pipelines that never met — the Kernel's existing knowledge-loop
(`KnowledgeAcquisitionEngine`, autonomous, generic `KnowledgeResource`s)
and Software Cognition's repository understanding (R14/R15, real, but
always human-URL-driven). The bridge: `SemanticApp.knowledgeNeeds`, a
real field the SAME single reasoning call already populates on its
final result, confirmed by repository-wide grep to have been read by
nothing downstream before this milestone.

**Wired:** `AutonomousKnowledgeAcquisitionPlanner`
(`lib/knowledge/autonomous_knowledge_planner.dart`) deterministically
turns `knowledgeNeeds` into a ranked plan — zero new LLM call, zero
invented needs. `AnythingKernel` gained an optional
`SoftwareCognitionCoordinator?` and an opt-in `autoDiscoverKnowledge`
parameter (default `false`); when true, a new Step 5.5 searches
(`SearchProvider`, reused via a new `KnowledgeAcquisitionEngine.
searchProvider` getter) and understands (`SoftwareCognitionEngine.
understandRepositoryFromUrl`, unchanged) each actionable target, then
corroborates via the UNCHANGED `SoftwareReasoner.reasonAboutRepositories`
— merging with, never replacing, whatever `corroboratingRecommendations`
R15's manual path already supplied. `ExperienceCreationCoordinator` and
`AppComposition.production()` thread the new opt-in flag and share one
`SoftwareCognitionCoordinator` instance between the Kernel and the
Coordinator.

**Declined:** any live LLM prompt/schema change to teach the model
`resourceType`'s software categories more reliably — a real, separate,
higher-risk change to a tested production LLM integration, named as a
recommendation rather than made silently inside this milestone.

**Verified, not assumed:** a real Kernel-level test proves two fake
search results corroborate "flutter" into `corroboratedPatterns` with
zero human-supplied reference URLs; a real test proves the default
(`autoDiscoverKnowledge: false`) never calls `SearchProvider` even with
actionable `knowledgeNeeds` present (byte-for-byte backward
compatibility); a real test proves R15's manual path and R16's
autonomous path compose additively in one call.

17 new tests, full regression **1300/1300** (up from 1283). `flutter
analyze`: 71/0, unchanged baseline. Zero new LLM calls. `lib/generator_framework/`/
`lib/build_graph/`/`lib/runtime/` untouched.

**Recommendation for R17 (if resumed)**: (1) a real UI toggle for
`autoDiscoverKnowledge` in `lib/features/home/home_screen.dart`; (2) if
autonomous discovery proves valuable, the higher-risk `model_reasoner.dart`
prompt/schema change to teach the model `resourceType`'s software
categories deliberately and separately; (3) `CapabilityRegistry`'s
zero-production-callers finding (named by R14/R15, still unaddressed)
deserves independent architectural review; (4) the R13
`ExperienceHostScreen` detail-cache characteristic and R10's "second,
genuinely different generator" recommendation remain open.

**DO NOT START R17 — per this milestone's own stop condition, wait for
external architectural review.**

## Implementation Milestone R17 — Semantic Solution Architecture, Full-Stack Architecture Synthesis (2026-08-03)

Of R17's 20 requested representation categories, 11 were already real
(`ArchitectureCandidate`, V2/V5; `BackendEngineeringPlan`'s 6 sub-models,
R8). New `SemanticSolutionArchitecture` (`lib/solution_architecture/`)
composes both BY REFERENCE, never duplicating their data, and adds real
architecture-shaped `SolutionComponent`s (Components/Services/
Interfaces/Dependencies/Responsibilities/Boundaries/Contracts/Lifecycle/
Ownership, derived per entity) plus one genuinely new signal —
`CachingModel`, an honest restatement of `BackendEngineeringPlan
.backgroundJobs.sourceStrategy` (already real since R8). The other 8
requested concepts (Realtime/Messaging/Notifications/Observability/
Monitoring/Configuration/Policies/Scaling) have zero real signal
anywhere in this codebase's engineering models and are honestly named
in `unmodeledConcepts`, never fabricated — continuous with
`CanonicalImplementationModel`'s own identical, pre-existing (R9)
honesty call.

`CanonicalImplementationModel`/`CanonicalImplementationPlanner` were
deliberately NOT extended — `SemanticSolutionArchitecture` composes the
SAME two inputs `CanonicalImplementationContext` already requires, so a
third parameter would add no real information; `SemanticSolutionArchitecture`
is exposed additively on `ExecutionPlanReady.solutionArchitecture`
instead. `lib/generator_framework/`/`lib/build_graph/`/`lib/runtime/`
are completely untouched — `BuildGraphBuilder` only ever reads
`entities`/`controllers`/`capabilities` from the unmodified
`CanonicalImplementationModel`, so the Build Graph's consumption chain
is satisfied transitively, proven by a real regression test against the
existing `RuntimeExperienceGenerator`.

Two new Software Cognition pattern analyzers (`RealtimePatternAnalyzer`/
`CachingPatternAnalyzer`, mirroring R14's exact shape) give real
dependency-hint-based grounding for 2 of the 9 gaps. New
`SolutionArchitectureGraphBridge` ingests frontend entities into the
World Graph for the first time ever (confirmed by grep: zero
`ArchitectureCandidate` references in `world_model_coordinator.dart`
before this milestone) — unifying with `BackendGraphBridge`'s existing
entity nodes via the same `stableId` convention, plus real
permission-capability edges and a real caching signal node.

20 new tests, full regression **1320/1320** (up from 1300, zero
regressions). `flutter analyze`: 71/0, unchanged baseline. Zero new LLM
calls.

**Recommendation for R18 (if resumed)**: (1) extend
`RealtimePatternAnalyzer`/`CachingPatternAnalyzer`'s findings into
`SemanticSolutionArchitecture` itself (today they only reach the World
Graph, not the architecture model); (2) `CapabilityRegistry`'s
zero-production-callers finding (R14/R15, still unaddressed) deserves
independent architectural review; (3) the R13 `ExperienceHostScreen`
detail-cache characteristic, R10's "second generator," and R16's UI-toggle/
prompt-richness recommendations remain open.

**DO NOT START R18 — per this milestone's own stop condition, wait for
external architectural review.**

## R18 — Solution Execution Planner, Universal Execution Strategy

New `lib/execution_planning/` (`ExecutionStrategy`/`ExecutionTargetPlan`,
`SolutionExecutionPlanner`) — real, deterministic classification of
R18's 12 requested Execution Targets against `SemanticSolutionArchitecture`
(R17). REALITY: the R9-R13 compiler chain (`BuildGraphBuilder` ->
`GenerationPipeline` -> `RuntimeExperienceGenerator`) has zero production
callers anywhere in this codebase (confirmed by grep) — the live
creation path still runs entirely through `CreationEngine`'s original
V3-era blueprint conversion. Only 3 of 12 targets have real signal
(Runtime Experience, Backend Service, REST API); only Runtime Experience
has a real generator (`reference.runtime-experience`, R13). The other 9
are honestly, permanently `notApplicable`, each with a distinct, real
reason. A real bug was found and fixed via testing: `ApiSpecificationModel`
computes REST endpoints unconditionally from CRUD interaction flags,
independent of whether a backend is actually needed — REST API's real
applicability signal required both `endpoints.isNotEmpty` AND
`deployment.requiresBackend`, not endpoints alone.

Wired additively into `AnythingKernel.processIntent` (Step 8.6,
`ExecutionPlanReady.executionStrategy`) — zero risk, since it only
computes a plan, never invokes a generator. Deliberately did NOT wire
the compiler chain into the live creation path this milestone (two
structurally different `ExperiencePackage`-producing routes have never
been proven equivalent for a real request — that's real future-milestone
scope, not this one's). `lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/` completely untouched. World
Model/Engineering Memory deliberately not touched (cheap, deterministic,
recomputed from already-persisted data).

See `docs/architecture/SOLUTION_EXECUTION_PLANNING.md` for the full
audit.

**DO NOT START R19 — per this milestone's own stop condition, wait for
external architectural review.**

## Implementation Milestone R19 — Compiler Production Integration

REALITY (re-confirmed by grep before writing any code): the R9-R13
compiler chain still had zero production callers. Built a real
equivalence harness (`lib/compiler_integration/`) comparing legacy vs.
compiler `ExperiencePackage`s from the SAME real Kernel run across 11
real dimensions — for the "Field Log" fixture, compatibility score
9/11 (0.82), never a fabricated 100%; both pipelines independently
re-verified deterministic. Added ONE production feature flag,
`useCompilerPipeline` (default `false`), threaded through
`ExperienceCreationCoordinator` — every existing call site keeps
getting the legacy package byte-for-byte unchanged; when opted in, the
compiler package is served only if it passes the exact same
`ExperiencePackageValidator`, falling back to legacy otherwise. Proven
end-to-end: a real widget test drives a create action through the
compiler-selected package against real SQLite via the real,
unmodified `ExperienceHostScreen`/`BehaviorInterpreter`.
`lib/runtime/`, `lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/`, `lib/software_cognition/`,
`lib/world_model/`, `lib/storage/engineering_memory_repository.dart`,
and `lib/creation/creation_engine.dart` are all completely untouched.
Legacy was NOT removed or disabled — per the milestone's own mandate.

See `docs/architecture/COMPILER_PRODUCTION_INTEGRATION.md` for the full
audit, known differences, and migration strategy.

## Implementation Milestone R20 — Canonical Experience Enrichment (COMPLETE)

Traced R19's two documented gaps to their real root causes rather than
inventing new ones. Field richness: `SemanticField` already carries
`defaultValue`/`allowedValues`/`referenceEntityId`/`description`, the
SAME source legacy's `DataFieldSchema` already reads — but
`ImplementationField` (R9) dropped it. Threaded through via two new,
additive, optional `CanonicalImplementationContext` fields
(`semanticEntities`/`derivedValues`), sourced from the Kernel's
already-in-scope `reasonResult.semanticApp`, enriching
`ImplementationField` at the last mile rather than touching
`FieldDecision`/`DatabaseColumn` and their many other consumers. A real
bug was found and fixed during testing: `referenceEntityId` pointing to
an undeclared entity leaked through unchecked in an early version;
fixed by only keeping it when the target entity actually exists.
`minLength`/`maxLength`/`minimum`/`maximum` deliberately NOT enriched —
legacy itself never populates them either (verified by reading
`CreationEngine`).

Derived values: `SemanticDerivedValue` gets real `dataQuery`+
`calculation` behavior nodes in legacy — both already real,
already-handled `BehaviorInterpreter` node types. `CanonicalImplementationModel`
gained a real, deterministic `derivedValues` list; `RuntimeExperienceGenerator`
now emits the identical node/edge/state shape legacy already does.

View enrichment (dashboard/calendar/settings/summary) was investigated
and left honestly open — rendering these would require genuinely new
UI-generation semantics `RuntimeExperienceGenerator` has no vocabulary
for, which this milestone's "only solve verified differences" mandate
does not license inventing.

Measured, real before/after: R19's "Field Log" fixture scored 9/11
(0.82). A new `sharedFieldMetadataParity` `EquivalenceComparator`
dimension was added (separate from the count-based
`dataFieldCountParity`, which legitimately still differs because of the
compiler's real auto primary-key column) — the enriched "Field Log Rich"
fixture scores 10/12 (0.83). `dataFieldCountParity`/`screenCountParity`
remain real, open, structurally-explained differences.
`lib/runtime/`, `lib/software_cognition/`, `lib/build_graph/`, and
`lib/generation_specification/` are all untouched — no new semantic
node/mapping was genuinely required. `useCompilerPipeline` remains
opt-in, default `false` — this milestone's evidence does not support
flipping the default.

See `docs/architecture/COMPILER_PRODUCTION_INTEGRATION.md`, "R20 —
Canonical Experience Enrichment" for the full audit.

**DO NOT START R21 — per this milestone's own stop condition, wait for
external architectural review.**

## R21 — Canonical Experience Views, Non-CRUD Experience Generation

`CanonicalImplementationModel` gained `views: List<ImplementationView>`
(dashboard/calendar/settings/empty/summary — legacy's own real
`BlueprintViewType` names, kept distinct only because legacy picks a
distinct navigation icon per name; the field content
calendar/settings/empty/summary render is, and stays, identical, since
legacy's own `CreationEngine` treats all four as one shared switch-case
branch, verified by reading it). `RuntimeExperienceGenerator` now
builds a real `dashboardMetrics` screen (count/sum/average metrics,
matching legacy's exact derivation) and a real shared generic-fallback
screen (referenceSelector/input/switch per field, matching legacy's
exact shared behavior).

Measured, real: "Task Board" fixture (dashboard + settings views)
scores 10/12 (0.83), with the target `tasks_dashboard`/`tasks_settings`
screens no longer missing from the compiler side — the real, itemized
proof. Composite views (`SemanticView.sections`) remain honestly
unmodeled: `grep -n "\.sections\b" lib/creation/creation_engine.dart`
returns zero matches — legacy itself never reads that data, so there is
no real behavior to be equivalent with.
`lib/runtime/`/`lib/software_cognition/`/`lib/build_graph/`/
`lib/generation_specification/` all untouched. `useCompilerPipeline`
remains opt-in, default `false`.

See `docs/architecture/COMPILER_PRODUCTION_INTEGRATION.md`, "R21 —
Canonical Experience Views" for the full audit.

## R22 — Canonical Experience Identity

R21's own "Known differences" named the remaining gap plainly: CRUD
screen naming conventions differ between legacy and compiler. Reading
the actual conversion code (`lib/synthesis/synthesis_planner.dart`,
`lib/synthesis/model_reasoner.dart`) found this is an identity problem,
not a naming one: `BlueprintView.id` is free text the LLM writes
(`_normalizeId(view['id'] ?? view['name'])`), never a deterministic
`<entityId>_<role>` formula the way the compiler's own screen ids are.
`sourceEntityId`/`viewType` — real, already-structured fields sitting
next to that free-text `id` — are a screen's true identity, and both
pipelines already implicitly organize their screens around exactly
this pair.

New `lib/experience_identity/experience_identity.dart`: `ScreenIdentity`
(entity + role, mirroring `BlueprintViewType`'s real 8 values) and
`ActionIdentity` (entity + create/update/delete, the subset
`ImplementationOperationKind` can express). Legacy projection reads
only `sourceEntityId`/`viewType`, never `.id`. Compiler projection
mirrors `RuntimeExperienceGenerator`'s own screen-synthesis conditions
exactly. Behavior/Navigation Identity are not separate types — they
already reuse Action/Screen Identity structurally. Component/Artifact/
Route Identity are honestly unmodeled — no real dual-side signal exists
to project from.

`EquivalenceComparator.compare()` gained two additive, optional
parameters; when supplied, screen-presence comparison becomes a real
multiset comparison by `ScreenIdentity` instead of raw id strings.
Measured, real: on a fixture with a deliberately entity-unrelated
legacy view id, the `entries_list`-vs-`entry_list` class of mismatch no
longer appears in `missingComponents` once compared by identity — while
the compiler's genuine create/edit form split (legacy has no edit-mode
view type at all) correctly still appears in `extraComponents` as a
real, quantified, honest difference.

`lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/`, `lib/runtime/`,
`lib/software_cognition/`, `lib/world_model/`,
`lib/storage/engineering_memory_repository.dart`, and
`lib/creation/creation_engine.dart` all completely untouched.
`useCompilerPipeline` remains opt-in, default `false`.

See `docs/architecture/COMPILER_PRODUCTION_INTEGRATION.md`, "R22 —
Canonical Experience Identity" for the full audit.

**DO NOT START R23 — per this milestone's own stop condition, wait for
external architectural review.**

## R23 — Compiler Certification Framework, Automated Equivalence Certification

REUSE-and-AGGREGATE milestone over R19-R22's already-proven
`EquivalenceComparator`/`CompilerPipelineRunner`/Canonical Experience
Identity — all used completely unmodified. New
`lib/compiler_certification/` (3 files): a real 13-fixture corpus
(`crud`/`offline_first`/`dashboard`/`calendar`/`settings`/`summary`/
`multi_entity`/`relationships`/`permissions`/`capabilities`/
`navigation`/`backend_required`/`composite`), a runner that executes
both pipelines per fixture via the real, unmodified `AnythingKernel`/
`CreationEngine`/`runCompilerPipeline` and calls the real, unmodified
`EquivalenceComparator.compare()` with R22's identity-aware parameters,
a `CertificationReport` aggregator (every metric a documented
fraction/average over real per-fixture `EquivalenceReport`s, never
invented), and a real JSON-snapshot regression/trend mechanism (no new
Engineering Memory/World Model persistence).

Real, measured corpus result: `migrationReadinessScore` 0.681
(`structuralEquivalence` 0.769, `determinismRate` 1.0). A genuinely new,
corpus-scale finding: most fixtures under-declare `SemanticView`s
relative to their entities' unconditionally-full CRUD surface
(`BackendEngineeringPlan.api`, R18), so the compiler's always-full
list/form/detail screen set diverges from legacy's views-only screen
set on nearly every fixture — a fixture-corpus characteristic, not a
newly discovered pipeline defect.

`lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/`, `lib/runtime/`,
`lib/software_cognition/`, `lib/world_model/`,
`lib/storage/engineering_memory_repository.dart`, and
`lib/creation/creation_engine.dart` all completely untouched.
`useCompilerPipeline` remains opt-in, default `false`.

See `docs/architecture/COMPILER_PRODUCTION_INTEGRATION.md`, "R23 —
Compiler Certification Framework" for the full audit.

## IS-R24 — Engineering Intelligence Layer (COMPLETE)

Audited R24's 14 requested graph types against the codebase before
writing any code: 11 already existed under real names
(`RequirementGraph`/V2, `ArchitectureCandidate`+`BackendEngineeringPlan`
unified by `SemanticSolutionArchitecture`/R17, existing diff engines
`RequirementGraphDiffer`/`ArchitectureDiffer` from R3/R4). Workflow
Graph has no real, distinct signal and stays honestly unmodeled.

The one genuinely novel contribution: `lib/engineering_intelligence/`
(3 files) — a real `EngineeringIntelligence` facade, an
`AffectedEntityAnalyzer` translating R3/R4's existing diffs into real
affected entity ids, and an `IncrementalCompilerSynthesizer` that scopes
a full `CanonicalImplementationModel` to only the affected entities and
re-runs the EXISTING, UNMODIFIED `runCompilerPipeline` (R19) — reaching
diff-driven incremental regeneration into the compiler chain for the
first time. The resulting package flows into the EXISTING, UNMODIFIED
`EvolutionDiffPlan`/`applyEvolutionPlan()` hot-reload mechanism (R4-R7)
with zero code changes to that machinery, proven by a real test. A
narrow, real `RequirementGraphBridge` closes the "`RequirementGraph` is
never ingested into World Model" finding.

Real, measured incremental-vs-full compiler latency (200-entity model,
1 affected entity): ~22ms full, ~1ms incremental.

`lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/`, `lib/runtime/`,
`lib/software_cognition/`, and `lib/creation/creation_engine.dart` all
completely untouched. `useCompilerPipeline` remains opt-in, default
`false` — this specification never touches live creation.

See `docs/architecture/ENGINEERING_INTELLIGENCE.md` for the full audit
and the requested-vs-existing mapping table.

## IS-R25 — Universal Solution Orchestrator (COMPLETE)

`SolutionExecutionPlanner` (R18) already produces a real `ExecutionStrategy`
— target/dependencies/executionOrder/requiredGenerators/validationRequirements/
buildRequirements/deploymentRequirements — roughly 8 of R25's 9 requested
Orchestration Model fields, already real, already tested. It deliberately
never executes that strategy. Nothing in this codebase, before this
specification, ever walked `ExecutionStrategy.actionableTargets` and
actually ran a stage — that is the one, real, novel contribution R25
makes.

New `lib/solution_orchestration/` (3 files): `ExecutionTargetOrderer` (a
real Kahn's-algorithm-style level-partitioning scheduler over
`ExecutionTargetKind`/`ExecutionTargetPlan.dependencies`, mirroring
`BuildGraphOrderer`'s R11 honesty precedent), `StageOutcome`/
`OrchestrationReport` (real, structured per-stage completion criteria —
package produced AND compiler diagnostics clean AND
`ExperiencePackageValidator`-valid), and `SolutionExecutionOrchestrator`
(dispatches through the EXISTING, UNMODIFIED `runCompilerPipeline` (R19)/
`IncrementalCompilerSynthesizer` (R24), never embedding generator logic).

Of R18's 12 execution targets, only Runtime Experience ever reaches
`applicableWithGenerator` — real production strategies produce exactly
one actionable stage today. The level/parallel-partitioning algorithm is
proven correct on synthetic multi-target fixtures instead, stated
honestly rather than overclaiming real multi-generator parallelism.
`Future.wait`-based dispatch provides dependency-safe ordering, not
genuine CPU parallelism under Dart's single-isolate model for today's
synchronous generator primitives — named as a real, honest limitation.
Retry (bounded, default off) is real, tested infrastructure, honestly
documented as unlikely to change a deterministic pipeline's outcome.
Rollback reuses `ExperienceModificationCoordinator.rollback()` (R6)
unmodified, invoked by a caller (never the orchestrator itself, respecting
the established `lib/app/` → `lib/` layering direction) — proven
end-to-end.

World Model and Engineering Memory: no changes — both confirmed to have
no genuine new information to contribute beyond what R9/R17 already
provide.

`lib/generator_framework/`, `lib/build_graph/`,
`lib/generation_specification/`, `lib/runtime/`,
`lib/software_cognition/`, `lib/execution_planning/`, `lib/world_model/`,
`lib/storage/engineering_memory_repository.dart` all completely
untouched. `useCompilerPipeline` remains opt-in, default `false` — this
specification is not wired into live creation.

See `docs/architecture/SOLUTION_ORCHESTRATION.md` for the full audit.

**DO NOT START R26 — per this milestone's own stop condition, wait for
external architectural review.**

## Implementation Specification IS-R26 — Backend Service Generator, First Multi-Generator Production Target

R25's orchestrator could only ever dispatch ONE real generator
(`RuntimeExperienceGenerator`). R26 built the second:
`BackendServiceGenerator` (`lib/generator_framework/reference/`),
transforming the already-real `CanonicalImplementationModel` +
`BackendEngineeringPlan` into real, typed backend specification
artifacts — never SQL, never source code (Milestone R8's standing
constraint, still in force).

Four precise structural gaps were fixed: `runCompilerPipeline`'s
hardcoded `RuntimeExperienceGenerator` (generalized via a new,
backward-compatible `runGeneratorPipeline` primitive);
`SolutionExecutionPlanner._backendService()`'s hardcoded
`applicableNoGenerator` (flipped to `applicableWithGenerator` now that a
real generator exists); `StageOutcome.package`'s Runtime-Experience-only
shape (a new, additive `backendArtifacts` field); and
`GeneratorContext`'s lack of an extension point for
`BackendEngineeringPlan` (threaded through the existing, generic
`GeneratorOptions.values`, never a new required interface field).

Mandatory vision validation proven end-to-end: one real
`ExecutionStrategy` with BOTH `backendService` and `runtimeExperience` as
`applicableWithGenerator` runs through the real, unmodified
`SolutionExecutionOrchestrator`, both stages succeed, and real
dependency-safe ordering places Backend Service strictly before Runtime
Experience.

Two real, pre-existing test assertions (R18, R25) that specifically
tested the OLD "no generator exists yet" state were updated to reflect
the deliberate, milestone-mandated change — every other test passes
unmodified.

**Execution result:** 20 new tests pass. Full regression: **1464/1464**
(up from 1444). `flutter analyze`: 71 issues, 0 errors, unchanged
baseline. `lib/runtime/`, `lib/software_cognition/`, `lib/world_model/`,
`lib/storage/engineering_memory_repository.dart`,
`lib/engineering_intelligence/`, `lib/backend_engineering/`,
`lib/creation/creation_engine.dart`, `RuntimeExperienceGenerator` itself
all completely untouched. `useCompilerPipeline` unaffected, still
defaults `false`.

See `docs/architecture/BACKEND_SERVICE_GENERATOR.md` for the full audit.

**DO NOT START R27 — per this specification's own stop condition, wait
for external architectural review.**
