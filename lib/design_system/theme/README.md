# design_system/theme/

ThemeData configuration and design system theme integration.

## What belongs here

- ThemeData builders and customization
- Light/dark theme definitions
- Text theme configuration
- Component theme overrides
- Theme extension types

## What does NOT belong here

- Raw design tokens (use `design_system/tokens/`)
- Widget implementations (use `design_system/components/`)
- App shell or routing (use `app/`)

## Key interfaces

- `AppTheme` — ThemeData factory
- `ThemeExtension<T>` — custom theme extensions
- `ThemeMode` — light/dark/system configuration
