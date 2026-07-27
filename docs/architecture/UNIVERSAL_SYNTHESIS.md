# Universal Synthesis Architecture

## Overview

Stage 10/10.1/10.2 transforms Anything from a Calculator-specific creation system into a general-purpose app synthesis engine. The architecture proves that a single pipeline can generate fundamentally different application structures from natural-language intent, with no domain-specific hardcoding.

**Stage 10.1 key change:** All domain-specific logic has been removed from the synthesis engine. Domain knowledge now lives in the `ApplicationReasoner` (deterministic or model-backed), not in templates or pattern code.

**Stage 10.2 key change:** The Kernel/Coordinator boundary is fixed so the universal synthesis pipeline reaches production. `CompositeApplicationReasoner` orchestrates deterministic-first reasoning with model fallback. Model validation is strict (unknowns rejected). The full creation lifecycle — Intent → Kernel → Coordinator → Engine → Package → Persistence — is proven end-to-end.

**Stage 10.3 key change:** Knowledge refinement loop added to Kernel. Reasoner now takes `ApplicationReasoningContext` carrying knowledge bundle, round count, and available capabilities. Deterministic reasoner tightened to collection-only patterns. Legacy `_buildFallbackPlan()` removed. Metadata category derived from archetypes. Blueprint tags flow to manifest. Prompt injection defense added to model reasoner.

**Stage 10.4 key change:** Knowledge accumulation defect fixed — loop now merges into `accumulated` variable preserving all rounds' knowledge. Required/optional separation: optional failures no longer escape as `ReasoningKnowledgeRequired`. Total knowledge budget enforced at orchestration boundary (50 resources, 16K chars, 20 requirements, 20 warnings). `KnowledgeBundle.mergedWith()` provides cross-round deduplication and merge semantics. Unused import removed from GenericPackageBuilder.

## Architecture Diagram

```
User Intent ("Make me a plant care tracker")
    │
    ▼
IntentClassifier ──→ IntentCategory (create/modify/open)
    │
    ▼
ModelUnderstandingService ──→ IntentUnderstanding
    │                         ├─ objective
    │                         ├─ category
    │                         ├─ confidence
    │                         ├─ networkNeed
    │                         └─ creationNeed
    ▼
ApplicationReasoner ──→ SemanticApp (or ProviderRequired)
    │                   ├─ entities [SemanticEntity]
    │                   ├─ views [SemanticView]
    │                   ├─ actions [SemanticAction]
    │                   ├─ derivedValues [SemanticDerivedValue]
    │                   ├─ tags ['plant_care', 'tracker']
    │                   └─ archetypes [tracker]
    ▼
SynthesisPlanner ──→ AppBlueprint
    │                 ├─ builds from SemanticApp
    │                 ├─ derives archetypes from structure
    │                 └─ applies structural patterns
    ▼
AppBlueprint (technology-independent)
    │  ├─ archetypes [collection, tracker, planner, dashboard, ...]
    │  ├─ entities [BlueprintEntity with fields]
    │  ├─ views [BlueprintView with sections]
    │  ├─ actions [BlueprintAction]
    │  ├─ derivedValues [BlueprintDerivedValue]
    │  ├─ tags ['plant_care', 'tracker'] (open-world)
    │  └─ offlinePolicy / networkConfig
    ▼
BlueprintValidator ──→ BlueprintValidation
    │                   ├─ isValid
    │                   ├─ errors
    │                   └─ warnings
    ▼
BlueprintToSpecConverter ──→ ExperienceSpec
    │                        ├─ derives category from archetypes
    │                        ├─ converts to CreationEngine format
    │                        └─ applies capability requirements
    ▼
CreationEngine ──→ ExperiencePackage
    │              ├─ InterfaceDefinition (screens + navigation)
    │              ├─ BehaviorGraph (events + mutations + calculations)
    │              ├─ StateSchema (form inputs + derived values)
    │              ├─ DataSchema (entities + fields)
    │              └─ integrity hash
    ▼
AnythingRuntime ──→ ExperienceSession
    │                ├─ StateEngine (reactive state)
    │                ├─ DataRuntime (SQLite CRUD)
    │                ├─ BehaviorInterpreter (trusted execution)
    │                └─ ExperienceRenderer (Flutter widgets)
    ▼
Running Application
```

## Core Components

### AppArchetype (lib/synthesis/app_archetype.dart)

High-level structural classification (enum, no domain knowledge):
- `utility` — no persistence, no network (Calculator)
- `collection` — manages records (e.g. Notes, Reading List)
- `tracker` — periodic/daily state (e.g. Habit Tracker)
- `planner` — tasks with dates/status (e.g. Study Planner)
- `dashboard` — summary-first with aggregation (e.g. Expense Tracker)
- `reference` — external information (e.g. Weather)
- `workflow` — multi-step process
- `hybrid` — combines archetypes

**Stage 10.1:** `AppDomain` enum was removed. Domain tags are now open-world `List<String>` on `AppBlueprint`.

### ApplicationReasoner (lib/synthesis/application_reasoner.dart)

**Stage 10.1 (NEW):** Typed contract for semantic reasoning from natural language.
**Stage 10.3:** Evolved to take `ApplicationReasoningContext` instead of raw `IntentUnderstanding`.

Returns one of:
- `ReasoningReady` — complete `SemanticApp` ready for synthesis
- `ReasoningProviderRequired` — model needed for complex/novel intent
- `ReasoningKnowledgeRequired` — external knowledge needed before reasoning
- `ReasoningUnsupported` — domain cannot be synthesized
- `ReasoningFailed` — unparseable intent

`ApplicationReasoningContext` carries:
- `understanding` — intent understanding from classification
- `knowledge` — acquired `KnowledgeBundle?` (null on first round)
- `availableCapabilities` — capability IDs available to the app
- `round` — current refinement round (0-based)
- `maxRounds` — maximum allowed refinement rounds

`SemanticApp` contains:
- `entities` — typed entities with fields, actions, computed values
- `views` — screens with sections
- `tags` — open-world domain tags (e.g. `['plant_care', 'tracker']`)
- `archetypes` — structural archetypes derived from semantic structure

### CompositeApplicationReasoner (lib/synthesis/composite_reasoner.dart)

**Stage 10.2 (NEW):** Orchestrates reasoning strategy selection for production use.

Strategy chain:
1. `DeterministicReasoner` — tried first (free, instant)
2. `ModelApplicationReasoner` — fallback when deterministic returns `ProviderRequired`
3. `ReasoningProviderRequired` — returned if no provider is configured

Error messages are redacted: consumers see "Unable to create this type of app. Please try rephrasing." instead of raw exceptions.

### DeterministicReasoner (lib/synthesis/deterministic_reasoner.dart)

**Stage 10.1 (NEW):** No-AI fallback for simple structural requests.
**Stage 10.3 tightening:** Only handles collection patterns ("list of X", "collection of X"). All tracker, planner, dashboard, habit, expense patterns now escalate to model reasoning.

Returns `ReasoningProviderRequired` for all non-collection requests. Returns `null` (no match) if entity extraction fails or input is too generic — no fallback defaults.

### ModelApplicationReasoner (lib/synthesis/model_reasoner.dart)

**Stage 10.1 (NEW):** ModelProvider-backed reasoning for complex intents.
**Stage 10.2:** Strict validation — unknown field types, action types, operations, view types, and section types are **rejected** with errors (no silent coercion to defaults). JSON extraction tries direct parse → fenced code block → regex. Error messages are redacted for consumers.
**Stage 10.3:** Accepts `ApplicationReasoningContext`. Injects acquired knowledge into prompt with clear untrusted delimiter. Knowledge truncated to 4000 chars. Prompt injection patterns stripped (ignore previous instructions, execute this javascript, reveal secret, run this shell, you are now, forget all instructions, system:). Knowledge needs parsed from model response.

- Sends structured prompt with strict JSON schema
- Parses model output into `SemanticApp` with validation
- BYOK via existing `ModelProviderRegistry`
- Privacy-minimal context (objective + category only)

### AppBlueprint (lib/synthesis/app_blueprint.dart)

Technology-independent semantic description of a synthesized application. Describes WHAT the app is, not HOW it's implemented.

Key structures:
- `BlueprintEntity` — semantic entities (e.g. Plant, Loan, Product)
- `BlueprintField` — typed fields with constraints
- `BlueprintView` — views with purpose and sections
- `BlueprintAction` — user actions (create, update, delete, toggle)
- `BlueprintDerivedValue` — computed values (sum, count, streak)
- `BlueprintNetworkConfig` — network requirements
- `tags: List<String>` — open-world domain tags

### BlueprintValidator (lib/synthesis/blueprint_validator.dart)

Validates blueprints before synthesis:
- Structural integrity (IDs, names, references)
- Security limits (max entities, fields, views)
- Reference consistency (entity references exist)
- Network/offline policy consistency

### SynthesisPatterns (lib/synthesis/synthesis_patterns.dart)

**Stage 10.1:** Simplified to structural-only. Patterns accept pre-built entities/views/actions and apply structural wiring (navigation, state bindings, event hooks). No domain knowledge.

- `CollectionPattern` — list-based storage structure
- `TrackerPattern` — periodic tracking structure
- `PlannerPattern` — task scheduling structure
- `DashboardPattern` — summary aggregation structure

### SynthesisPlanner (lib/synthesis/synthesis_planner.dart)

**Stage 10.1:** Delegates semantic reasoning to `ApplicationReasoner`, then converts `SemanticApp` to `AppBlueprint`.

1. Calls `ApplicationReasoner.reason(intent)`
2. Receives `SemanticApp` with entities, views, actions, tags
3. Converts to `AppBlueprint` with structural patterns
4. Derives archetypes from semantic structure (not domain keywords)
5. Returns complete `AppBlueprint`

### BlueprintToSpecConverter (lib/synthesis/blueprint_to_spec.dart)

**Stage 10.1:** Category derived from archetypes and structure, not domain strings.

Converts `AppBlueprint` into `ExperienceSpec` for the existing CreationEngine pipeline.

### GenericPackageBuilder (lib/synthesis/generic_package_builder.dart)

Converts AppBlueprint into ExperiencePackage:
- Builds InterfaceDefinition from views
- Builds BehaviorGraph from actions + derived values
- Builds StateSchema from form fields
- Builds DataSchema from entities
- Computes integrity hash

**Audit confirmed:** No domain branches — all entity/view/action handling is generic.

## Data Flow

### Creation Flow
1. User provides natural language intent
2. IntentClassifier categorizes (create/modify/open)
3. ModelUnderstandingService produces IntentUnderstanding
4. AnythingKernel.processIntent() invokes CompositeApplicationReasoner
5. CompositeApplicationReasoner tries DeterministicReasoner, then ModelApplicationReasoner
6. Returns SemanticApp with entities, views, actions, tags
7. SynthesisPlanner converts to AppBlueprint
8. BlueprintValidator validates the blueprint
9. BlueprintToSpecConverter converts to ExperienceSpec
10. Kernel returns ExecutionPlanReady with plan + spec
11. ExperienceCreationCoordinator consumes ExecutionPlanReady
12. CreationEngine produces ExperiencePackage
13. Package is validated and persisted
14. Activity is recorded
15. BirthSequence plays
16. AnythingRuntime opens the experience

### Modification Flow
1. User requests change ("Add tags to notes")
2. Existing ExperiencePackage is loaded
3. ModificationEngine applies typed operations
4. Updated package is validated and persisted
5. Data is preserved through migration

### Opening Flow
1. User taps app in My Apps
2. ExperienceOpeningCoordinator loads package
3. Protection check (Kaalka if protected)
4. Integrity verification
5. AnythingRuntime opens experience

## Derived Values

Computed values that update when data changes:
- `count` — count of records
- `sum` — sum of a numeric field
- `average` — average of a numeric field
- `min` / `max` — minimum/maximum of a field
- `consecutiveDateCount` — streak calculation
- `daysRemaining` — countdown
- `percentage` — percentage calculation

Implemented via behavior graph nodes:
1. `dataQuery` fetches all records
2. `calculation` computes aggregate
3. Result stored in state variable

## Multi-Screen Navigation

Generated apps support multiple screens:
- List/dashboard root view
- Form/detail secondary view
- Bottom navigation between views

Navigation is declarative (NavigationDefinition) and owned by Runtime.

## Security

- No arbitrary code execution
- All behavior nodes are allowlisted types
- Execution budget (100 nodes per execution)
- Blueprint limits enforced
- Capabilities declared and checked
- Experience isolation maintained
- Kaalka protection works across all archetypes

## Open-World Domain Model

**Stage 10.1:** Domain knowledge is no longer hardcoded.

- `AppBlueprint.tags` — open-world list of domain strings
- Unknown domains require no source-code change
- Domain knowledge lives in `ApplicationReasoner`
- Patterns and planners are domain-agnostic

## No AI Required

For deterministic structural intents (collection, tracker, planner, dashboard):
- `CompositeApplicationReasoner` tries `DeterministicReasoner` first
- All synthesis is deterministic for these patterns
- Tests verify offline creation
- Zero model invocations confirmed

AI-assisted creation is used for complex/novel intents that require domain reasoning. The `CompositeApplicationReasoner` falls back to `ModelApplicationReasoner` automatically.
