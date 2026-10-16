# Architecture — Oxen Energies Stock Manager

## 1. System Overview

A single Flutter (Android) app used by 5 employees. There is **no custom server**.
The app talks directly to **Firebase** (Auth + Cloud Firestore). All business
logic lives in the app; Firestore Security Rules enforce access. Data volume and
write rate are small (a few hundred documents, a handful of writes/day).

## 2. Architecture Pattern

- **Pattern:** Client-only modular monolith (feature-first Flutter app) with a
  **repository layer** over Firebase.
- **Reason:** No server to host/operate; the client has no IT staff. Firebase
  removes the backend while keeping data centralised across devices.

## 3. Technology Stack

| Concern | Technology |
|---|---|
| Frontend | Flutter (Dart, Material 3) |
| State management | Riverpod (`flutter_riverpod`) — already in use |
| Backend | Firebase (managed) |
| Database | Cloud Firestore |
| Authentication | Firebase Authentication (email/password) |
| Storage | Firebase Storage (later: challan PDFs / item photos) — optional |
| Hosting | None (mobile only) |
| Charts | `fl_chart` (already in use) |
| PDF | `pdf` + `printing` (already in use) |
| Fonts | `google_fonts` (Poppins) |
| Formatting | `intl` (already in use) |

## 4. System Components

### Frontend (Flutter)
- Screens under `lib/features/<feature>/`.
- Reusable widgets under `lib/core/widgets/`.
- Theme + tokens under `lib/core/theme/`.
- **Responsibilities:** render UI, validate input, hold ephemeral UI state.

### Repository Layer (new)
- `lib/data/repositories/*` — one repository per aggregate.
- **Responsibilities:** read/write Firestore, map documents ↔ models, expose
  streams (`Stream<List<...>>`) to Riverpod providers.
- **Rule:** UI never talks to Firestore directly; only repositories do.

### Firebase
- **Auth:** identity + session for the 5 employees.
- **Firestore:** the system of record (items, transactions, challans, users, meta).
- **Responsibilities:** persistence, sync across devices, access control via rules.

## 5. Architecture Diagram

```
User
  │
  ▼
Screens / Widgets  (features/*, core/widgets/*)
  │  reads/writes via providers
  ▼
Riverpod Providers (providers/*)  ── derived/selectors
  │  subscribe to streams / call notifiers
  ▼
Repositories (data/repositories/*)  ── model ⇄ document mapping
  │
  ▼
Firebase SDK
  ├─ Firebase Auth
  └─ Cloud Firestore
```

## 6. Data Flow (example: Stock In)

1. Staff opens **Stock In**, selects an item, enters quantity + source.
2. Screen validates input locally.
3. `MovementScreen` calls `StockNotifier.stockIn(...)`.
4. Notifier calls `ItemRepository` + `TransactionRepository` inside a Firestore
   **write batch/transaction**.
5. Firestore updates item quantity and appends a transaction with `balanceAfter`.
6. Repositories' streams emit; providers rebuild; UI updates; success toast shown.

## 7. Project Structure

```
lib/
  main.dart                 # bootstrap: Firebase.initializeApp + ProviderScope
  app.dart                  # MaterialApp + auth gate
  core/
    theme/                  # app_colors.dart, app_theme.dart
    utils/                  # formatters.dart, result.dart
    widgets/                # app_button, app_card, app_sheet, app_text_field,
                            # common, item_picker, toast
  data/
    models/                 # (move from lib/models later, optional)
    repositories/           # NEW: item_, transaction_, challan_, user_repo
  features/
    auth/                   # login_screen
    dashboard/              # dashboard_screen
    stock/                  # stock_list, item_detail, item_form, movement
    challan/                # list, form, preview, format_picker
    settings/               # settings_screen
    shell/                  # app_shell
  models/                   # stock_item, stock_transaction, challan, item_glyph
  providers/                # stock_providers.dart
  services/                 # auth_service, challan_pdf_service
assets/
  brand/                    # logo, splash, letterhead
  icon/                     # launcher icon sources
```

## 8. Dependency Rules

- Screens/widgets **must not** import `cloud_firestore` directly — go through repositories.
- Providers may depend on repositories; repositories may depend on Firebase.
- Repositories must not import Flutter widgets.
- `core/` must not import `features/`.
- Keep the existing `StockNotifier` public API stable during migration so screens change minimally.

## 9. Key Technical Decisions

- **Decision:** Use Firestore (NoSQL) rather than SQL/MySQL.
  **Context:** No server; small, document-shaped data; real-time sync desired.
  **Alternatives:** Supabase/Postgres, SQLite-on-device + manual sync.
  **Reason:** Zero ops, offline cache, real-time listeners, fits the client's constraints.

- **Decision:** Keep Riverpod; add repository layer behind it.
  **Reason:** Existing providers already isolate writes (`StockNotifier`); swap mock data for repositories with minimal UI churn.

- **Decision:** Email/password auth (not PIN) for production.
  **Reason:** 5 named employees, auditable actions; PIN flow becomes optional convenience later.

- **Decision:** Store challan lines as an embedded array inside the challan document.
  **Reason:** Lines are always read/written with their challan; no cross-challan queries.

## 10. Performance Considerations

- Use paginated/limited queries for lists; avoid loading the full transaction
  history on the dashboard (use `limit` + date filters).
- Enable Firestore offline persistence (default on mobile).
- Cache reference data (categories, company profile) in memory.

## 11. Scalability Considerations

- Single-company scale (hundreds of items, low thousands of transactions/year) —
  no sharding required.
- Index the fields used for filtering/sorting (see `DATABASE.md`).
- Keep derived values (stock value) computed in-app or with simple aggregates.

## 12. Failure Scenarios

- **Firestore unavailable / offline:** reads served from cache; writes queue and
  sync on reconnect (Firestore default). Show a subtle "offline" state; do not lose input.
- **Auth fails/timeout:** show a retryable error on Login; never fall through to demo data.
- **Partial write:** wrap multi-document writes (item + transaction + challan) in a
  Firestore transaction/batch so they succeed or fail together.
- **Duplicate challan number:** generate numbers server-side atomically via a
  counter document (transaction), not client-side sequences.
- **Rule denial:** surface a friendly "You don't have permission" message.

## Startup presentation

`main` calls `runApp` immediately. `StartupGate` renders the splash first, then
invokes the initialization callback (Firebase, followed by notifications) after
its first frame. Initialization and a 2.2-second entrance minimum run together.
`AuthGate` mounts only after initialization succeeds, preserving Firebase session
routing to Login or AppShell. Errors offer retry; no demo data or unauthenticated
shell is exposed. Repeated initialization reuses the existing Firebase app.
