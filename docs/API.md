# API Documentation — Oxen Energies Stock Manager

> There is **no custom HTTP API**. The "API" is Cloud Firestore accessed through
> the repository layer. This file documents the data access contracts the app
> depends on. UI code must never call Firestore directly.

## Conventions

- **Base:** Firestore project (client's Firebase project).
- **Auth:** Firebase Auth token (implicit on every Firestore call).
- **Versioning:** N/A (mobile app ships its own schema version).
- **Error format:** Firebase exception → mapped to `Result` (`ok=false`, friendly `message`).
- **Pagination:** `limit()` + advisory queries; `startAfterDocument` for large lists.
- **Real-time:** `snapshots()` streams for live lists.

## Repository contracts (Dart)

### ItemRepository

- `Stream<List<StockItem>> watchItems()` — live item list.
- `Future<StockItem?> getItem(String id)`.
- `Future<Result> upsertItem(StockItem item)` — create or update; writes an
  `adjustment` transaction if quantity changed.
- `Future<Result> quickAddItem({name, sku, category, unit, ...})` — rejects duplicate SKU.
- `Future<Result> deleteItem(String id)` — admin; cascades (ledger + challan lines).

### TransactionRepository

- `Stream<List<StockTransaction>> watchByItem(String itemId)` — item ledger.
- `Stream<List<StockTransaction>> watchRecent(int limit)` — dashboard.
- `Future<Result> stockIn({itemId, quantity, source, reference, date, notes})`.
- `Future<Result> stockOut({itemId, quantity, party, reference, date, notes, adminOverride})`.
- Writes run inside a Firestore transaction together with the item quantity update
  so `balanceAfter` is always consistent.

### ChallanRepository

- `Stream<List<Challan>> watchChallans({ChallanStatus? status})`.
- `Future<Challan?> getByNumber(String number)`.
- `Future<String> nextChallanNumber()` — atomic via `meta/counters`.
- `Future<Result> issueChallan(Challan challan)` — batch: validates stock, deducts
  each line, appends `challanOut` transactions, marks challan Issued.
- `Future<Result> setFormat(String number, ChallanFormat format)`.

### UserRepository

- `Future<AppUser?> currentUser()` — profile + role for the signed-in uid.
- `Stream<List<AppUser>> watchUsers()` — admin.
- `Future<Result> upsertUser(AppUser user, {role, active})` — admin.

### MetaRepository

- `CompanyProfile getCompany()` / `Stream<CompanyProfile>` — `meta/company`.
- `Future<Result> saveCompany(CompanyProfile)` — admin.

## Error / status mapping

| Situation | App behaviour |
|---|---|
| Unauthenticated | Redirect to Login |
| Permission denied | Toast "You don't have permission" |
| Offline | Serve cache; queue writes; subtle offline hint |
| Not found | Empty state ("Item not found") |
| Validation error | Inline field error (no write) |
| Unknown error | `AppToast.error` with generic message; log details |

## Validation rules (mirrored in Firestore rules)

- `items`: `name.length >= 3`, `quantity >= 0`, `reorderLevel >= 0`, prices >= 0, category in enum.
- `transactions`: `quantity > 0` on create; `type` in enum; immutable.
- `challans`: `lines.length >= 1`; `number` unique; per-line `quantity > 0`.

## Tests (per contract)

For each write method: success case, invalid input, unauthenticated, forbidden
(wrong role), and a retry/idempotency consideration for challan issuing.
