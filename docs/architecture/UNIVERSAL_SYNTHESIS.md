# Universal Synthesis Architecture

## Overview

Stage 10 transforms Anything from a Calculator-specific creation system into a general-purpose app synthesis engine. The architecture proves that a single pipeline can generate fundamentally different application structures from natural-language intent.

## Architecture Diagram

```
User Intent ("Make me a notes app")
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
    │                         └─ ambiguities
    ▼
SynthesisPlanner ──→ SynthesisResult
    │                 ├─ AppBlueprint
    │                 ├─ patterns applied
    │                 └─ synthesis notes
    ▼
AppBlueprint (technology-independent)
    │  ├─ archetypes [collection, tracker, planner, dashboard, ...]
    │  ├─ entities [BlueprintEntity with fields]
    │  ├─ views [BlueprintView with sections]
    │  ├─ actions [BlueprintAction]
    │  ├─ derivedValues [BlueprintDerivedValue]
    │  └─ offlinePolicy / networkConfig
    ▼
BlueprintValidator ──→ BlueprintValidation
    │                   ├─ isValid
    │                   ├─ errors
    │                   └─ warnings
    ▼
GenericPackageBuilder ──→ ExperiencePackage
    │                      ├─ InterfaceDefinition (screens + navigation)
    │                      ├─ BehaviorGraph (events + mutations + calculations)
    │                      ├─ StateSchema (form inputs + derived values)
    │                      ├─ DataSchema (entities + fields)
    │                      └─ integrity hash
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

High-level structural classification:
- `utility` — no persistence, no network (Calculator)
- `collection` — manages records (Notes, Reading List)
- `tracker` — periodic/daily state (Habit Tracker)
- `planner` — tasks with dates/status (Study Planner)
- `dashboard` — summary-first with aggregation (Expense Tracker)
- `reference` — external information (Weather)
- `workflow` — multi-step process
- `hybrid` — combines archetypes

### AppBlueprint (lib/synthesis/app_blueprint.dart)

Technology-independent semantic description of a synthesized application. Describes WHAT the app is, not HOW it's implemented.

Key structures:
- `BlueprintEntity` — semantic entities (Note, Habit, Expense)
- `BlueprintField` — typed fields with constraints
- `BlueprintView` — views with purpose and sections
- `BlueprintAction` — user actions (create, update, delete, toggle)
- `BlueprintDerivedValue` — computed values (sum, count, streak)
- `BlueprintNetworkConfig` — network requirements

### BlueprintValidator (lib/synthesis/blueprint_validator.dart)

Validates blueprints before synthesis:
- Structural integrity (IDs, names, references)
- Security limits (max entities, fields, views)
- Reference consistency (entity references exist)
- Network/offline policy consistency

### SynthesisPatterns (lib/synthesis/synthesis_patterns.dart)

Reusable building blocks for app synthesis:
- `CollectionPattern` — Notes, Reading List
- `TrackerPattern` — Habit Tracker
- `PlannerPattern` — Study Planner
- `DashboardPattern` — Expense Tracker

Patterns define default entities, views, actions, and derived values for each archetype.

### SynthesisPlanner (lib/synthesis/synthesis_planner.dart)

Converts IntentUnderstanding into AppBlueprint:
1. Detects primary archetype from objective
2. Selects appropriate synthesis patterns
3. Applies patterns to build structure
4. Customizes from understanding details
5. Returns complete AppBlueprint

### GenericPackageBuilder (lib/synthesis/generic_package_builder.dart)

Converts AppBlueprint into ExperiencePackage:
- Builds InterfaceDefinition from views
- Builds BehaviorGraph from actions + derived values
- Builds StateSchema from form fields
- Builds DataSchema from entities
- Computes integrity hash

### BlueprintToSpecConverter (lib/synthesis/blueprint_to_spec.dart)

Converts AppBlueprint into ExperienceSpec for the existing CreationEngine pipeline.

## Data Flow

### Creation Flow
1. User provides natural language intent
2. IntentClassifier categorizes (create/modify/open)
3. ModelUnderstandingService produces IntentUnderstanding
4. SynthesisPlanner detects archetype and applies patterns
5. AppBlueprint is produced
6. BlueprintValidator validates the blueprint
7. GenericPackageBuilder creates ExperiencePackage
8. Package is validated and persisted
9. BirthSequence plays
10. AnythingRuntime opens the experience

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

## No AI Required

For deterministic golden archetypes (Notes, Habits, Expenses, Study, Reading):
- Creation works without ModelProvider
- Creation works without KnowledgeProvider
- All synthesis is deterministic
- Tests verify offline creation

AI-assisted creation is optional for novel/ambiguous requests.
