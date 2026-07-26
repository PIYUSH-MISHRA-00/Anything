# core/contracts/

Abstract interfaces, type definitions, and contract boundaries for the entire app.

## What belongs here

- Abstract base classes and interfaces (`IKernel`, `IRuntime`, `ICapability`, etc.)
- Type aliases and generic type definitions
- Protocol/boundary definitions between layers

## What does NOT belong here

- Concrete implementations (use the appropriate layer directory)
- Business logic (use `core/`, `features/`)
- UI code (use `design_system/`, `features/`)

## Key interfaces

- `Kernel` — intent parsing and orchestration contract
- `Runtime` — execution engine contract
- `Capability` — composable ability contract
- `KnowledgeProvider` — knowledge boundary contract
- `SecurityBoundary` — Kaalka protection contract
- `Repository` — storage boundary contract
- `EventBus` — event system contract
