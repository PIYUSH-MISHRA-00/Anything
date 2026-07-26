# kernel/

Intent parsing, planning, and orchestration: the brain of the system.

## What belongs here

- Intent parser: turning raw input into structured intents
- Planner: decomposing intents into execution plans
- Orchestrator: coordinating capabilities and runtime
- Context engine: maintaining conversational/situational context
- Reasoning engine: logical inference and decision-making

## What does NOT belong here

- UI code (use `features/`, `app/`)
- Concrete capability implementations (use `capabilities/`)
- Event bus (use `runtime/`)
- Storage (use `storage/`)

## Key interfaces

- `Kernel` (from `core/contracts/`)
- `IntentParser`
- `Planner`
- `Orchestrator`
- `ContextEngine`
- `ReasoningEngine`
