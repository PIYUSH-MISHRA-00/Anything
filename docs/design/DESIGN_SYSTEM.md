# Anything Design System

## Overview

The Anything design system implements the "Ambient Intelligence" visual language defined in the Stitch design exports. It creates a calm, premium, minimal experience that feels alive but restrained.

## Tokens

### Colors

Two complete palettes: Light and Dark, extracted from Stitch's `ambient_intelligence` DESIGN.md files.

- **Light**: Warm off-white surfaces (#FCF9F8), deep indigo primary (#11278A), charcoal text (#1C1B1B)
- **Dark**: Deep indigo-charcoal surfaces (#0B1326), luminous lavender primary (#BDC2FF), off-white text (#DAE2FD)

Files: `lib/design_system/tokens/colors.dart`

### Typography

- **Light**: Public Sans (headlines) + Inter (body/labels)
- **Dark**: Manrope (headlines) + Inter (body) + Geist (labels)

Google Fonts integration via `google_fonts` package. Font licensing is open (SIL OFL).

File: `lib/design_system/tokens/typography.dart`

### Spacing

8px base unit. Key values: 16px (compact), 24px (regular), 32px (wide), 64px (section).

File: `lib/design_system/tokens/spacing.dart`

### Radii

- Light: generous (16px default, up to 48px)
- Dark: compact (8px default, up to 24px)
- Pill shapes for buttons and chips (9999px)

File: `lib/design_system/tokens/radii.dart`

### Shadows

- Ambient: indigo-tinted (15% opacity) soft shadows
- Glow: enhanced ambient with blur
- Nav: bottom navigation bar shadow

File: `lib/design_system/tokens/shadows.dart`

### Motion

- Fast: 100ms (micro-interactions)
- Standard: 200ms (buttons, cards)
- Emphasized: 350ms (page transitions)
- Slow: 500ms (entrance/exit)
- Creation: 2500ms (reserved for Experience birth)

File: `lib/design_system/tokens/motion.dart`

### Layout

- Breakpoints: compact (<600), medium (600-1200), expanded (>1200)
- Content width: 600px max for text, 1440px max for layout
- Min touch target: 48dp

File: `lib/design_system/tokens/layout.dart`

## Theme

System/Light/Dark mode with immediate switching. Persisted locally via SharedPreferences.

File: `lib/design_system/theme/anything_theme.dart`, `theme_provider.dart`

## Components

| Component | File | Description |
|-----------|------|-------------|
| AnythingButton | `components/anything_button.dart` | Pill-shaped primary button |
| AnythingGhostButton | `components/anything_button.dart` | Outlined secondary button |
| AnythingCard | `components/anything_card.dart` | Standard card with ambient shadow |
| AnythingGlassCard | `components/anything_card.dart` | Glassmorphism floating card |
| AnythingTextField | `components/anything_text_field.dart` | Large minimal input |
| AnythingIntentField | `components/anything_intent_field.dart` | Universal Intent Surface shell |
| AnythingChip | `components/anything_chip.dart` | Pill-shaped tag/filter |
| AnythingSectionHeader | `components/anything_section_header.dart` | Section label with optional action |
| AnythingEmptyState | `components/anything_empty_state.dart` | Intentional empty state |
| AnythingListTile | `components/anything_list_tile.dart` | Settings/navigation list item |

## Responsive Behavior

- Phone: single column, 16px margins
- Tablet: adapted layout, 24px margins
- Desktop: max-width 1440px centered, 32px+ margins

## Accessibility

- Semantic labels on all interactive elements
- Minimum 48dp touch targets
- Text scaling support
- High contrast in both themes
- Focus states visible
- Screen reader semantics

## Stitch Mapping

| Design System | Stitch Reference |
|---------------|-----------------|
| Colors | `ambient_intelligence_1/DESIGN.md`, `ambient_intelligence_dark/DESIGN.md` |
| Typography | Same DESIGN.md files |
| Spacing | Same DESIGN.md files |
| Home Screen | `anything_home/`, `anything_home_dark_mode/` |
| Intent Field | `anything_universal_intent_surface/` |
| My Apps | `anything_my_apps_library/` |
| Activity | `anything_activity_timeline/` |
| Preferences | `anything_preferences/` |
