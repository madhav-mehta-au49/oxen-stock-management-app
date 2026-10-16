# UX Flows — Oxen Energies Stock Manager

> The journeys the app must support. Each flow lists loading, empty, success and
> error states. Screen names map to `lib/features/*`.

## Flow 0 — App Launch

1. Splash shows (logo on brand background).
2. `Firebase.initializeApp` + restore session.
3. If signed in → Dashboard. If not → Login.
- **Loading:** branded splash.
- **Error:** if Firebase fails to init, show a retry screen (do not fall through to demo data).

## Flow 1 — Sign In

1. User opens Login.
2. Enters email + password (optional PIN mode later).
3. Tap **Sign in** → button shows spinner.
4. Success → push Dashboard (`AppShell`).
- **Validation:** email format; password non-empty.
- **Error:** invalid credentials → inline error banner, no field cleared.
- **Forgot password:** currently a toast; becomes a real Firebase reset email.
- **Empty:** N/A.

## Flow 2 — Dashboard

1. User opens Dashboard tab.
2. Summary (total value, items, low stock, today in/out), movement chart, recent activity, low-stock banner.
3. Quick actions: Stock In / Stock Out / New Challan; tap activity → Item detail.
- **Loading:** skeleton/spinner on first load.
- **Empty:** no items → empty states in cards.
- **Error:** offline → cached data + subtle offline hint.

## Flow 3 — Inventory List

1. Stock tab → list of item cards.
2. Search by name/SKU/supplier; filter by category chip; sort via sort sheet.
3. Tap card → Item detail; row actions → Stock In/Out/Edit.
- **Empty:** no items → "Add first item"; no matches → "Clear filters".
- **Loading:** list spinner / shimmer.
- **Error:** load failure → retry affordance.

## Flow 4 — Add / Edit Item

1. FAB "Add item" (or Edit from detail) → Item form.
2. Fill name, category, unit, unit nos, quantity/opening, reorder, prices, supplier, placeholder icon.
3. Save → toast; list updates.
- **Validation:** name ≥ 3; numbers valid; required fields marked.
- **Edge:** editing quantity writes an adjustment ledger row so ON HAND matches the ledger.
- **Edge:** deleting an item removes its ledger and strips it from challans (warns if challans affected).

## Flow 5 — Stock In / Stock Out

1. Quick action or row action → Movement form.
2. Select item (or add new inline); enter quantity with +/- and optional MAX.
3. Choose source (in) / reason (out); optional reference, date, notes.
4. Confirm → toast; quantity + ledger update.
- **Validation:** quantity > 0; out cannot exceed available unless **admin override**.
- **Loading:** confirm button spinner.
- **Error:** insufficient stock → red panel + override toggle.

## Flow 6 — New Challan

1. Challan tab → New challan.
2. Charger auto-number shown (`OX/CH/<year>/NNNN`).
3. Enter customer, site, address, contact, vehicle, date; choose PDF format.
4. Add items (picker) → qty + rate sheet → line added.
5. Confirm & issue → challan saved (Issued), stock deducted, → Preview.
- **Validation:** customer required; ≥ 1 line; per-line qty ≤ available.
- **Loading:** confirm button spinner.
- **Error:** insufficient stock blocks issue with a clear message.
- **Empty:** no lines → empty state with "Add first item".

## Flow 7 — Challan Preview & PDF

1. Preview shows issued banner, ship-to, details, items, totals, stock deductions.
2. Actions: Preview & print PDF, Share, New challan, Back to dashboard.
3. PDF renders on the **company letter pad** (Phase 4).
- **Loading:** PDF action spinner.
- **Error:** PDF build failure → friendly toast.

## Flow 8 — Settings / More

1. More tab → profile (name/role from auth), alert toggles, company profile, app info.
2. Sign out → Login (clears session).
- **Role:** non-admin sees company profile read-only.
- **Persistence:** toggles save per user; company profile saved to `meta/company` (admin).

## Flow 9 — First-Run / Onboarding

1. First sign-in → optional onboarding (1–3 cards): what the app does, add first item.
2. Seed/demo data only used during UAT; not shown to end users by default.
