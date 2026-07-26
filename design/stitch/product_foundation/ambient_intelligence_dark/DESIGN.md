---
name: Ambient Intelligence Dark
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
  on-surface-variant: '#c6c5d5'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#908f9e'
  outline-variant: '#454653'
  surface-tint: '#bdc2ff'
  primary: '#bdc2ff'
  on-primary: '#131e8c'
  primary-container: '#818cf8'
  on-primary-container: '#101b8a'
  inverse-primary: '#4953bc'
  secondary: '#bac5f0'
  on-secondary: '#242f52'
  secondary-container: '#3a456a'
  on-secondary-container: '#a9b4de'
  tertiary: '#c3c0ff'
  on-tertiary: '#272377'
  tertiary-container: '#8e8ce4'
  on-tertiary-container: '#242075'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e0e0ff'
  primary-fixed-dim: '#bdc2ff'
  on-primary-fixed: '#000767'
  on-primary-fixed-variant: '#2f3aa3'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#bac5f0'
  on-secondary-fixed: '#0d1a3c'
  on-secondary-fixed-variant: '#3a456a'
  tertiary-fixed: '#e2dfff'
  tertiary-fixed-dim: '#c3c0ff'
  on-tertiary-fixed: '#100563'
  on-tertiary-fixed-variant: '#3e3c8f'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 56px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.01em
  title-md:
    fontFamily: Manrope
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 48px
  xl: 80px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 64px
---

## Brand & Style

This design system is defined by a sense of calm, premium intelligence. It utilizes a **Minimalist-Material** hybrid style that emphasizes negative space, subtle motion, and high-quality typography to reduce cognitive load. The personality is professional yet approachable—acting as a quiet, capable assistant that stays in the background until needed.

The aesthetic leans into the "Ambient" narrative through soft transitions and depth created via tonal layering rather than aggressive borders. It is designed for high-focus environments where clarity and visual comfort are paramount.

## Colors

The palette is anchored in a deep indigo-charcoal base to ensure a premium dark-mode experience. 
- **Primary:** A soft, luminous lavender-blue (#818CF8) used for interactive states and key emphasis.
- **Secondary:** A muted pale indigo (#C7D2FE) for less prominent actions and accents.
- **Background:** The foundation is a rich, near-black indigo (#0F172A).
- **Surface:** Tiers of charcoal-slate (#1E293B) provide logical containment and elevation.
- **Typography:** Primary text uses an off-white (#F8FAFC) to reduce eye strain while maintaining accessibility. Secondary text should utilize a 70% opacity of the off-white.

## Typography

This design system uses a triple-font strategy to balance character with utility:
- **Manrope (Headlines):** Modern and refined, used for all primary headings to establish a premium feel.
- **Inter (Body):** Highly systematic and legible, ensuring that long-form content is easy to digest in dark mode.
- **Geist (Labels/Mono):** Used for micro-copy, status labels, and technical data to provide a precise, developer-friendly edge.

Scale large display text down by approximately 25-30% for mobile viewports to maintain vertical rhythm.

## Layout & Spacing

The layout follows a **fluid grid** logic with 12 columns for desktop and 4 columns for mobile. 
- **Spacing Rhythm:** Based on an 8px linear scale. 
- **Margins:** Desktop views should maintain generous 64px side margins to enforce the "Minimalist" feel. Mobile uses 16px margins to maximize screen real estate.
- **Consistency:** Use the `md` (24px) spacing unit for standard vertical padding between sections and `sm` (12px) for internal component spacing.

## Elevation & Depth

In this dark-themed environment, depth is communicated through **Tonal Layers** rather than heavy shadows.
1. **Level 0 (Base):** #0F172A - The foundation.
2. **Level 1 (Surface):** #1E293B - Used for cards and main containers.
3. **Level 2 (Overlay):** #334155 - Used for modals, menus, and floating elements.

**Shadows:** When necessary for floating components, use an "Ambient Shadow"—a deep indigo-tinted shadow (Hex #000000 at 40% opacity) with a large blur radius (32px) and no offset. This creates a soft glow effect rather than a harsh drop-shadow.

## Shapes

The shape language follows a **Rounded** philosophy, heavily inspired by Material 3. 
- Standard buttons and input fields use a `0.5rem` (8px) radius.
- Large containers and cards use `1rem` (16px) to appear friendly and soft.
- Elements should never be sharp; even the smallest decorative elements should carry a minimum 2px radius.

## Components

- **Buttons:** Primary buttons use the Primary Color (#818CF8) with dark text (#0F172A). Secondary buttons are outlined with a 1px stroke of the surface-border color and off-white text.
- **Input Fields:** Use a subtle dark fill (#1E293B) with a bottom-only border or full 1px border that glows slightly (low-opacity Primary color) when focused.
- **Chips:** Highly rounded (pill-shaped) with a background color only 2-4% lighter than the surface it sits on.
- **Cards:** No borders. Use the Level 1 Surface color to differentiate from the background. 
- **Lists:** Separators should be high-transparency whites (10% opacity) to remain almost invisible, maintaining a clean flow.
- **Selection Controls:** Checkboxes and Radios utilize the Primary color for the "checked" state, appearing as a soft glowing beacon in the dark UI.