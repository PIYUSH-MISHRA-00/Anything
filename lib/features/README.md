# features/

Feature modules: screen-level code organized by user-facing capability.

## What belongs here

- Screen widgets and page-level UI
- Feature-specific state management
- Feature-specific business logic coordination
- Feature routing and navigation

## What does NOT belong here

- Shared/reusable widgets (use `design_system/components/`)
- Core abstractions (use `core/`)
- Platform-specific code (use `platform/`)

## Key interfaces

- Each feature folder should have its own internal structure
- Feature entry points and public API surfaces
