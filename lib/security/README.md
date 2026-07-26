# security/

Kaalka protection boundary: security, permissions, and access control.

## What belongs here

- Kaalka boundary implementation
- Permission checking and access control
- Security policy enforcement
- Safe execution wrappers
- Input sanitization

## What does NOT belong here

- Core security interfaces (use `core/contracts/`)
- Kernel security decisions (use `kernel/`)
- UI security indicators (use `features/`)

## Key interfaces

- `SecurityBoundary` (from `core/contracts/`)
- `KaalkaBoundary`
- `PermissionChecker`
- `SafeExecutionWrapper`
