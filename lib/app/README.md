# app/

App shell: routing, theme wiring, dependency injection, and top-level configuration.

## What belongs here

- App entry point and MaterialApp configuration
- Route definitions and navigation setup
- Theme and design system wiring
- Dependency injection / service locator setup
- Global app-level state providers

## What does NOT belong here

- Feature-specific screens or widgets (use `features/`)
- Business logic or domain models (use `core/`, `features/`)
- Platform-specific code (use `platform/`)

## Key interfaces

- `AppConfig` (from `core/config/`)
- `ThemeConfig` (from `design_system/theme/`)
- `RouteProvider`
- `ServiceLocator`
