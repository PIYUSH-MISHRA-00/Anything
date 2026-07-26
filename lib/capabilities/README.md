# capabilities/

Composable abilities available to the kernel and runtime.

## What belongs here

- Individual capability implementations (web search, file ops, code gen, etc.)
- Capability registry and discovery
- Capability configuration and permissions
- Capability result types

## What does NOT belong here

- Kernel orchestration logic (use `kernel/`)
- Runtime execution engine (use `runtime/`)
- UI for capabilities (use `features/`)

## Key interfaces

- `Capability` (from `core/contracts/`)
- `CapabilityRegistry`
- `CapabilityResult`
- `CapabilityConfig`
