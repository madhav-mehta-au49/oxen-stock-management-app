# Delivery Phases & Checklists — Oxen Energies Stock Manager

> One phase at a time. **Do not start the next phase until the current phase's
> checklist is complete and the client has approved it.** Each phase ends with a
> verification step; mark items `[x]` as they pass.

Legend: `[ ]` todo · `[x]` done · **DoD** = Definition of Done.

---

## Phase 0 — Discovery & Documentation ✅

**Goal:** Understand the blueprint + all screens; freeze scope; write the docs set.

- [x] Extract and read the Vibe Coding Blueprint PDF (31 pages).
- [x] Read every source file under `lib/` (12 screens + core + models + providers + PDF service).
- [x] Extract brand colours from `Oxen logo.jpeg` (blue + green; no orange).
- [x] Measure assets: logo 2002×2002 (wordmark ≈2.82:1); letter pad 1131×1600.
- [x] Write `PRD.md`, `DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DATABASE.md`,
      `SECURITY.md`, `CODE_STYLE.md`, `TESTING.md`, `UX_FLOWS.md`, `API.md`, `AGENTS.md`.
- [x] Write this `PHASES.md`.

**DoD:** Docs complete and client-confirmed. Open questions in `PRD.md §12` answered.

**Open items:** confirm brand hexes; 5 employee emails; role split.

---

## Phase 1 — Brand Assets & Theme ✅

**Goal:** Produce correct, sized brand assets and rebuild the theme around the logo colours.

Tasks:
- [x] Trim the logo to content bounds (1340×475) + transparent background → `assets/brand/oxen_logo.png` (exact colours).
- [x] Optional white logo variant kept for reversed use → `assets/brand/oxen_logo_white.png`.
- [x] Square 1024² master app icon — **exact coloured logo on white** → `assets/icon/oxen_app_icon.png`.
- [x] Android launcher icon set (`mipmap-mdpi…xxxhdpi`) — exact logo on white + adaptive icon (white background layer).
- [x] Native splash screen — **white background + exact coloured logo** via `launch_background.xml` (+ `values/colors.xml`).
- [x] Letter-pad asset prepared → `assets/brand/letterhead.jpg` (integration is Phase 4).
- [x] Wired assets into `pubspec.yaml`.
- [x] Rewrote `lib/core/theme/app_colors.dart` with the blue+green palette.
- [x] Updated `lib/core/theme/app_theme.dart` (primary/secondary roles, elevated button, checkbox).
- [x] Replaced the placeholder `BrandMark` with the real logo asset (dark/light variants; API preserved).
- [x] Added in-app `SplashScreen` and set it as the app entry.
- [x] Fixed contrast conflicts where the old orange/blue sat on dark surfaces (dashboard hero, FABs, challan header, toasts, login hero).
- [x] `flutter analyze` → No issues found; `flutter build apk --debug` → success.

**Verify:** ✅ Analyzer clean + debug APK builds. ⏳ Visual check on device (logo proportions, splash, launcher icon) recommended.

**DoD:** No orange anywhere; logo renders crisply; icon + splash installed. ✅ (visual device check pending)

**Note:** Used native Android splash config rather than adding `flutter_native_splash` (fewer dependencies, same result).

---

## Phase 2 — UI / Mobile-Friendliness Polish ✅

**Goal:** Every screen is comfortable on a phone, uses correct icons, and has consistent spacing.

- [x] Audited all 11 screens at **320 / 360 / 411 dp** via a new widget test (`test/mobile_layout_test.dart`) that fails on any RenderFlex overflow.
- [x] Fixed all overflows found (Login "Remember / Forgot password?" row, Stock list quantity row, Challan list meta row).
- [x] Standardised every icon to the **rounded** family (`Icons.*_rounded`) — `_outlined`/base icons converted (12 files).
- [x] Added tooltips/semantic labels to icon-only buttons (dashboard refresh/notifications, sheet close, clear-search, item menu, remove-line, error dismiss).
- [x] Increased small touch targets: `IconAction` 34→40, dashboard round buttons 40→44.
- [x] Verified long text ellipsizes (quantity row, challan meta, remember/forgot row).
- [x] Colour-coded states still pair with icon/label (stock status pills, movement arrows).
- [x] `flutter analyze` clean; full `flutter test` → **42 tests pass**; APK built + installed.

**Verify:** ✅ Automated overflow test passes at all three widths; installed on device for visual review.

**DoD:** ✅ All screens pass the automated layout check. ⏳ Human visual pass on device pending.

**Note:** The widget test uses Flutter's wide monospace test font, so it is a *conservative* stress test (wider than real Poppins) — passing it means layouts are robust even with large text scaling.

---

## Phase 3 — Reference Designs in Stitch ⏭️ Skipped

**Decision (client):** The current Flutter design is approved as-is; Stitch reference
designs are not required. Future visual changes will be handled directly in Flutter.
The Stitch MCP remains available if needed later.

- [~] Skipped by client decision — no Stitch project created.

**DoD:** N/A (skipped).

---

## Phase 4 — Challan on the Company Letter Pad ✅

**Goal:** Challan PDFs render on the supplied letter pad, not a generic layout.

- [x] Analysed `challan latter pad.jpeg` (1131×1600 = A4): header band 0–218 px,
      blank body 218–1525 px, solid footer band 1525–1600 px.
- [x] Built the letter pad as a **full-page background** (`pageTheme.buildBackground`
      + `pw.FullPage(ignoreMargins)`) and placed the challan inside the body area
      (margins: top 122, left/right 42, bottom 52 pt).
- [x] `ChallanFormat` repurposed to **`letterhead` (default)** and **`plain`**;
      picker, model default and seed data updated.
- [x] Recoloured the PDF palette to brand blue/green (removed the old orange).
- [x] Amount-in-words, totals row, remarks/terms and signature blocks retained.
- [x] Verified programmatically: A4 single page, letterhead image embedded, text
      sits in body (y 122–523), clear of header (≤115) and footer (≥802).
- [x] `flutter analyze` clean; `flutter test` → 42 pass; APK built + installed.

**Verify:** ✅ Automated PDF inspection passes. ⏳ Physical print comparison on device pending.

**DoD:** ✅ PDF is generated on the letter pad. ⏳ Print/share confirm on a real device.

**Deferred:** company fields still come from `MockData`; wiring them to
`meta/company` happens in Phase 6 (Firestore).

---

## Phase 5 — Firebase Project & Authentication ✅

**Goal:** Replace demo auth with Firebase Auth.

- [x] Firebase project **`oxen-stock-management`** already exists (client account) — used as-is.
- [x] Registered the Android app (`com.oxensolar.oxen_solar_stock`) — app id `1:270089656123:android:e5ae65d7b57aa2d3a4491e`.
- [x] `google-services.json` + `lib/firebase_options.dart` generated via FlutterFire CLI.
- [x] Gradle `com.google.gms.google-services` plugin wired (settings + app build files).
- [x] Added `firebase_core` + `firebase_auth`.
- [x] `main.dart` initialises Firebase with `DefaultFirebaseOptions`.
- [x] `AuthService` on Firebase Auth (sign in / sign out / reset email + friendly error mapping).
- [x] Auth gate in `app.dart`: Splash → Login ⇄ AppShell driven by `authStateChanges`.
- [x] Login screen rewritten: email/password only, error banner, Forgot-password → reset email; PIN + demo credentials removed.
- [x] Settings sign-out calls `AuthService.signOut()`; shows the signed-in email.
- [x] Login **"Remember me"** + **OS credential autofill** (`AutofillGroup` + `AutofillHints`; email persisted via `shared_preferences`; `finishAutofillContext()` prompts the password manager to save).
- [x] **Email/Password provider enabled** (verified: probe no longer returns config error).
- [x] **Admin account created** in Firebase Authentication (see the Firebase console).
- [x] `flutter analyze` clean; `flutter test` → 42 pass; APK builds, installs, starts with no crash.
- [ ] Remaining 4 employee accounts + `users/{uid}` profile docs (name, role, active) — Phase 6.
- [ ] Firestore Security Rules deploy + rules tests — Phase 6.

**Verify:** ⏳ sign in on the device with the admin account (kill/relaunch keeps session; wrong creds rejected).

**DoD:** ✅ Only real accounts reach the app; no demo credentials in the codebase.

---

## Phase 6 — Firestore Data Model & Repository Layer ✅

**Goal:** Replace `mock_data.dart` with live Firestore, keeping the UI stable.

- [x] Added `cloud_firestore` (+ `shared_preferences`).
- [x] Model serialization: `toMap`/`fromMap` on `StockItem`, `StockTransaction`, `Challan`/`ChallanLine`; new `AppUser`, `CompanyProfile`.
- [x] Repositories: `ItemRepository`, `TransactionRepository`, `ChallanRepository`, `UserRepository`, `MetaRepository` (`lib/data/repositories/`).
- [x] Providers now compose live stream data; the `StockNotifier` API is preserved (now async) so screens changed minimally.
- [x] Atomic writes via Firestore transactions: stock in/out, quantity-edit adjustment, and challan issue (deduct + ledger + challan together).
- [x] Atomic challan numbering via `meta/counters` (`OX/CH/<year>/NNNN`).
- [x] Bootstrap on sign-in: creates `users/{uid}` (first user = admin) and seeds `meta/company`.
- [x] Firestore Security Rules written (`firestore.rules`) + **deployed**.
- [x] `flutter analyze` clean; `flutter test` → 41 pass; APK builds, installs, starts with no crash.
- [ ] Composite indexes — current queries avoid them (single-field only); add if new filters are introduced.
- [ ] Device verification of live writes (data persists across restart, visible in the console).

**Verify:** ⏳ sign in → add item → stock in/out → create challan → reopen app (data persists) → check Firebase Console.

**DoD:** ⏳ All screens run on real data (device verification pending).

---

## Phase 7 — Challan, Reporting & Settings on Real Data 🚧 Partly done

- [x] Dashboard totals / chart / activity computed from Firestore streams.
- [x] Item ledger + full ledger from `transactions`.
- [x] Challan list search expanded (number, customer, site, address, contact, vehicle, notes, item names/SKU) + sort (newest/oldest/customer/value).
- [x] Settings toggles **persisted** per user (`settings/{uid}`).
- [x] **Default challan format** picker works and is applied to new challans.
- [x] Company profile editable (admin) → `meta/company`.
- [x] **Product photos (free)**: picked via camera/gallery, compressed on-device, thumbnail base64 in `items.imageThumb`, full image in `itemImages/{id}`; category icon is the fallback. No Firebase Storage.
- [ ] Role gating in UI (hide admin-only actions from staff/viewer).

## Phase 8 — Notifications & Sound Alerts 🚧 Partly done

- [x] `flutter_local_notifications` added (+ core-library desugaring) and initialised in `main`.
- [x] Android notification channel + `POST_NOTIFICATIONS` permission request.
- [x] **Low-stock alerts**: sound + system notification when an item crosses its reorder level; respects the Settings toggle; fires only on transition (no spam).
- [x] **In-app notification centre** (bell + unread badge + list + tap-through + mark-seen), fed by low-stock, challan-issued and daily-summary events.
- [x] **Daily stock summary**: configurable time (default **08:00**), delivered on the first app open after that time, with a **Preview now** action. (No server needed.)
- [ ] Cross-device FCM push — deferred (needs Cloud Functions / Blaze).

---

## Phase 9 — Full Testing & QA

**Goal:** Prove it works before delivery.

- [ ] `flutter analyze` → 0 issues; `dart format` clean.
- [ ] `flutter test` → unit + widget tests pass.
- [ ] Firebase emulator + rules tests pass.
- [ ] Manual QA checklist (`TESTING.md §9`) on a real device, all screens.
- [ ] Critical flows: sign-in, item CRUD, stock in/out (incl. override), challan + PDF, sync, offline.
- [ ] Test on a low-end phone and a tablet/wide layout.
- [ ] Verify no secrets committed; `pubspec` dependencies reviewed.
- [ ] Fix all blocking bugs; log non-blocking ones.

**Verify:** build a release APK; install fresh; complete a full business day of operations.

**DoD:** All `TESTING.md §8` boxes ticked; client performs a successful UAT run.

---

## Phase 10 — Delivery & Handover

- [ ] Build release `appbundle`/`apk` (signed) with correct app name, icon, version.
- [ ] Populate the real initial stock + the 5 accounts; initialise challan counter.
- [ ] Finalise `docs/` (docs match shipped behaviour).
- [ ] Deliver APK/AAB + docs + a short user guide (Sign in, Stock In/Out, Challan, View ledger).
- [ ] Walk through deployment (Play Console internal testing / direct APK) with the client.
- [ ] Record known limitations and future work.
- [ ] Obtain final sign-off.

**DoD:** Client has a working, signed build, the docs, and a walkthrough.

---

## Progress Tracker

| Phase | Name | Status |
|---|---|---|
| 0 | Discovery & Documentation | ✅ Done |
| 1 | Brand Assets & Theme | ✅ Done |
| 2 | UI / Mobile polish | ✅ Done |
| 3 | Stitch reference designs | ⏭️ Skipped |
| 4 | Challan letter pad | ✅ Done |
| 5 | Firebase Auth | ✅ Done |
| 6 | Firestore + repositories | ✅ Done |
| 7 | Reporting & settings on real data | ⏳ Next |
| 8 | Notifications & sound alerts | ⬜ |
| 9 | Full testing & QA | ⬜ |
| 10 | Delivery & handover | ⬜ |

## Requested maintenance — animated splash refresh (October 2026)

- [x] Designed a white splash with the original unframed transparent wordmark.
- [x] Implemented fade/rise, energy-line reveal, gradient loader and reduced motion.
- [x] Fixed skipped splash by drawing before initialization with a 2.2-second minimum.
- [x] Added retry for startup/auth errors and Android 12+ handover configuration.
- [x] Analyzer clean; full widget suite: 49 passed. Splash suite after landscape refinement: 6 passed.
- [x] Release APK built successfully (61.5 MB), using invocation-only Kotlin incremental-cache workaround.
- [ ] Human cold-launch review on an Android device.
