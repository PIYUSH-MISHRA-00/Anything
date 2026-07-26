---
name: Ambient Intelligence
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#454652'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#757683'
  outline-variant: '#c5c5d4'
  surface-tint: '#4456b6'
  primary: '#11278a'
  on-primary: '#ffffff'
  primary-container: '#2e41a1'
  on-primary-container: '#aab6ff'
  inverse-primary: '#bac3ff'
  secondary: '#4648d4'
  on-secondary: '#ffffff'
  secondary-container: '#6063ee'
  on-secondary-container: '#fffbff'
  tertiary: '#2f343d'
  on-tertiary: '#ffffff'
  tertiary-container: '#464b54'
  on-tertiary-container: '#b6bbc5'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dee0ff'
  primary-fixed-dim: '#bac3ff'
  on-primary-fixed: '#00105a'
  on-primary-fixed-variant: '#2a3d9d'
  secondary-fixed: '#e1e0ff'
  secondary-fixed-dim: '#c0c1ff'
  on-secondary-fixed: '#07006c'
  on-secondary-fixed-variant: '#2f2ebe'
  tertiary-fixed: '#dee2ed'
  tertiary-fixed-dim: '#c2c6d1'
  on-tertiary-fixed: '#171c23'
  on-tertiary-fixed-variant: '#424750'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Public Sans
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Public Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
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
  label-sm:
    fontFamily: Public Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  link-relationship:
    fontFamily: Public Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  unit: 8px
  container-max: 1280px
  gutter: 24px
  margin-mobile: 16px
  margin-desktop: 40px
---

## Brand & Style
The design system is built upon the concept of "Ambient Intelligence"—a digital environment that feels integrated, perceptive, and effortlessly fluid. It targets a sophisticated audience that values privacy, long-term digital memory, and seamless connectivity. 

The style blends **Minimalism** with **Glassmorphism**. It avoids sharp edges and jarring transitions, favoring a "living" interface that responds to user presence. The emotional response is one of calm reliability and high-tech domesticity. Interfaces should feel less like tools and more like an extension of the user’s cognitive space.

## Colors
The palette is centered on a deep indigo primary, representing stability and depth. 

- **Primary (#2e41a1):** Used for key actions and active memory states.
- **Secondary (#6366f1):** Used for relationship links and interactive highlights.
- **Surface Tints:** Use the tertiary color (#f0f4ff) for subtle background shifts to indicate grouped context.
- **Memory States:**
    - **Active:** High-contrast Indigo; represents currently accessed or processing information.
    - **Dormant:** De-emphasized Slate; represents backgrounded information that remains accessible.
    - **Protected:** Deep Obsidian; represents encrypted or private data vaults, requiring higher authentication.

## Typography
This design system utilizes **Public Sans** across all levels to maintain its institutional yet accessible character. 

The type hierarchy is designed for clarity in data-dense environments. **Display** styles use tighter letter-spacing and heavier weights to anchor pages. **Body** text maintains a generous line height to ensure readability in long-form "memory" logs. **Relationship Links** are a specific typographic class used for navigating between connected data nodes, styled with a medium weight to distinguish them from static labels.

## Layout & Spacing
The layout follows a **Fluid Grid** model based on an 8px square rhythm. 

- **Desktop:** 12-column grid with 24px gutters. Use wide margins (40px) to evoke a sense of "air" and focus.
- **Mobile:** 4-column grid with 16px gutters and margins.
- **Spacing Philosophy:** Use dynamic padding for containers. Memory-related components (cards/nodes) should have internal padding that scales with the importance of the data (more padding = more significance).

## Elevation & Depth
Depth is created through **Glassmorphism** and **Tonal Layering** rather than traditional drop shadows.

- **Surface 1 (Base):** Solid white or very light gray.
- **Surface 2 (Floating):** Semi-transparent white with a 20px backdrop blur and a 1px soft border (#000000 5% opacity).
- **Active Focus:** For active memory states, use a soft, primary-tinted glow (`0px 4px 20px rgba(46, 65, 161, 0.15)`) to suggest radiance.
- **Relationship Connectors:** Use thin, 1px vector lines with 40% opacity to visualize links between cards, creating a "web" effect.

## Shapes
The shape language is defined by **ROUND_FULL**. There are no sharp corners in this design system. All interactive elements, containers, and indicators use the maximum possible border radius (Pill-shaped) to reinforce the organic, friendly nature of the ambient intelligence. 

Standard components use a 1rem base radius, while large "Memory Cards" use 3rem (rounded-xl) to feel like smooth, tactile stones.

## Components
- **Buttons:** Always pill-shaped. Primary buttons use the Indigo fill with white text. Secondary buttons use a glass effect with an Indigo border.
- **Relationship Links:** Distinct from standard buttons; these appear as small, pill-shaped tags with a subtle secondary color background and a "link" icon. They visualize the connection between two disparate data points.
- **Memory Cards:** The primary container.
    - *Active:* Thick Indigo border, subtle inner glow.
    - *Dormant:* Semi-transparent background, grayscale content.
    - *Protected:* Solid dark background, minimalist lock icon, blurred content preview.
- **Input Fields:** Fully rounded with a light tertiary fill. On focus, the border transitions to the primary Indigo.
- **Chips/Status Indicators:** Used for metadata. Always use `label-sm` typography and a light tint of the state color (e.g., light blue for dormant).
- **Navigation:** A floating pill-shaped dock at the bottom of the screen, utilizing glassmorphism and backdrop blurs to stay unobtrusive.