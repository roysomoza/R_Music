---
name: Pure Audio Dark
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#c3c6d8'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#8c90a2'
  outline-variant: '#424656'
  surface-tint: '#b4c5ff'
  primary: '#b4c5ff'
  on-primary: '#002979'
  primary-container: '#0f62fe'
  on-primary-container: '#f3f3ff'
  inverse-primary: '#0052dd'
  secondary: '#c8c6c6'
  on-secondary: '#303030'
  secondary-container: '#474747'
  on-secondary-container: '#b6b5b4'
  tertiary: '#ffb59d'
  on-tertiary: '#5d1900'
  tertiary-container: '#c84000'
  on-tertiary-container: '#fff1ed'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174c'
  on-primary-fixed-variant: '#003da9'
  secondary-fixed: '#e4e2e1'
  secondary-fixed-dim: '#c8c6c6'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474747'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59d'
  on-tertiary-fixed: '#390c00'
  on-tertiary-fixed-variant: '#832700'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: IBM Plex Sans
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: IBM Plex Sans
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 32px
    letterSpacing: '0'
  headline-sm:
    fontFamily: IBM Plex Sans
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
    letterSpacing: '0'
  body-lg:
    fontFamily: IBM Plex Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: '0'
  body-md:
    fontFamily: IBM Plex Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-bold:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: IBM Plex Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.02em
  headline-lg-mobile:
    fontFamily: IBM Plex Sans
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
    letterSpacing: -0.01em
spacing:
  base-unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 48px
  container-max: 1440px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
---

## Brand & Style

The design system is an ultra-refined, performance-oriented interface designed for high-fidelity audio production and management. It targets professionals and audiophiles who require a distraction-free environment that maximizes focus during long sessions.

The aesthetic is **Modern Corporate Minimalism**, characterized by a systematic, high-contrast dark interface. It leverages a rigorous grid and precision-engineered components to evoke a sense of reliability and technical excellence. The style prioritizes utility and clarity, using depth and subtle tonal shifts rather than decorative flourishes to guide the user's eye.

## Colors

The palette is built on a "Carbon" foundation, utilizing a deep neutral base to minimize eye strain. 

- **Primary Blue (#0f62fe):** Reserved strictly for interactive actions, primary call-to-actions, and active status indicators. 
- **Neutral Core (#121212):** The primary canvas color. UI depth is achieved through incremental lightness shifts (Surface Layer 1 and 2) rather than color variation.
- **Contrast Ratios:** All text elements must maintain a minimum 4.5:1 ratio against their respective backgrounds, with primary headers aiming for 7:1 for maximum legibility.

## Typography

This design system utilizes **IBM Plex Sans** to reinforce its systematic and technical heritage. The typeface’s humanist-grotesque hybrid nature ensures it remains readable at small sizes in dense data views while appearing authoritative in large displays.

- **Scale:** Use a modular scale where body text stays at 14px for density.
- **Weight:** Use SemiBold (600) for high-level hierarchy and Regular (400) for content. 
- **Tracking:** Headings use slight negative tracking (-0.01em) to maintain visual tension, while labels use positive tracking (0.02em) to improve legibility on dark backgrounds.

## Layout & Spacing

The layout is governed by a **strict 12-column fluid grid** for desktop and a **4-column grid** for mobile. 

- **Grid Logic:** All components must align to a 4px baseline grid. 
- **Rhythm:** Use 16px (md) for standard gutters and 24px (lg) for vertical section spacing. 
- **Density:** In data-heavy audio views (waveforms, mixers), padding may be reduced to 8px (sm) to maximize information density.

## Elevation & Depth

In this dark mode system, depth is communicated through **Tonal Layering** and **Low-Contrast Outlines**. 

- **Layering:** Elements "closer" to the user are rendered in lighter shades of grey. Background is #121212, Cards/Panels are #161616, and floating Modals are #262626.
- **Outlines:** Use 1px borders (#393939) to define shapes. Avoid heavy shadows; instead, use a subtle 10% black outer glow only for high-level floating elements like dropdowns to separate them from the layer below.
- **Active State:** The primary blue is the only element that should feel "vibrant." Everything else should remain grounded in the neutral palette.

## Shapes

The shape language is **Sharp (0px)**. 

To maintain the architectural and systematic feel, all containers, buttons, and input fields utilize 90-degree corners. This evokes a professional "rack-mount" hardware aesthetic. The only exception to the sharp rule is for specific data-viz elements like circular knobs or progress rings where the geometry is functional.

## Components

- **Buttons:** Primary buttons are solid #0f62fe with white text. Secondary buttons are transparent with a #393939 border and #f4f4f4 text. No rounded corners.
- **Inputs:** Dark backgrounds (#161616) with a bottom-only 1px border for a refined look. On focus, the border becomes the primary blue.
- **Cards:** No shadows. Use #161616 background with a 1px border (#393939).
- **Lists:** High-density rows with 1px dividers. Hover states should use #262626 to provide immediate feedback without color shift.
- **Audio Specifics:** Waveform displays should use the primary blue for active segments and #393939 for background/inactive states. Faders and sliders use the primary blue for the "active track" and #f4f4f4 for the handle for high visibility.
- **Status Chips:** Small, rectangular, utilizing a subtle background tint of the status color (e.g., dark green background with light green text) to remain unobtrusive.