# Anything Runtime Architecture

## Overview

The Anything Runtime executes validated ExperiencePackages as controlled running sessions. It interprets trusted declarative structures — it does NOT execute arbitrary code.

## Pipeline

```
ExperiencePackage
→ Package Validation
→ Compatibility Check
→ Session Creation
→ State Initialization
→ Data Runtime Init
→ Service Resolution
→ Capability Resolution
→ Interface Rendering
→ Behavior Execution
→ User Interaction
→ State/Data Updates
→ Session Lifecycle
```

## Core Components

### AnythingRuntime
Central orchestrator for Experience execution.

### ExperienceRenderer
Converts declarative InterfaceDefinition to Flutter widgets. Only trusted component types supported.

### BehaviorInterpreter
Executes BehaviorGraph nodes. No arbitrary eval. Bounded execution.

### ExperienceStateEngine
Manages typed state with reactivity. Session-scoped isolation.

### ExperienceDataRuntime
Manages local data for Experiences. Controlled CRUD operations.

### ExperienceServiceResolver
Maps service definitions to trusted Runtime services.

## Security

- Package validation before execution
- Trusted component types only
- No arbitrary eval
- No dynamic widget import
- Capability allowlist enforced
- Experience-level network/permission mediation
- No arbitrary downloaded code execution
