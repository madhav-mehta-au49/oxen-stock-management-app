# Design System — Oxen Energies Stock Manager

> Status: **Draft — brand colours derived from the logo image, pending client confirmation.**
> Colour values below were extracted programmatically from `Oxen logo.jpeg`
> (2002×2002). Because the logo is an image, confirm exact hexes with the client
> before final lock. This file is the single source of visual truth.

## 1. Design Direction

- **Style:** Clean, professional, "utility" business tool. Dense but breathable.
- **Mood:** Confident, trustworthy, technical (solar/energy). Not playful.
- **Design Principles:**
  1. **Mobile-first:** every screen comfortable at 360 dp width, one-hand reachable primary actions.
  2. **Data clarity:** quantity, status and money are the most scannable elements.
  3. **Consistent rhythm:** one spacing scale, one radius scale, one icon system.
  4. **Low friction:** the happy path (stock in/out, challan) never exceeds one screen.

## 2. Brand

- **Brand Name:** Oxen Energies
- **Tagline:** Solar Equipment & EPC Supplies
- **Logo:** Supplied as `Oxen logo.jpeg`. It is a **wide horizontal wordmark**
  (content bound ≈ 1340 × 475 px, ratio ≈ 2.82:1) on a white background with
  large padding. Trimmed + transparent background produced in Phase 1
  (`assets/brand/oxen_logo.png`, exact colours preserved).
  - **Always use the exact supplied logo colours.** Never recolour to a flat white silhouette.
  - Full wordmark: navigation headers, splash, letterhead.
  - On dark/brand surfaces (navy headers, login hero) the logo sits on a **white chip** so the original colours stay legible.
  - App launcher icon + native splash: **exact coloured logo on a white background**.
  - Never stretch; preserve the ≈2.82:1 ratio; keep clear space ≥ height/4.
- **Brand Voice:** Direct, factual, respectful. Sentences, not slang.

## 3. Colour Palette

Extracted brand hues (blue → green) with a harmonised scale:

| Token | Hex | Use |
|---|---|---|
| `primary` (brand blue) | `#0A2A66` | Headers, primary buttons, active nav |
| `primaryDeep` | `#071C45` | Pressed/emphasis, gradient end |
| `primarySoft` | `#E8EEF9` | Selected chips, soft backgrounds |
| `accent` (brand green) | `#1E8E3E` | Success, stock-in, positive deltas |
| `accentBright` (lime) | `#3FBF1F` | Accent highlights, charts |
| `accentSoft` | `#E7F4EA` | Success backgrounds |
| `teal` | `#14544F` | Secondary charts / tertiary accents |
| `navy` | `#0B1220` | Dark surfaces, toasts, hero gradients |
| `background` | `#F4F6FB` | Scaffold background |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceAlt` | `#F9FAFC` | Inset panels |
| `border` | `#E4E8F0` | Hairlines, input borders |
| `divider` | `#EFF1F6` | List dividers |
| `textPrimary` | `#0F1A2B` | Titles, body |
| `textSecondary` | `#5B6675` | Secondary text |
| `textMuted` | `#98A1B0` | Hints, captions |
| `success` | `#1E8E3E` | = accent |
| `warning` | `#C77700` | Low-stock caution (amber, functional only) |
| `error` | `#C62828` | Destructive, out-of-stock |
| `info` | `#1565C0` | Issued status, informational |

**Gradients**
- `brandGradient`: `#0A2A66 → #071C45` (primary surfaces).
- `heroGradient`: `#0B1220 → #12224A` (login hero, dashboard header).

**Rule:** Blue = brand/action. Green = positive/success/stock-in. Amber = caution.
Red = danger/stock-out. Never colour a value without its icon/label (accessibility).

## 4. Typography

- **Font Family:** Poppins (Google Fonts) — already used in `app_theme.dart`. Keep.
- **Heading Font:** Poppins (w600/w700) · **Body Font:** Poppins (w400/w500)

| Level | Size | Weight | Line height |
|---|---|---|---|
| H1 / `headlineLarge` | 30 | 700 | 1.2 |
| H2 / `headlineMedium` | 24 | 700 | 1.25 |
| H3 / `headlineSmall` | 20 | 700 | 1.3 |
| Title / `titleMedium` | 16 | 600 | 1.35 |
| Body / `bodyMedium` | 14 | 400 | 1.5 |
| Small / `bodySmall` | 12 | 400 | 1.45 |
| Label / `labelMedium` | 12 | 600 | 1.3 |

Numbers (quantities, money) may use `FontFeature.tabularFigures()` for alignment.

## 5. Spacing

- **Base unit:** 4 px.
- **Scale:** 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48.
- **Screen padding:** 20 px horizontal (already standard via `PagePadding`).
- **Between form fields:** 16 px. Between sections: 18–24 px. Card inner padding: 16 px.
- **Between buttons in a row:** 10–12 px. Sticky bottom bar minimum inset: 20/16.

## 6. Border Radius

- **Small:** 8 px · **Medium (default):** 12 px · **Large:** 20 px · **Pill:** 999 px.
- Icon tiles: 10–13 px. Bottom sheets: top 24 px.

## 7. Shadows

- **Small (`cardShadow`):** `0x0A1A2332`, blur 14, y 4.
- **Medium (`softShadow`):** `0x0F1A2332`, blur 18, y 6.
- **Large:** brand-tinted, blur 20, y 8 (hero cards only).

## 8. Buttons

- **Primary:** brand blue fill, white text, height 52, radius 12, w600 label, optional leading icon.
- **Secondary/Outline:** transparent, `border` stroke, `textPrimary` label.
- **Success:** green fill (confirm stock-in). **Danger:** red fill (stock-out, delete).
- **Ghost:** text-only, `primaryDeep`.
- **Disabled:** `#D8DCE5` fill / `#A6ADBA` text; outline/ghost disable via opacity.
- **Loading:** replace label with 20 px `CircularProgressIndicator` in the button's fg colour.
- Always ≥ 48 px touch target; `dense` variant height 46–48 for card rows.

## 9. Inputs

- **Default:** white fill, 1 px `border`, radius 12, content padding 16.
- **Focus:** 1.6 px `primary` border (+ optional soft glow).
- **Error:** `error` border + message below in `error`.
- **Disabled/read-only:** `surfaceAlt` fill, `textMuted` text.
- **Placeholder:** `textMuted`. Labels above field in `labelMedium`.
- Numeric fields: `TextInputType.number`, digits-only formatter, right or centre aligned.

## 10. Cards

- White, radius 12, `cardShadow`, padding 16. Tappable cards wrap in `InkWell`
  with matching radius. Section titles sit **outside** cards via `SectionHeader`.

## 11. Navigation

- **App bar:** flat, background = scaffold, no elevation, `titleLarge`, dark status icons.
- **Bottom nav (`AppShell`):** 4 tabs — Dashboard, Stock, Challan, More. Active tab:
  `primarySoft` pill + `primary` icon/label; inactive `textMuted`. Height 68 + safe area.
- **Detail/forms:** standard back navigation via `AppBar`.
- **Mobile navigation:** bottom nav only (no drawer). Tablet: consider 2-pane later.

## 12. States

- **Loading:** skeleton or centred spinner; buttons show inline spinners.
- **Empty:** `EmptyState` (icon circle + title + message + optional action).
- **Error:** inline `error` banners; toasts for transient failures.
- **Success:** `AppToast.success`; green confirm banners.
- **Disabled:** per button/input rules above.

## 13. Icons

- **Library:** Material Icons (`Icons.*`), already used throughout.
- **Default size:** 20–22 dp in lists, 17–19 in dense rows, 34+ in empty states.
- **Style:** **Rounded** variants (`Icons.*_rounded`) for consistency.
- **Category icons:** solar_power (panels), bolt (inverters), battery_charging_full
  (batteries), cable, hardware (mounting), lightbulb_outline (lighting), handyman (accessories).
- Icons must always accompany colour-coded states (never colour alone).

## 14. Responsive Design

- **Mobile:** primary target; single-column; 20 px gutters.
- **Tablet:** constrain content `maxWidth: 640`, centre; login uses the wide 2-panel layout.
- **Desktop/web:** out of scope but should not crash.
- **Breakpoints:** Mobile < 600 · Tablet 600–899 · Desktop ≥ 900 (login already switches at 900).

## 15. Accessibility

- Maintain ≥ 4.5:1 contrast for body text on its background.
- Minimum 48×48 dp touch targets.
- Provide semantic labels on icon-only buttons (`tooltip`/`Semantics`).
- Never rely on colour alone (pair with icon + text).
- Support system text scaling without clipping (avoid fixed text heights).
