# Backend Engineering — Implementation Milestone R8

## Overview

Extends the deterministic engineering pipeline from frontend-only
Experience engineering (`lib/application_engineering/`, Vision
Milestone V3) into full-stack specification: Database Schema, API
Specification, Authentication, Storage, Background Jobs, and Deployment
— all as **real, typed data structures**, never generated SQL, never
generated backend source code, never a deployment config file, never
executed or provisioned. This milestone produces specifications an
implementation-generation milestone could later consume — it does not
itself generate implementation code.

## Investigation finding

`lib/application_engineering/` was confirmed, by direct source read, to
be entirely frontend/Experience-shaped (Behavior/Data/Navigation/
Interaction/Binding/Validation/Persistence/Offline/Synchronization/
Lifecycle/Accessibility/Performance/Security Engineering) — no backend,
API, schema, authentication, or deployment concept existed anywhere
upstream. This is genuinely new capability work, not a rediscovery of
existing infrastructure (unlike R2-R7's own "reuse before build"
findings) — sanctioned explicitly by this milestone's own "if not
existing, create only the minimum canonical abstractions required."

## Module map (`lib/backend_engineering/`)

| Module | Real behavior |
|---|---|
| `database_schema.dart` | `DatabaseSchemaModel`/`DatabaseTable`/`DatabaseColumn`/`ForeignKeyConstraint` — real depth: every `SemanticEntity`/`SemanticField` becomes a real table/column, `BlueprintFieldType` mapped to a small, storage-agnostic `DatabaseColumnType`, real foreign keys from fields with `referenceEntityId`, real delete policy from `RelationshipDecision.deletePolicy`. |
| `api_specification.dart` | `ApiSpecificationModel`/`ApiEndpoint` — real depth: every entity's real `InteractionDecision` (canCreate/canRead/canUpdate/canDelete/supportsSearch, already computed by Architecture Planning, Vision Milestone V2) becomes real, matching REST-shaped endpoints — never a fabricated default when no interaction decision exists. |
| `authentication_model.dart` | `AuthenticationModel` — deliberately minimal: `requiresCredentials` mirrors the real, existing `SecurityDecision.requiresCredentialVault`. No identity-provider/session/role model is built, because no real upstream signal for "does this app need end-user login" exists anywhere in `ArchitectureCandidate` today — fabricating one would violate this milestone's own "never invent data" rule. |
| `storage_model.dart` | `BackendStorageModel` — real, direct restatement of each entity's already-decided `StorageKind` (Vision Milestone V2), never a re-decision. |
| `background_jobs_model.dart` | `BackgroundJobsModel` — real, single-field derivation: `requiresBackgroundSync` from `SynchronizationDecision.strategy` (`cacheFirst`/`networkFirst` = true). No scheduler/queue/retry-policy concept exists upstream to derive richer data from. |
| `deployment_specification.dart` | `DeploymentSpecificationModel` — real: `requiresBackend` from `OfflineDecision`/`SecurityDecision`; `secretReferences` are NAME-ONLY (`SecretReference`, never a value), emitted only when credentials are genuinely required. |
| `backend_engineering_context.dart` | Mirrors `EngineeringContext`'s exact shape — the same already-computed `ArchitectureCandidate`/`SemanticApp`, zero new upstream dependency. |
| `backend_engineering_planner.dart` | `BackendEngineeringPlanner` — the orchestrator, one deterministic derivation method per sub-model, mirroring `EngineeringPlanner`'s own assembly shape. |
| `backend_engineering_serialization.dart` | Hand-written `toJson()`/`fromJson()`, same convention as `architecture_candidate_serialization.dart` (R5). |

## Honest depth statement

Database Schema and API Specification are genuinely complete-feeling —
the source data (`SemanticField`'s real type/required/reference
information, `InteractionDecision`'s real CRUD flags) supports real
depth. Authentication/Storage/Background-Jobs/Deployment are
deliberately minimal: every field is real and derived, but the spec's
own long wishlists (indexes, migrations, seed data, rate limits,
realtime, identity providers, sessions, roles, policies, schedulers,
workers, queues, retry policies, scaling, networking, monitoring,
health checks) are **not modeled**, because no real upstream signal
exists to derive them from without inventing data. This is a named,
deliberate scope boundary — not an oversight.

## AI boundary

Zero new LLM calls. `BackendEngineeringPlanner.plan()` consumes only
the same, already-computed `ArchitectureCandidate`/`SemanticApp` that
`EngineeringContext` (V3) already receives — proven directly by a real
determinism test (the same Kernel run, twice, produces byte-for-byte
identical backend plans).

## Kernel integration

`AnythingKernel.processIntent` gains one new step (7.8, between Evolution
Planning and `ExperienceSpec` conversion) — additive, deterministic,
World-Model-ingested via the existing `_ingestIntoWorldModelSafely`
defensive contract (a failure here can never fail generation).
`ExecutionPlanReady` gained one additive `backendEngineeringPlan` field,
matching R5's `requirementGraph` field precedent exactly.

## Engineering Memory integration

`EngineeringMemoryRepository` (R5) gained a `backend_engineering_json`
column via a real, additive `ALTER TABLE` migration (catching the
"duplicate column" failure as the idempotency signal — sqflite has no
`ADD COLUMN IF NOT EXISTS`). **Critical backward-compatibility
decision**: the row's `integrity_hash` formula was deliberately left
UNCHANGED (still 3 fields, not 4) — extending it to cover the new
column would have retroactively invalidated every R5-era row's already-
computed hash, causing `load()` to treat genuinely valid historical
engineering memory as "tampered" and silently discard it. A dedicated
test proves an R5-shaped row still loads correctly post-R8.

## World Model integration

A 7th value was added to `WorldNodeKind`: `backendEndpoint`. Database
tables deliberately do NOT get a new kind — they unify with the
EXISTING `entity` kind (a backend table and its frontend entity are the
same real-world concept, viewed from a different engineering angle),
proven directly by a real identity-unification test. `BackendGraphBridge`
follows the exact same pure-translation pattern as the other 6 Bridges.

## Security

No privilege-escalation path: the authentication/authorization model is
non-executable specification data. `SecretReference` is name-only by
construction — the type has no field capable of holding a value.
Capability isolation and the existing trust boundary are unchanged;
this milestone adds no new dispatch path.

## Known limitations

- Authentication/Storage/Background-Jobs/Deployment models are real but
  intentionally minimal (see "Honest depth statement" above).
- No SQL, backend source code, or deployment config is ever generated —
  by design, not as a limitation to fix later at this milestone's own
  scope, but a genuine, larger future milestone would be required to go
  from specification to real generated implementation.
- `EngineeringMemoryRepository`'s per-row integrity hash does not cover
  the new `backend_engineering_json` column (a deliberate backward-
  compatibility trade-off, not an oversight — malformed backend JSON is
  still caught by the existing try/catch and degrades gracefully).
