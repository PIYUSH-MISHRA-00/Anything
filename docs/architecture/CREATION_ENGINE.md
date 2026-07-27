# Creation Engine Architecture

## Overview

The Creation Engine converts ExperienceSpec + ExecutionPlan + AppBlueprint into an ExperiencePackage. It does NOT execute arbitrary code.

## Pipeline

```
CreationContext (intent, specification, plan, blueprint)
  → Interface Generator (from blueprint views)
  → Behavior Generator (from blueprint actions)
  → State Generator (from blueprint entity fields)
  → Data Generator (from blueprint entities)
  → Manifest Builder (category from blueprint archetypes, tags from blueprint tags)
  → Service Mapper
  → Capability Mapper
  → Package Builder
  → Validator
  → ExperiencePackage
```

## CreationContext

Contains everything needed:
- Intent
- ExperienceSpec (trusted requirements)
- ExecutionPlan
- AppBlueprint (optional, carries rich semantic data)
- Available capabilities
- Platform context
- Security policy

## Blueprint-Based Generators

When `CreationContext.blueprint` is provided:

- **Interface:** `InterfaceDefinition` built from `blueprint.views` — each view becomes a screen
- **Behavior:** `BehaviorGraph` built from `blueprint.actions` — each action becomes a node
- **State:** `StateSchema` built from blueprint entity fields — text fields, booleans, etc. become state variables
- **Data:** `DataSchema` built from `blueprint.entities` — entities and their fields preserved
- **Manifest:** Category derived from first `blueprint.archetype.name`, tags from `blueprint.tags`

When `blueprint` is null, falls back to ExperienceSpec-based flat generation.

## CreationResult

Typed outcomes:
- CreationReady
- CreationNeedsClarification
- CreationNeedsCredential
- CreationFailed
- CreationUnsupported

## Security

- Only trusted behavior node types allowed
- Capability allowlist enforced
- No arbitrary eval
- No downloaded code execution
- Resource limits enforced
