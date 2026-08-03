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

## v2.0.0 Release Candidate

**Objective:** All of M1-M6 acceptance gates met; `flutter analyze` clean; full `flutter test` suite passes (not just the subsets exercised in this audit); `flutter build apk --debug` succeeds and release build succeeds where a signing environment is available; no UNKNOWN rows remain in `V2_VISION_GAP_MATRIX.md` for anything in v2.0.0 scope; `docs/progress/V2_STAGE_11.md` and other stage docs reflect actual, dated, execution-verified state; CI is green on the release branch.

**Acceptance gate:** this document's own checklist, re-run and all green, immediately before tagging.
