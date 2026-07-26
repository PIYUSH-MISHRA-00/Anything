---
name: Ambient Technical Intelligence
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#bec8d2'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#88929b'
  outline-variant: '#3e4850'
  surface-tint: '#89ceff'
  primary: '#89ceff'
  on-primary: '#00344d'
  primary-container: '#0ea5e9'
  on-primary-container: '#003751'
  inverse-primary: '#006591'
  secondary: '#c0c1ff'
  on-secondary: '#1000a9'
  secondary-container: '#3131c0'
  on-secondary-container: '#b0b2ff'
  tertiary: '#ffb86e'
  on-tertiary: '#492900'
  tertiary-container: '#de8712'
  on-tertiary-container: '#4d2b00'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c9e6ff'
  primary-fixed-dim: '#89ceff'
  on-primary-fixed: '#001e2f'
  on-primary-fixed-variant: '#004c6e'
  secondary-fixed: '#e1e0ff'
  secondary-fixed-dim: '#c0c1ff'
  on-secondary-fixed: '#07006c'
  on-secondary-fixed-variant: '#2f2ebe'
  tertiary-fixed: '#ffdcbd'
  tertiary-fixed-dim: '#ffb86e'
  on-tertiary-fixed: '#2c1600'
  on-tertiary-fixed-variant: '#693c00'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-lg:
    fontFamily: Public Sans
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-md:
    fontFamily: Public Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  code-xs:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
  label-caps:
    fontFamily: Public Sans
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin: 24px
  col-gap: 1px
---

## Brand & Style
The design system evolves the "Ambient Intelligence" philosophy into a high-fidelity workspace for technical validation. It targets engineers and data scientists who require a calm, "low-noise" environment to process complex regression data without cognitive fatigue.

The style is **Corporate / Modern** with a lean toward **Minimalism**. It prioritizes clarity through generous whitespace and a sophisticated "Obsidian & Glass" aesthetic. The emotional response is one of surgical precision and absolute reliability; the UI recedes to highlight the data, using subtle translucent layers to denote depth without cluttering the visual field.

## Colors
The palette is rooted in a deep `dark` mode to reduce eye strain during long validation sessions. 

- **Primary & Secondary:** A digital "Electric Blue" and "Indigo" for interactive states and primary focus areas.
- **Validation States:** High-contrast semantic colors are used. **Emerald (Success)** for passes, **Ruby (Error)** for failures, and **Amber (Warning)** for regressions. These colors must maintain a high luminosity to remain legible against the dark background.
- **Surfaces:** Use a tiered gray scale starting from `#0F172A` (Base) to `#1E293B` (Surface), ensuring high contrast for data rows.

## Typography
This design system utilizes a dual-font strategy:
1. **Public Sans:** Used for all interface chrome, navigation, and high-level summaries. It provides a human, approachable frame for the platform.
2. **JetBrains Mono:** The technical workhorse. Used for all logs, execution traces, JSON schemas, and multi-model output comparisons. 

**Technical Hierarchy:** 
- Use `code-sm` for standard log output. 
- Use `code-xs` for metadata, timestamps, and secondary technical attributes.
- Headlines should be kept clean and concise, avoiding decorative treatments.

## Layout & Spacing
The layout employs a **Fluid Grid** model optimized for side-by-side data comparison. 

- **Comparison Grids:** For multi-model validation, use a 1px "ghost gutter" (using border-strokes) to create a seamless pane-to-pane transition without wasting horizontal space.
- **Rhythm:** A 4px base unit ensures tight alignment for dense data tables.
- **Breakpoints:**
    - **Desktop (1440px+):** 12-column grid, max-width fluid.
    - **Tablet (768px - 1439px):** 8-column grid, collapsing sidebars into icons.
    - **Mobile:** Not recommended for validation; view-only mode with stacked summary cards.

## Elevation & Depth
Depth is conveyed through **Tonal Layers** and **Glassmorphism**.

- **Level 0 (Base):** Deepest background (#0F172A).
- **Level 1 (Panels):** Slightly lifted surface (#1E293B) with a 1px subtle stroke.
- **Level 2 (Overlays/Modals):** Glassmorphic surfaces with a 12px backdrop-blur and 40% opacity fill of the surface color.
- **Shadows:** Use extremely soft, tinted shadows (Primary Color at 10% opacity) for active elements to give a "glow" effect rather than a traditional physical shadow.

## Shapes
Following the "Ambient Intelligence" heritage, the system uses **Pill-shaped (3)** roundedness for buttons, chips, and status indicators. However, large data containers and code blocks should use `rounded-lg` (2rem) to maintain structural integrity while still feeling soft and approachable.

## Components
- **Buttons:** Primary buttons are pill-shaped with a subtle inner glow. Secondary buttons are ghost-style with a thin border.
- **Validation Chips:** High-contrast pills. "Pass" uses an emerald background with white text; "Fail" uses ruby. Include a 2px "pulse" animation for active test runs.
- **Data Grids:** Rows should alternate with subtle tonal shifts. Highlight active rows with a primary-colored left-border accent (4px width).
- **Log Viewer:** Monospaced text on a true-black background. Timestamps are dimmed to 50% opacity.
- **Comparison Panes:** Split-screen views with a synchronized scroll lock for comparing regression outputs across different model versions.
- **Motion Cues:**
    - **Running state:** A subtle, horizontal "scanning" light effect across the top of the test card.
    - **Validation Pulse:** When a test passes, the emerald chip should emit a single, low-opacity expansion ring.