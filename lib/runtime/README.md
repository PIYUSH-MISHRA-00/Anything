# runtime/

Execution engine: running plans, managing the event bus, and coordinating capabilities.

## What belongs here

- Plan execution engine
- Event bus implementation
- Execution context and state management
- Capability invocation and lifecycle

## What does NOT belong here

- Intent parsing or planning (use `kernel/`)
- Capability implementations (use `capabilities/`)
- UI code (use `features/`)

## Key interfaces

- `Runtime` (from `core/contracts/`)
- `EventBus` (from `core/contracts/`)
- `ExecutionEngine`
- `PlanExecutor`
