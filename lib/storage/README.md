# storage/

Repository boundaries for persistence: databases, caches, and file storage.

## What belongs here

- Repository implementations (experiences, settings, sessions)
- Database schemas and migrations
- Cache implementations
- File storage abstractions
- Serialization/deserialization

## What does NOT belong here

- Core repository interfaces (use `core/contracts/`)
- Feature-specific data models (use `features/`)
- Knowledge providers (use `knowledge/`)

## Key interfaces

- `Repository` (from `core/contracts/`)
- `ExperienceRepository`
- `SettingsRepository`
- `SessionRepository`
- `CacheProvider`
