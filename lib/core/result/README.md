# core/result/

Result/Either monad for expressive, type-safe error handling without exceptions.

## What belongs here

- `Result<T>` — success/failure wrapper
- `Either<L, R>` — two-value type
- Extension methods for map, flatMap, fold, etc.
- Conversion utilities between Result and exceptions

## What does NOT belong here

- Error type definitions (use `core/errors/`)
- Business logic that uses results (use appropriate layer)
- UI code that displays errors (use `features/`)

## Key interfaces

- `Result<T>` — primary result type
- `Either<L, R>` — generic two-type union
- `ResultExtensions` — functional combinators
