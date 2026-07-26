# Stitch Implementation Map

Maps implemented Flutter screens and components to their Stitch design references.

## Screens

| Flutter Screen | Stitch Reference | Status |
|---------------|-----------------|--------|
| `HomeScreen` | `anything_home/`, `anything_home_dark_mode/` | Implemented |
| `ExperiencesScreen` | `anything_my_apps_library/` | Shell implemented |
| `ActivityScreen` | `anything_activity_timeline/` | Shell implemented |
| `PreferencesScreen` | `anything_preferences/` | Shell implemented |
| `AnythingAppShell` | Navigation pattern from multiple screens | Implemented |

## Components

| Flutter Component | Stitch Pattern | Notes |
|------------------|---------------|-------|
| `AnythingIntentField` | `anything_universal_intent_surface/` | Visual shell only, no Kernel |
| `AnythingButton` | Buttons across all screens | Pill-shaped, indigo |
| `AnythingCard` | Cards in Home, My Apps | Ambient shadow |
| `AnythingChip` | Chips in Home suggestions | Pill-shaped |
| `AnythingTextField` | Input fields | Large, minimal |
| `AnythingEmptyState` | Empty states | Intentional, teaches next step |
| `AnythingListTile` | Settings items | Standard list pattern |
| `AnythingSectionHeader` | Section labels | Uppercase, tracking |

## Navigation

| Element | Stitch Pattern | Implementation |
|---------|---------------|----------------|
| Bottom Nav | Floating pill nav | `AnythingAppShell._buildFloatingNav()` |
| Top Bar | Sticky with blur | `HomeScreen` header |
| Tab Icons | Material Symbols | Home, Auto Awesome, Notifications, Tune |

## Design Tokens

| Token Category | Stitch Source | File |
|---------------|--------------|------|
| Colors (Light) | `ambient_intelligence_1/DESIGN.md` | `tokens/colors.dart` |
| Colors (Dark) | `ambient_intelligence_dark/DESIGN.md` | `tokens/colors.dart` |
| Typography | Both DESIGN.md files | `tokens/typography.dart` |
| Spacing | Both DESIGN.md files | `tokens/spacing.dart` |
| Radii | Both DESIGN.md files | `tokens/radii.dart` |
| Shadows | Stitch visual analysis | `tokens/shadows.dart` |
| Motion | Stitch animation patterns | `tokens/motion.dart` |
| Layout | Stitch responsive patterns | `tokens/layout.dart` |
