# core/config/

App-wide configuration types and environment settings.

## What belongs here

- App configuration model (features flags, environment, build info)
- Configuration provider interface
- Default values and configuration loading
- Environment-specific configuration

## What does NOT belong here

- Feature-specific config (use `features/`)
- Theme/design config (use `design_system/theme/`)
- Platform-specific config (use `platform/`)

## Key interfaces

- `AppConfig` — main configuration model
- `ConfigProvider` — configuration loading interface
- `Environment` — runtime environment enum
