# design_system/components/

Reusable Flutter widgets that consume design tokens and follow the design system.

## What belongs here

- Atomic widgets (buttons, cards, inputs, badges, etc.)
- Composite widgets (nav bars, toolbars, panels)
- Layout primitives (spacers, dividers, containers)
- Widget variants and theming support

## What does NOT belong here

- Feature-specific screens or complex layouts (use `features/`)
- Raw design tokens (use `design_system/tokens/`)
- ThemeData setup (use `design_system/theme/`)

## Key interfaces

- `AppButton`
- `AppCard`
- `AppInput`
- `AppBadge`
- `AppNavigationBar`
