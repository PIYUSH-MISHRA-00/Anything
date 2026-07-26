# features/workspace/

Workspace view and management: active work context and session management.

## What belongs here

- Workspace screen and layout
- Active task/context display
- Workspace switching UI
- Session state management

## What does NOT belong here

- Kernel orchestration (use `kernel/`)
- Runtime execution (use `runtime/`)
- Activity timeline (use `features/activity/`)

## Key interfaces

- `WorkspaceScreen`
- `WorkspacePanel`
- `WorkspaceSwitcher`
