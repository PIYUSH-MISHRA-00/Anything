---
name: Institutional Logic
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
  on-surface-variant: '#43474f'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eff1f3'
  outline: '#73777f'
  outline-variant: '#c3c6d0'
  surface-tint: '#40608b'
  primary: '#001631'
  on-primary: '#ffffff'
  primary-container: '#002b54'
  on-primary-container: '#7493c2'
  inverse-primary: '#a8c8fa'
  secondary: '#0040e0'
  on-secondary: '#ffffff'
  secondary-container: '#2e5bff'
  on-secondary-container: '#efefff'
  tertiary: '#06172a'
  on-tertiary: '#ffffff'
  tertiary-container: '#1c2c40'
  on-tertiary-container: '#8393ab'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d4e3ff'
  primary-fixed-dim: '#a8c8fa'
  on-primary-fixed: '#001c3a'
  on-primary-fixed-variant: '#264872'
  secondary-fixed: '#dde1ff'
  secondary-fixed-dim: '#b8c3ff'
  on-secondary-fixed: '#001356'
  on-secondary-fixed-variant: '#0035be'
  tertiary-fixed: '#d3e4fe'
  tertiary-fixed-dim: '#b7c8e1'
  on-tertiary-fixed: '#0b1c30'
  on-tertiary-fixed-variant: '#38485d'
  background: '#f7f9fb'
  on-background: '#191c1e'
  surface-variant: '#e0e3e5'
typography:
  display-xl:
    fontFamily: Public Sans
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Public Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  title-md:
    fontFamily: Public Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Public Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Public Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Public Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  mono-label:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  margin-page: 32px
  gutter-grid: 24px
  indent-dept: 24px
  indent-team: 48px
---

## Brand & Style

The design system is engineered for high-stakes enterprise environments where clarity, hierarchy, and reliability are paramount. The brand personality is **authoritative, systemic, and transparent**, designed to evoke a sense of absolute stability and professional rigor. It serves a primary audience of systems administrators, compliance officers, and organizational architects who manage complex, multi-tiered infrastructures.

The design style is **Corporate Modern with a Structural emphasis**. It prioritizes information density and logical grouping over decorative elements. Visual weight is used strategically to differentiate between global organizational settings and granular team-level data. The aesthetic is "Invisible UI"—where the interface recedes to let critical certification states and structural relationships lead the user's focus.

## Colors

The palette is anchored by **Trusted Navy (#002B54)** for primary navigation and global headers, signaling authority and permanence. **Security Cobalt (#2E5BFF)** is utilized for primary actions and administrative highlights, providing a clear path for user progression.

### Certification Color System
A rigorous four-tier state system indicates the lifecycle and trust level of assets:
- **Experimental (Amber):** Cautionary; indicates sandbox or unvetted status.
- **Verified (Emerald):** Functional; passed automated integrity checks.
- **Enterprise Approved (Blue):** Standardized; cleared for broad internal usage.
- **Platform Certified (Indigo):** Gold standard; immutable and globally compliant.

Backgrounds utilize a tiered grayscale palette to separate organizational levels (Org = White, Dept = Slate-50, Team = Slate-100).

## Typography

The design system exclusively uses **Public Sans** to maintain an institutional, highly legible, and neutral tone. The typographic scale is optimized for data density and hierarchical clarity.

- **Headlines:** Use tighter letter-spacing and heavier weights to anchor pages.
- **Labels:** Small labels utilize `uppercase` styling with increased tracking (0.05em) to distinguish administrative metadata from user content.
- **Mono Integration:** For technical identifiers (Org IDs, API Keys), JetBrains Mono is used at the label scale to ensure character distinction.

## Layout & Spacing

This design system employs a **Fixed Grid** on desktop (1440px max-width) and a **Fluid Grid** for mobile. The spacing rhythm is based on a **4px baseline**, ensuring all components align to a predictable vertical and horizontal cadence.

### Structural Hierarchy
To visualize the 3-tier ecosystem, the layout utilizes **Structural Indentation**:
- **Organization Level:** Full-width containers, White background.
- **Department Level:** 24px left-inset content area or sidebar indicator, Slate-50 background.
- **Team Level:** 48px left-inset or nested card structure, Slate-100 background.

Gutters are kept at a rigid 24px to maintain whitespace in data-heavy views.

## Elevation & Depth

Hierarchy is achieved through **Low-contrast outlines** and **Tonal layering** rather than heavy shadows. This prevents the interface from feeling cluttered in dense multi-level views.

- **Level 0 (Canvas):** Base background color of the specific organizational tier.
- **Level 1 (Cards/Surface):** White background with a 1px border (#E2E8F0). No shadow.
- **Level 2 (Active/Modals):** White background with a subtle, 8% opacity Security Cobalt shadow (0px 4px 12px) to denote temporary focus.
- **Structural Lines:** Vertical guide rails (1px width) are used in tree views to visually connect Departments to their parent Organizations.

## Shapes

The shape language is **Soft (0.25rem)**. This slight rounding provides a modern touch without sacrificing the professional "grid-first" feel of the enterprise ecosystem. 

- **Input Fields/Buttons:** 0.25rem (4px).
- **Cards/Containers:** 0.5rem (8px).
- **Certification Badges:** 1rem (Pill-shaped) to distinguish them from functional UI components.

## Components

### Buttons & Controls
- **Primary:** Trusted Navy background with White text. Square shoulders (4px radius).
- **Administrative:** Security Cobalt ghost buttons for secondary settings.

### Certification Chips
Pill-shaped badges with high-contrast text. Use the `certification_states` color as a 10% opacity background and a 100% opacity left-hand "status dot" icon.

### Tiered List Items
Lists must include a "Structural Rail" on the left. Organizations use a thick 4px border-left in Trusted Navy. Departments use a 2px border-left in Slate-400. Teams use no border-left but a 48px padding-left.

### Form Fields
Required fields use a subtle 2px bottom border in Security Cobalt when focused. Labels must always be visible (no floating labels) to ensure context is never lost during data entry.

### Data Grids
Zebra striping is forbidden. Use 1px horizontal dividers only. Header rows use `label-sm` typography with a Slate-100 background.