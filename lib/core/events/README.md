# core/events/

Typed event system for decoupled communication between layers.

## What belongs here

- Base event types and event dispatcher interface
- Typed event definitions (e.g., `IntentCaptured`, `ExperienceUpdated`)
- Event subscription and emission utilities
- Event middleware / interceptor patterns

## What does NOT belong here

- Concrete event handling logic (use `runtime/` or `features/`)
- UI event handlers (use `features/`)
- Platform events (use `platform/`)

## Key interfaces

- `Event` — base event type
- `EventBus` — publish/subscribe bus
- `EventHandler<T>` — typed handler
- `EventMiddleware` — interception pattern
