# features/developer/

Developer mode interfaces: debugging, inspection, and developer tools.

## What belongs here

- Developer tools screen
- Debug panels and inspectors
- Performance monitoring UI
- Kernel/runtime state inspection

## What does NOT belong here

- Core debugging logic (use `core/`)
- Runtime internals (use `runtime/`)
- Kernel internals (use `kernel/`)

## Key interfaces

- `DeveloperToolsScreen`
- `DebugPanel`
- `StateInspector`
