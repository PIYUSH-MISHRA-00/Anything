# legacy/

Preserved legacy code during migration: code that has not yet been refactored.

## What belongs here

- Original code preserved during v2 migration
- Deprecated but still functional modules
- Transitional adapters between old and new architecture

## What does NOT belong here

- New v2 code (use the appropriate v2 directory)
- Code that has been fully migrated
- Code that is no longer used (delete it)

## Key interfaces

- No new interfaces should be defined here
- Legacy interfaces should be adapted to v2 contracts
