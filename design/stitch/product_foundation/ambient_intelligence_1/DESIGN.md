---
name: Ambient Intelligence
colors:
  surface: '#fcf9f8'
  surface-dim: '#dcd9d9'
  surface-bright: '#fcf9f8'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f6f3f2'
  surface-container: '#f0eded'
  surface-container-high: '#eae7e7'
  surface-container-highest: '#e5e2e1'
  on-surface: '#1c1b1b'
  on-surface-variant: '#454652'
  inverse-surface: '#313030'
  inverse-on-surface: '#f3f0ef'
  outline: '#757683'
  outline-variant: '#c5c5d4'
  surface-tint: '#4456b6'
  primary: '#11278a'
  on-primary: '#ffffff'
  primary-container: '#2e41a1'
  on-primary-container: '#aab6ff'
  inverse-primary: '#bac3ff'
  secondary: '#5e5f5c'
  on-secondary: '#ffffff'
  secondary-container: '#e0e0dc'
  on-secondary-container: '#626360'
  tertiary: '#34342e'
  on-tertiary: '#ffffff'
  tertiary-container: '#4b4b44'
  on-tertiary-container: '#bcbbb2'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dee0ff'
  primary-fixed-dim: '#bac3ff'
  on-primary-fixed: '#00105a'
  on-primary-fixed-variant: '#2a3d9d'
  secondary-fixed: '#e3e2df'
  secondary-fixed-dim: '#c7c7c3'
  on-secondary-fixed: '#1b1c1a'
  on-secondary-fixed-variant: '#464744'
  tertiary-fixed: '#e5e3d9'
  tertiary-fixed-dim: '#c8c7be'
  on-tertiary-fixed: '#1b1c17'
  on-tertiary-fixed-variant: '#474741'
  background: '#fcf9f8'
  on-background: '#1c1b1b'
  surface-variant: '#e5e2e1'
typography:
  headline-lg:
    fontFamily: Public Sans
    fontSize: 48px
    fontWeight: '600'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Public Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '500'
    lineHeight: '1.3'
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: 0.01em
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.08em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  unit: 8px
  container-padding: 32px
  gutter: 24px
  stack-lg: 64px
  stack-md: 32px
  stack-sm: 16px
---

## Brand & Style

The design system is centered on the concept of "Invisible Intelligence." It transforms the interaction with AI from a technical utility into a serene, high-end lifestyle experience. The brand personality is calm, human, and reassuring, prioritizing emotional resonance over computational power.

The visual style is a sophisticated evolution of **Material 3**, blending extreme **Minimalism** with **Glassmorphism**. It utilizes expansive white space, subtle tonal shifts, and soft, organic transitions to make the interface feel less like a machine and more like a responsive environment. The goal is to evoke a sense of quiet confidence and effortless capability.

## Colors

The palette is anchored in warm, organic neutrals that mimic high-quality paper or soft limestone. This base creates a "hush" across the UI, allowing the single accent color—a deep, intelligent **Indigo**—to signify intentionality and action.

Dynamic color principles are applied through tonal mapping: 
- **Surface:** A soft off-white/cream that prevents screen fatigue.
- **On-Surface:** A deep charcoal, avoiding pure black to maintain a premium feel.
- **Accent:** Reserved for primary calls to action and moments of focus.
- **State Colors:** Success and alerts should be muted and integrated into the tonal palette rather than using harsh reds or greens.

## Typography

Typography focuses on excessive legibility and a relaxed hierarchy. **Public Sans** provides a sturdy, institutional yet modern foundation for headlines, while **Inter** ensures functional clarity for body text and system labels.

Generous tracking is applied to labels to create an editorial feel. Line heights are intentionally loose (1.5x - 1.6x) to ensure the text feels unhurried. For mobile, headline sizes are significantly reduced and tightened to maintain a balanced "safe" margin around the edges of the screen.

## Layout & Spacing

The layout follows a **Fluid Grid** model with high internal margins to create a "sanctuary" for content. On desktop, the interface uses a centered 12-column layout with a maximum content width of 1440px to prevent information sprawl.

Spacing is "comfortable," favoring larger gaps (stack-lg) between major sections to emphasize the minimal aesthetic. 
- **Mobile:** 20px side margins, single column stack.
- **Tablet:** 32px margins, 6-column grid.
- **Desktop:** 64px+ margins for a focused, cinematic feel.

## Elevation & Depth

Depth is achieved through **Ambient Shadows** and **Tonal Layers** rather than physical borders. The design system uses three primary elevation levels:
1.  **Level 0 (Base):** The neutral surface color.
2.  **Level 1 (Floating):** Used for primary cards. It features a very soft, multi-layered shadow (15% opacity tint of the primary indigo) to make elements feel as though they are hovering slightly above the surface.
3.  **Level 2 (Active):** Used for overlays. This incorporates a **Backdrop Blur** (Glassmorphism) to maintain context of the underlying layer while focusing the user.

Avoid harsh outlines. Use subtle 1px inner strokes in a slightly lighter shade of the background to define edges on high-elevation components.

## Shapes

The shape language is defined by ultra-softness. Large corner radii (24px to 32px) are applied to all container elements and cards to evoke a friendly, approachable, and "cushioned" feel. Smaller elements like buttons and chips follow a **Pill-shaped** (Full Rounded) profile, ensuring no sharp edges exist within the experience.

## Components

### Buttons
Primary buttons are pill-shaped, using the deep indigo background with white text. Hover states should involve a soft scale-up (1.02x) rather than a color change. Ghost buttons use a subtle tonal border.

### Cards
Cards are the primary vessel for information. They must have a minimum padding of 32px and a corner radius of 32px. Use subtle background gradients (e.g., from Neutral 100 to Neutral 200) to give them a slight 3D "pillowy" effect.

### Input Fields
Inputs are large and minimal. Instead of a traditional box, use a soft-tinted pill shape with a clear, high-contrast cursor. Labels should float elegantly above or within the field in a `label-sm` style.

### The "Creation" Experience
The design system replaces all loading spinners with a custom "Creation" motion. Use a particle-based animation where soft, semi-transparent circles gather and morph into the final component shape. Use copy like "Curating your view..." or "Assembling your request..." to maintain the human tone.

### Lists & Items
List items should have generous vertical padding (24px) and be separated by whitespace or extremely faint tonal dividers (2% opacity). Interaction should feel fluid, with items "sliding" into place upon entry.