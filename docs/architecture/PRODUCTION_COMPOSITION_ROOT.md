# Production Composition Root — Implementation Milestone R1

## Overview

R1 is the first real-code milestone after the four MIS-1 audit/design
documents. It builds nothing new architecturally — it wires together
subsystems MIS-1 Part 1/2 already confirmed exist, are tested, and were
simply unreached from production: `WorldModelCoordinator`,
`CapabilityPlatform`, `CredentialVault`, and `SoftwareCognitionCoordinator`.
No canonical subsystem was redesigned or replaced.

## The composition root: `AppComposition`

`lib/app/app_composition.dart` — a new, small, plain (non-widget) class,
constructed exactly once by `AnythingAppShell` and threaded via
constructor injection to `HomeScreen`/`ExperiencesScreen`/
`ExperienceHostScreen`, following this codebase's existing "optional
injectable dependency" convention (never a DI framework — matches Rule 8,
"no hidden magic").

**REALITY before R1** (MIS-1 Part 2, "Composition Roots" /
"Reachability Analysis"): `HomeScreen.initState` independently
constructed an `AnythingKernel` with no `WorldModelCoordinator`
reference at all; `ExperienceModificationCoordinator` independently
constructed its own default `WorldModelCoordinator()` — two disconnected
graphs, neither persisted, neither shared with any other subsystem.

**PROPOSED / now REALITY**: `AppComposition.production()` builds one
`WorldModelCoordinator` (backed by `WorldModelRepository`, so it also now
persists — MIS-1 Part 2's "World Update" node was previously unreachable
in production), one `CapabilityPlatform` with every builtin capability
registered, one `CredentialVault`, one `AnythingProviderRegistry`, one
`AnythingKernel`, one `SoftwareCognitionCoordinator`, one
`RuntimeIntelligenceCoordinator` — and hands the same instances to every
screen/coordinator that needs them.

## What changed, subsystem by subsystem

### WorldModelCoordinator sharing

- `AnythingKernel` gained an optional `WorldModelCoordinator? worldModel`
  constructor parameter (default `null` — every pre-R1 caller/test is
  unaffected). When present, `processIntent` now calls
  `ingestReviewSession(...)` right after Design Review approves (Step
  7.5) and `ingestEvolutionRoadmap(..., blueprint: ...)` right after
  Evolution Planning produces a roadmap (Step 7.7) — both wrapped in a
  best-effort `_ingestIntoWorldModelSafely` helper that swallows any
  ingestion failure so a World Graph bookkeeping error can never fail
  `processIntent` itself (Rule 7: nothing may reduce determinism of the
  generation contract).
- `ExperienceCreationCoordinator` gained optional
  `WorldModelCoordinator?`/`SoftwareCognitionCoordinator?` parameters.
  After a successful creation, it calls `ingestExperience(metadata,
  package)` and `persist()` — closing one of the four `ingest*` methods
  MIS-1 Part 2 found had zero call sites anywhere.
- `ExperienceModificationCoordinator`'s existing `worldModel` parameter
  (added in V10 for `precheckModification()`) is now, for the first
  time, given the SAME shared instance instead of its own default —
  `test/app/r1_composition_root_test.dart` proves this directly: a
  creation via one coordinator is visible to a DIFFERENT coordinator's
  real `precheckModification()` call, against the SAME graph.
- `ingestKnowledge` is now wired (Implementation Milestone R2). Investigation
  found the conversion this limitation described as "not cleanly scoped"
  already existed in full: `KnowledgeGraphBuilder.build(KnowledgeBundle)`
  (`lib/software_architect/knowledge_graph.dart`) was already a real,
  general builder — not a test-only fixture helper — and Kernel Step 5.5
  already called it to feed Feature Discovery's optional `knowledge:`
  parameter. R2 reused that SAME, already-computed `KnowledgeGraph`
  value and passed it to `_ingestIntoWorldModelSafely(() =>
  _worldModel?.ingestKnowledge(knowledgeGraph))` immediately afterward —
  no new builder, no new call to acquire anything twice. See
  `docs/architecture/KNOWLEDGE_ENGINE.md`'s "World Graph ingestion
  (Implementation Milestone R2)" section for the full account, including
  a real bug found and fixed in `KnowledgeGraphBridge`'s identity
  computation (it previously used the acquisition-timestamp-based
  `KnowledgeResource.id`, which made every re-fetch of the same URL
  mint a brand-new World Graph node instead of deduplicating).

### Capability Platform wiring

`ExperienceServiceResolver` gained an optional `CapabilityPlatform?`
constructor parameter. `execute()`'s dispatch now routes
`httpClient`/`notifications`/`fileAccess`/`knowledgeRetrieval`/
`aiInference` through `CapabilityPlatform.invoke()` when a platform is
wired (mapped via a small `_serviceTypeToCapabilityId` table); `clock` is
untouched (still its own hardcoded, always-real path); `localDatabase`
remains stubbed — no registered Capability Platform capability answers
it, and inventing one would be new architecture, out of R1's "wire what
exists" scope.

Real backing services, added as thin adapters
(`lib/capabilities/adapters/`), each wrapping an ALREADY-canonical
system rather than inventing a new one:

- `RealHttpTransport` — wraps `package:http` (already a dependency, used
  by `GroqModelProvider`).
- `ModelProviderAiAdapter` — wraps the existing BYOK
  `ModelProviderRegistry`, reading `.activeProvider` at call time.
- `KnowledgeAcquisitionProviderAdapter` — wraps the existing
  `KnowledgeAcquisitionEngine`.

**Honest limitation**: `NotificationCapability`/`FileCapability` are
registered with their `Fake*` backing services in production — no real
OS notification delivery (`flutter_local_notifications` is not a
dependency) or file-picker-backed `FileService` exists yet. Building
either is real feature work, not "wiring," and is explicitly out of R1's
scope; registering the Fakes keeps the dispatch path structurally real
and testable without claiming a capability that doesn't exist.

### BYOK credential storage

`GroqModelProvider` now takes a `CredentialVault` (was a raw
`FlutterSecureStorage`); `AnythingProviderRegistry` now takes a
`CredentialVault` and threads it to every provider it constructs. This
closes MIS-1 Part 2/3's "BYOK Assessment" finding — credential storage no
longer bypasses the purpose-built vault. **Migration note**: the stored
key changes from the raw `GROQ_API_KEY` to the vault's namespaced
`credential_groq_api_key`. This repository has never been tagged/released
(`pubspec.yaml` still carries Flutter's template `1.0.0+1`, confirmed by
MIS-1 Part 1), so no production credential exists to migrate; a real
release would need a one-time migration, out of scope here.

### Software Cognition creation-pipeline hook

`AnythingKernel.processIntent` gained an optional `List<KnowledgeResource>
seedKnowledge` parameter, used to seed the knowledge refinement loop's
initial bundle (empty by default — zero behavior change when omitted).
`ExperienceCreationCoordinator.createFromIntent`/`createFromExpression`
gained an optional `referenceUrl` parameter: when supplied (and a
`SoftwareCognitionCoordinator` was injected), it acquires real repository
understanding, converts a sound result to a `KnowledgeResource` via the
existing `toKnowledgeResource()`, and seeds it into reasoning — reusing
the exact, already-safe "acquired knowledge" pathway (never a second
prompt-injection surface), per the design MIS-1 Part 3's own "Part D"
already recommended (composition-root opt-in, not a Kernel-stage
redesign). **No UI entry point was added** — exposing a "build like X"
text field is separate, larger product-surface work, out of R1's scope
(R1 wires the pipeline; a future milestone can wire the UI).

## Dependency impact

One new edge: Kernel → World Model (`AnythingKernel` now optionally
depends on `WorldModelCoordinator`). MIS-1 Part 1's dependency summary
did not previously show this edge — it is the expected, sanctioned
result of this milestone, not a violation of the dependency constitution
(`Anything_MIS1_Part4_Canonical_Dependency_Rules.txt`). No circular
import was introduced (verified: `lib/world_model/` imports nothing from
`lib/kernel/`; `lib/security/credential_vault.dart` imports nothing from
`lib/legacy/`).

## Testing

`test/app/r1_composition_root_test.dart` — 9 tests: shared
`WorldModelCoordinator` reachability (Kernel-injected and
Creation/Modification-shared, both proven via real graph state, not
object identity alone), Kernel backward-compatibility when no World
Model is injected, `CredentialVault` routing (verified through a real
`flutter_secure_storage` platform-channel mock — not a hand-duplicated
stand-in), `CapabilityPlatform` dispatch (wired and un-wired paths, plus
the honest `localDatabase` non-mapping), and both the positive and
negative Software Cognition creation-pipeline hook cases.

## Known limitations

- `ingestKnowledge` was wired in Implementation Milestone R2 — see
  `docs/architecture/KNOWLEDGE_ENGINE.md`. (This limitation is now
  closed; kept here, struck through in spirit, for the historical
  record of what R1 shipped.)
- `NotificationCapability`/`FileCapability` have no real production
  backing service (Fakes only) — building either is new capability
  implementation, not wiring, and needs a product decision first (does
  this need `flutter_local_notifications`? does file adoption need real
  per-Experience storage?).
- `AiCapability`'s `experienceId` constructor parameter is accepted but
  unused by `execute()` today — a single shared `AiCapability` instance
  is registered once at composition-root time; if `experienceId` is ever
  used for real per-Experience scoping in a future milestone, this
  registration will need to move to per-`openExperience` time.
- No UI entry point exists yet for the Software Cognition `referenceUrl`
  hook — the pipeline is wired, the product surface is not.
- `RuntimeIntelligenceCoordinator`/`ObservationEngine.attachSession()`
  remain unreached from `ExperienceHostScreen` — out of R1's explicit
  scope (R1 named World Model/Capability Platform/BYOK/Software
  Cognition wiring specifically; Runtime Intelligence auto-attachment is
  a separate, still-open MIS-1 finding).
