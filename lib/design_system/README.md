# design_system/

Flutter design system: tokens, reusable components, and theme configuration.

## What belongs here

- Design tokens (colors, typography, spacing, radii, shadows)
- Reusable Flutter widgets that follow the design system
- ThemeData configuration and customization
- Design system documentation and usage guidelines

## What does NOT belong here

- Feature-specific screens (use `features/`)
- Business logic (use `core/`, `features/`)
- App shell or routing (use `app/`)

## Key interfaces

- `DesignTokens` — token collection
- `AppTheme` — ThemeData builder
- `ComponentLibrary` — component catalog
