# platform/

Platform-specific code: native integrations, platform channels, and OS-specific behavior.

## What belongs here

- Platform channel implementations
- Native plugin integrations
- OS-specific UI adaptations
- Platform detection and configuration

## What does NOT belong here

- Core platform interfaces (use `core/contracts/`)
- Platform-agnostic business logic (use `core/`, `features/`)
- Design system (use `design_system/`)

## Key interfaces

- `PlatformAdapter`
- `PlatformChannel`
- `NativePlugin`
