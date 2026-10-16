# Product Requirements Document — Oxen Energies Stock Manager

> Status: **Draft — awaiting client sign-off**
> Owner: Oxen Energies (client) • Builder: Internal
> Source of truth: This document + `docs/` set. Derived from the client's finalised
> feature list and the current demo app (`lib/`). Follows the *Vibe Coding Blueprint*.

## 1. Product Overview

- **Product Name:** Oxen Energies Stock Manager
- **One-Line Description:** A mobile inventory workspace for a solar equipment
  supplier to track stock, record movements, and issue delivery challans.
- **Product Type:** Internal business tool (single-tenant, for one company).
- **Primary Platform:** Android (Flutter). iOS build possible later; web is out of scope.

## 2. Problem

- **What problem are we solving?** Oxen Energies tracks solar panels, inverters,
  batteries, cables, mounting and accessories across a yard/warehouse using
  manual registers and spreadsheets. Stock counts drift, challans are
  hand-written, and there is no reliable low-stock warning.
- **Why does it matter?** Wrong stock counts lead to failed site deliveries,
  over-purchasing and lost customer trust. Hand-written challans are error-prone
  and hard to reprint.
- **How are users solving this today?** Paper stock registers, WhatsApp messages
  between the store and site teams, and a Microsoft Excel ledger on one PC.

## 3. Goal

- **Primary Goal:** Give the store team a single, reliable, phone-first system
  for stock levels, movements and delivery challans, backed by cloud data so all
  5 employees see the same numbers.
- **Secondary Goals:**
  - Issue a professional challan PDF on the company's own letter pad in under a minute.
  - Alert before an item runs out (reorder level).
  - Provide a simple audit trail of every stock in/out.

## 4. Target Users

### User Type 1 — Store Manager (Admin)
- **Description:** Runs the warehouse; approves stock and is accountable for counts.
- **Needs:** Add/edit items, correct quantities, issue challans, view full ledger, manage staff.
- **Pain Points:** Re-counting stock, chasing paper, no single source of truth.

### User Type 2 — Store Staff (Staff)
- **Description:** Physically receives and issues material, prepares challans at dispatch.
- **Needs:** Fast stock-in and stock-out entry, quick item lookup (name/SKU/supplier), challan creation.
- **Pain Points:** Slow forms, items missing from the list, unclear "how many left".

### User Type 3 — Owner / Accounts (Viewer, optional)
- **Description:** Reviews stock value and challan history.
- **Needs:** Read-only dashboard totals and challan records.
- **Pain Points:** Has to ask the store team for numbers.

## 5. User Stories

- As a **store staff**, I want to sign in with my own account so that actions are attributable.
- As a **store staff**, I want to stock-in / stock-out material in seconds so that I can keep moving.
- As a **store staff**, I want to add a missing item on the spot so that I don't leave the entry flow.
- As a **store manager**, I want a dashboard of total value and low-stock items so that I know what to reorder.
- As a **store manager**, I want to create a challan and get a PDF on our letter pad so that dispatch looks professional.
- As a **store manager**, I want an automatic stock deduction when a challan is issued so that counts stay correct.
- As an **owner**, I want a per-item ledger so that I can audit any discrepancy.

## 6. Core Features

### Feature 1 — Authentication & Accounts
- **Purpose:** Restrict access to the 5 employees; attribute every action.
- **User Flow:** Splash → Login (email + password) → Dashboard. Session persists. Sign out from Settings.
- **Inputs:** Email, password (Firebase Auth).
- **Outputs:** Authenticated session + user profile (name, role).
- **Acceptance Criteria:**
  - Only registered accounts can reach the app shell.
  - Invalid credentials show a clear, non-revealing error.
  - Signed-in user's name/role appear in Settings and on challans ("Prepared by").
  - Sign out returns to Login and clears the session.
- **Edge Cases:** No network at first sign-in; disabled account; forgotten password.

### Feature 2 — Dashboard
- **Purpose:** At-a-glance stock health.
- **User Flow:** Open app → Dashboard tab.
- **Inputs:** Live items, transactions, challans.
- **Outputs:** Total stock value, total items, low-stock count, today in/out, movement chart (7D/30D), recent activity, low-stock banner, quick actions.
- **Acceptance Criteria:** Figures are computed from the database (not mock); quick actions open Stock In / Stock Out / New Challan; tapping activity opens the item.
- **Edge Cases:** Empty inventory → meaningful empty states; no movement today.

### Feature 3 — Inventory (Stock List)
- **Purpose:** Browse, search, filter, sort and act on items.
- **User Flow:** Stock tab → search/filter chips/sort → tap item, or use row actions (In/Out/Edit).
- **Inputs:** Search text; category filter; sort mode.
- **Outputs:** Item cards with status pill, quantity, reorder level, value.
- **Acceptance Criteria:** Search matches name/SKU/supplier; category chips show counts; sort options work; status (IN / LOW / OUT) is correct.
- **Edge Cases:** 0 items (empty state); no search matches.

### Feature 4 — Item Create / Edit / Delete
- **Purpose:** Maintain the item master.
- **User Flow:** Add item FAB or Edit → form → save; delete from detail menu.
- **Inputs:** Name, category, unit, unit nos, opening/hand quantity, reorder level, purchase & selling price, supplier, placeholder icon.
- **Outputs:** Item persisted; ledger adjustment row if quantity changed.
- **Acceptance Criteria:** Name ≥ 3 chars; quantity/reorder numeric ≥ 0; a quantity change on edit writes an adjustment entry so ON HAND matches the ledger; delete removes item + ledger (and updates challans that referenced it).
- **Edge Cases:** Duplicate SKU on quick-add rejected; deleting an item used by a challan.

### Feature 5 — Stock Movements (In / Out)
- **Purpose:** Record every inbound/outbound quantity.
- **User Flow:** Quick action or item card → form → Confirm.
- **Inputs:** Item, quantity, source (in) / reason (out), reference, date, notes; admin override for negative stock.
- **Outputs:** Updated quantity + ledger transaction with running balance.
- **Acceptance Criteria:** Quantity > 0; stock-out blocked when quantity > available unless admin override; "after move" preview and valuation shown.
- **Edge Cases:** Insufficient stock; max button; new item added inline.

### Feature 6 — Delivery Challans
- **Purpose:** Issue goods to a customer/site and deduct stock.
- **User Flow:** Challan tab → New challan → customer/site + items → Confirm → Preview → PDF (print/share).
- **Inputs:** Customer, site, address, contact, vehicle, date, items (qty + rate), remarks, PDF format.
- **Outputs:** Challan record (status Issued), auto stock-out per line, PDF.
- **Acceptance Criteria:** At least one item required; per-line qty cannot exceed available; issuing deducts stock and writes challan-out ledger rows; number is auto (format `OX/CH/<year>/NNNN`).
- **Edge Cases:** Insufficient stock blocks issue; reprint a historical challan.

### Feature 7 — Challan PDF on Company Letter Pad
- **Purpose:** Produce the client's actual letter-pad challan (not a generic layout).
- **User Flow:** From Preview → "Preview & print PDF" / "Share".
- **Inputs:** Challan data + company letterhead asset.
- **Outputs:** A4 PDF that visually matches the supplied `challan latter pad` header/branding.
- **Acceptance Criteria:** Company logo + letterhead header used; correct fields; amount in words; signature blocks; prints and shares on a real device.
- **Edge Cases:** Long item lists spanning multiple pages keep the letterhead header on page 1.

### Feature 8 — Settings & Profile
- **Purpose:** Device preferences, company profile, account.
- **User Flow:** More tab.
- **Inputs:** Alert toggles, default challan format, company profile fields.
- **Outputs:** Persisted preferences (per device/user).
- **Acceptance Criteria:** Profile (name/role) reflects the signed-in user; company profile matches challan output; sign out works.
- **Edge Cases:** Non-admin cannot edit company profile (role-gated).

### Feature 9 — Reporting / Ledger
- **Purpose:** Per-item and global movement history.
- **User Flow:** Item detail → Stock ledger; Dashboard → Full ledger.
- **Inputs:** Existing transactions.
- **Outputs:** Day-grouped ledger with signed qty and running balance.
- **Acceptance Criteria:** Balance after each row matches the item's quantity at that point.
- **Edge Cases:** Item with no movements.

### Feature 10 — Remember me & Credential Autofill
- **Purpose:** Avoid retyping credentials on every launch.
- **User Flow:** First sign-in → OS offers to save email/password → next time fields autofill (biometric) and session stays signed in.
- **Inputs:** Email, password, "Remember me" toggle.
- **Outputs:** Email persisted locally; credentials saved in the device password manager (Android Autofill).
- **Acceptance Criteria:**
  - Sign-in persists across app restarts (Firebase session).
  - Email prefills when "Remember me" is on; cleared when off.
  - Login fields expose `AutofillHints` inside an `AutofillGroup` so the OS password manager can save/autofill.
- **Edge Cases:** Shared device (user can untick Remember me); autofill unavailable.

### Feature 11 — Notifications & Sound Alerts
- **Purpose:** Surface stock events to the user proactively.
- **User Flow:** Event occurs (low stock / challan issued) → in-app notification appears in the notification centre (bell) and, if enabled, a system notification + sound.
- **Inputs:** Alert preferences in Settings (low-stock alerts, sound, daily digest).
- **Outputs:** In-app notification list; system (local) notifications; audible alert sound.
- **Acceptance Criteria:**
  - A notification centre lists real events (not a placeholder toast).
  - When "Low stock alerts" + sound are enabled, crossing reorder level raises a notification and plays a sound.
  - Notification state is per user and respects the toggles.
- **Edge Cases:** Alerts off → no sound/notification; duplicate events suppressed.
- **Note:** Cross-device *push* (FCM) requires a sender (Cloud Functions on the Blaze plan) — out of scope for the first cut; local + in-app notifications only. See Open Questions.

## 7. Non-Goals

The following are intentionally **NOT** part of this version:

- Multi-company / multi-tenant support.
- Billing, GST invoice generation, payments or accounting.
- Purchase orders and vendor management workflows.
- Barcode/QR scanning hardware integration.
- Offline-first conflict resolution (basic connectivity handling only).
- Web dashboard and iOS-specific polish.

## 8. MVP Scope

- **Must Have:** Firebase Auth (email/password) with remember-me + credential autofill;
  Firestore for items, transactions, challans, users; all screens wired to real data;
  dashboard live figures & charts; letter-pad challan PDF; in-app notifications + sound
  alerts for low stock.
- **Nice to Have:** Role gating (Admin vs Staff), challan reprint/share history,
  CSV export, FCM push notifications (with Cloud Functions).
- **Future:** reset password self-service, iOS build, barcode scanning, vendor module.

## 9. Success Metrics

- **Primary:** All inventory operations (add/edit/movement/challan) persist to the
  cloud and are visible on a second device within seconds.
- **Secondary:** Zero critical bugs on the pre-delivery test pass; challan PDF
  matches the letter pad; median stock-entry flow completes in < 30 seconds.

## 10. Constraints

- **Technical:** Must run on Android phones (min ~Android 6); Firebase only (no
  self-hosted server, per client). Flutter + Riverpod already chosen.
- **Business:** Client has no server and no IT staff; low data volume and low write rate.
- **Design:** Must use the client's logo colours and logo asset; mobile-first.
- **Timeline:** Phased delivery with client approval gate per phase (see `PHASES.md`).

## 11. Assumptions

- Client will provide Firebase project access or let us create one under their Google account.
- The 5 users are known and have company email addresses.
- The supplied `Oxen logo.jpeg` and `challan latter pad.jpeg` are the final brand assets.
- Company legal details (GSTIN, address, phone) in `mock_data.dart` are correct.

## 12. Open Questions

- Exact company email addresses for the 5 employee accounts?
- Roles: how many Admins vs Staff?
- Confirm final brand hex values (blue + green) — colours were extracted from the
  logo image, not supplied as a palette.
- Should Staff be able to delete items, or is that Admin-only?
- Should challan numbering be per-year and shared across all users?
- Notifications: do you want **cross-device push** (needs Firebase Cloud Functions / Blaze plan) or are **on-device local notifications** enough for now?
- Alert sound: use the default system notification sound, or a specific tone?
- Which events should notify: low stock only, or also challan issued / stock out / daily digest?

## 13. Definition of Done

- [ ] Requirements implemented
- [ ] Critical user flows work (sign in, item CRUD, movement, challan + PDF)
- [ ] Tests pass; build succeeds
- [ ] Security requirements satisfied (Firebase rules, no secrets in code)
- [ ] Documentation updated (`docs/`)
- [ ] Client sign-off obtained
