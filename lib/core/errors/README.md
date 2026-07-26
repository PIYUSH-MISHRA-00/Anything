# core/errors/

Error types, error boundaries, and structured error handling.

## What belongs here

- Custom error class hierarchy
- Error code enums and error metadata types
- Error boundary interfaces
- Platform-agnostic error wrapping

## What does NOT belong here

- Error handling logic in business code (use appropriate layer)
- UI error display (use `features/` or `design_system/`)
- Result/Either types (use `core/result/`)

## Key interfaces

- `AppError` — base error type
- `ErrorCode` — error code enum
- `ErrorBoundary` — error capture interface
- `ErrorHandler` — centralized error processing
