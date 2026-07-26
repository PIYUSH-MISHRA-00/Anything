---
name: Ambient Intelligence System
colors:
  surface: '#f7f9fb'
  surface-dim: '#d8dadc'
  surface-bright: '#f7f9fb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f4f6'
  surface-container: '#eceef0'
  surface-container-high: '#e6e8ea'
  surface-container-highest: '#e0e3e5'
  on-surface: '#191c1e'
  on-surface-variant: '#454652'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#757683'
  outline-variant: '#c5c5d4'
  surface-tint: '#4456b6'
  primary: '#11278a'
  on-primary: '#ffffff'
  primary-container: '#2e41a1'
  on-primary-container: '#aab6ff'
  inverse-primary: '#bac3ff'
  secondary: '#4953bc'
  on-secondary: '#ffffff'
  secondary-container: '#8792fe'
  on-secondary-container: '#17228f'
  tertiary: '#160bae'
  on-tertiary: '#ffffff'
  tertiary-container: '#3333c2'
  on-tertiary-container: '#b3b4ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dee0ff'
  primary-fixed-dim: '#bac3ff'
  on-primary-fixed: '#00105a'
  on-primary-fixed-variant: '#2a3d9d'
  secondary-fixed: '#e0e0ff'
  secondary-fixed-dim: '#bdc2ff'
  on-secondary-fixed: '#000767'
  on-secondary-fixed-variant: '#2f3aa3'
  tertiary-fixed: '#e1e0ff'
  tertiary-fixed-dim: '#c0c1ff'
  on-tertiary-fixed: '#07006c'
  on-tertiary-fixed-variant: '#2f2ebe'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-lg:
    fontFamily: manrope
    fontSize: 57px
    fontWeight: '700'
    lineHeight: 64px
    letterSpacing: -0.25px
  headline-lg:
    fontFamily: manrope
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
  headline-lg-mobile:
    fontFamily: manrope
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
  title-lg:
    fontFamily: manrope
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: publicSans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: 0.5px
  body-md:
    fontFamily: publicSans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.25px
  label-lg:
    fontFamily: publicSans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.1px
  label-sm:
    fontFamily: publicSans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.5px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  3xl: 64px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is rooted in the philosophy of **Ambient Intelligence**. The interface is designed to disappear, acting as a quiet, capable companion rather than a demanding tool. It balances the structured logic of Material Design 3 with an organic, handcrafted soul.

The aesthetic is **Modern Minimalist with Tonal Depth**, emphasizing:
- **Simple & Elegant:** Reducing visual noise to highlight intent.
- **Comfortable & Premium:** Utilizing generous negative space and high-end typography to reduce cognitive load.
- **Alive:** The UI feels biological through "breathing" motion and reactive surfaces that respond to user presence.
- **Atmospheric:** Using light and soft tonal shifts rather than hard lines to define boundaries.

## Colors

The palette is anchored by a deep, calm Indigo-Violet foundation that suggests reliability and depth. 

- **Primary:** Represents the core action and "intelligence" of the system.
- **Surface Strategy:** Following Material 3 logic, surfaces use tonal palettes. Light mode utilizes soft off-whites and cool greys to maintain a premium "paper-like" feel. Dark mode uses deep navy-greys with subtle indigo tints to prevent pure black fatigue.
- **Semantic Success:** Success states avoid aggressive greens. Instead, they use a subtle emerald glow and soft ripples to signify completion.
- **Interactive States:** Use MD3-inspired tonal overlays (Hover: 8%, Focus: 12%, Pressed: 12%).

## Typography

This design system uses a dual-font strategy to balance character with utility. 

- **Manrope** is used for headlines and titles to provide a modern, geometric, yet friendly personality. 
- **Public Sans** is utilized for body text and labels to ensure maximum legibility and a grounded, institutional reliability. 

**Hierarchy Rules:**
- Heading levels must maintain generous line spacing (1.2x to 1.5x) to support the "Ambient" feeling.
- Large Display sizes should use tighter letter spacing for a more editorial, premium look.
- Body text uses standard tracking to ensure accessibility across all device types.

## Layout & Spacing

The system is built on a strict **8dp grid** to maintain mathematical harmony while allowing for 4dp increments for fine-tuned micro-adjustments.

- **Grid Model:** A 12-column fluid grid for desktop and a 4-column grid for mobile.
- **Margins:** Desktop views favor a "fixed-max-width" approach (1280px) centered in the viewport, creating a stable, calm canvas. 
- **Spacing Philosophy:** When in doubt, increase padding. The "Ambient" aesthetic relies on white space to suggest "breathing room."
- **Breakpoints:**
  - Compact (Mobile): < 600dp
  - Medium (Tablet): 600dp - 840dp
  - Expanded (Desktop): > 840dp

## Elevation & Depth

This design system utilizes **Tonal Layering** over heavy drop shadows. Depth is communicated through surface color shifts (Material 3 Surface Tints) rather than traditional skeuomorphism.

- **Level 0 (Basal):** The main background surface.
- **Level 1 (Cards):** Subtle separation using a +1% primary color tint or a very soft 4px blur shadow (alpha 0.05).
- **Level 2 (Dialogs/Sheets):** Higher contrast separation with a 12px blur shadow, indicating a temporary focal point.
- **The "Lift" Effect:** Interactive elements like cards should "lift" (increase elevation and shadow spread) on hover to acknowledge user focus.

## Shapes

The shape language is organic and soft, avoiding sharp corners to maintain a friendly, approachable atmosphere.

- **Small Components (Chips, Inputs):** 12dp radius.
- **Buttons:** 16dp radius for a distinct, tactile feel.
- **Containers & Cards:** 24dp radius to create a soft, friendly structure.
- **Overlays (Dialogs/Sheets):** 28dp to 32dp, mimicking a handheld "slab" feel.
- **Intent Surface:** 32dp radius, creating a "pill-like" floating appearance for the core interaction hub.

## Components

### Intent Surface
The center of the experience. A floating, breathing rounded rectangle (32dp radius) that houses input, voice activation, and attachments. It should use a subtle pulse animation when idle.

### Cards
The fundamental building block. 24dp radius, subtle border (1px, low-opacity), and no heavy shadows. On hover, they scale slightly (1.02x) and increase tonal depth.

### Buttons
Fully rounded (16dp to pill-shaped). Use Material You ripples. The Primary button is the only element allowed to have a vibrant indigo fill; secondary buttons use tonal fills or outlines.

### Navigation
A persistent 5-destination bottom bar (mobile) or side rail (desktop) that "morphs." When a destination is selected, the icon is enclosed in a pill-shaped "active" container.

### Motion & Transitions
- **App Birth:** A 2-4 second intentional sequence where elements bloom from the center.
- **Standard Interactions:** 250ms "Settle" easing for most state changes.
- **Morphing:** When a card expands to full screen, use a shared-element transition (400ms) with an "Organic" path.