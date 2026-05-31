---
name: Industrial-Professional
colors:
  surface: '#f8f9ff'
  surface-dim: '#d0dbed'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e6eeff'
  surface-container-high: '#dee9fc'
  surface-container-highest: '#d9e3f6'
  on-surface: '#121c2a'
  on-surface-variant: '#444653'
  inverse-surface: '#27313f'
  inverse-on-surface: '#eaf1ff'
  outline: '#757684'
  outline-variant: '#c4c5d5'
  surface-tint: '#3755c3'
  primary: '#00288e'
  on-primary: '#ffffff'
  primary-container: '#1e40af'
  on-primary-container: '#a8b8ff'
  inverse-primary: '#b8c4ff'
  secondary: '#006d30'
  on-secondary: '#ffffff'
  secondary-container: '#92f5a4'
  on-secondary-container: '#007233'
  tertiary: '#700006'
  on-tertiary: '#ffffff'
  tertiary-container: '#9b000c'
  on-tertiary-container: '#ffa398'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dde1ff'
  primary-fixed-dim: '#b8c4ff'
  on-primary-fixed: '#001453'
  on-primary-fixed-variant: '#173bab'
  secondary-fixed: '#95f8a7'
  secondary-fixed-dim: '#79db8d'
  on-secondary-fixed: '#00210a'
  on-secondary-fixed-variant: '#005323'
  tertiary-fixed: '#ffdad6'
  tertiary-fixed-dim: '#ffb4ab'
  on-tertiary-fixed: '#410002'
  on-tertiary-fixed-variant: '#93000b'
  background: '#f8f9ff'
  on-background: '#121c2a'
  surface-variant: '#d9e3f6'
typography:
  headline-lg:
    fontFamily: Work Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Work Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Work Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Public Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Public Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: Atkinson Hyperlegible Next
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.05em
  data-numeric:
    fontFamily: Public Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 24px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  gutter-mobile: 16px
  gutter-desktop: 24px
  margin-mobile: 16px
  margin-desktop: 48px
  touch-target: 48px
---

## Brand & Style

The design system is engineered for the high-utility environment of small business operations, specifically textile shops, hotels, and factories. The brand personality is rooted in reliability, precision, and accessibility, ensuring that staff members across varying levels of digital literacy can manage attendance and payroll without friction.

The visual style follows an **Industrial-Professional** aesthetic. It prioritizes clarity and function over decoration, utilizing high-contrast elements and a structured grid to facilitate quick data entry and status checks. The emotional response should be one of "trust through clarity"—a system that feels as robust and dependable as the physical machinery or infrastructure of the business it serves.

## Colors

The palette is optimized for high-contrast visibility in diverse lighting conditions, such as brightly lit factory floors or dimly lit storage areas.

- **Trust Blue (#1E40AF):** The primary color, used for core navigation, primary actions, and branding. It signals stability and professional oversight.
- **Success Green (#15803D):** Reserved specifically for attendance check-ins and positive salary status.
- **Alert Red (#B91C1C):** Used for late marks, missed shifts, or payroll discrepancies.
- **Neutral Carbon (#1F2937):** Used for primary text and iconography to ensure maximum legibility against white or light gray surfaces.

Backgrounds should remain primarily white or very light gray (#F9FAFB) to maintain a clean, high-contrast workspace.

## Typography

This design system employs a multi-font approach to maximize legibility for a diverse workforce.

- **Work Sans** is used for headlines to provide a professional, grounded structure.
- **Public Sans** is used for body copy and data entry, chosen for its institutional clarity and neutral tone.
- **Atkinson Hyperlegible Next** is utilized for labels and instructional text to ensure high character differentiation, supporting workers with visual impairments or those reading in low-light environments.

Numeric data (salaries, hours, dates) should always be rendered in a medium or bold weight to ensure no ambiguity in financial reporting.

## Layout & Spacing

The layout follows a **Fixed Grid** model on desktop and a **Fluid Grid** on mobile devices. The rhythm is based on an 8px modular scale.

- **Touch Targets:** All interactive elements (buttons, checkboxes) must maintain a minimum height of 48px to accommodate use in active work environments where precision may be lower.
- **Desktop:** A 12-column grid with 24px gutters. Content is centered with a max-width of 1280px.
- **Mobile/Tablet:** A 4-column (mobile) or 8-column (tablet) grid. Use 16px margins to maximize screen real estate for data tables.
- **Data Density:** Use generous vertical padding in list items (16px) to prevent accidental taps, especially in "Punch In/Out" screens.

## Elevation & Depth

To maintain the "Industrial" feel, this design system avoids complex shadows or decorative blurs. Depth is communicated through **Tonal Layers** and **Low-Contrast Outlines**.

1. **Surface Base:** The primary background (White).
2. **Surface Container:** Used for cards and sections (Light Gray #F3F4F6).
3. **Outlines:** Elements like input fields and cards use a 1px solid border (#D1D5DB).
4. **Active State:** When an element is focused or active, the border thickens to 2px and uses the Primary color (#1E40AF) rather than using a shadow.

This flat, bordered approach ensures that elements remain distinct even on screens with lower color accuracy or high glare.

## Shapes

The shape language is "Soft-Industrial." While the grid is rigid, the corners are rounded to 8px (0.5rem) to make the application feel modern and approachable. 

- **Standard Elements:** Buttons, Cards, and Inputs use the 8px radius.
- **Status Chips:** Use a full pill-shape (100px radius) to differentiate them from interactive buttons.
- **Selection Indicators:** Use sharp 2px vertical bars on the left side of active list items to indicate focus.

## Components

### Buttons
- **Primary:** Solid Trust Blue background with White text. Bold weight.
- **Secondary (Attendance):** Solid Success Green background for "Check In."
- **Tertiary:** Outlined buttons for destructive or secondary actions like "Cancel" or "Edit."

### Input Fields
- High-contrast 1px borders (#9CA3AF). 
- Labels must always be visible (never use placeholder-only labels). 
- Error states use 2px Alert Red borders with a descriptive icon.

### Attendance Cards
- Large, clear typography for the current time and status.
- Primary action buttons should span the full width of the card on mobile for ease of access.

### Status Chips
- Use high-contrast background tints with dark text (e.g., Light Green background with Dark Green text) for "Present," "Absent," or "Paid" statuses.

### Multi-language Support
- Every label should have an associated clear, universal icon (e.g., a clock for attendance, a banknote for salary) to assist workers who may be less fluent in the primary interface language.