# Database — Oxen Energies Stock Manager (Cloud Firestore)

> Engine: **Cloud Firestore** (NoSQL document store) · Hosting: **Firebase (Google Cloud)**
> Source of truth for the data model. Do not invent collections/fields in code
> without updating this file.

## 1. Database Engine

- **Database:** Cloud Firestore (Native mode).
- **Hosting:** Firebase project owned by the client (Google account).
- **Region:** `asia-south1` (Mumbai) — closest to Jamnagar, Gujarat.

## 2. Naming Conventions

- **Collections:** `snake_case`, plural (`items`, `transactions`, `challans`, `users`, `meta`).
- **Document fields:** `camelCase` (`purchasePrice`, `reorderLevel`, `balanceAfter`).
- **Document IDs:** human-readable where useful (`ITM-001`, challan `OX-CH-2026-0001`),
  otherwise Firestore auto-ID.
- **Timestamps:** Store as Firestore `Timestamp`; convert to `DateTime` at the model boundary.
- **Money:** Store as `number` (double) in INR. Quantity/reorder as `number` (int).

## 3. Collections

### `users`
- **Purpose:** Employee profile + role, keyed by Firebase Auth `uid`.
- **Document id:** Auth `uid`.
- **Fields:** `email` (string), `name` (string), `role` ("admin" | "staff" | "viewer"),
  `active` (bool), `createdAt` (timestamp), `updatedAt` (timestamp).
- **Note:** Auth credentials live in Firebase Auth, **not** here.

### `items`
- **Purpose:** Inventory master.
- **Document id:** `ITM-###` (e.g. `ITM-001`).
- **Fields:** `name`, `category` (string enum), `sku`, `unit`, `quantity` (int),
  `reorderLevel` (int), `purchasePrice` (double), `sellingPrice` (double),
  `supplier`, `glyphKey`, `rack`, `unitNos`,
  `createdAt` (timestamp), `updatedAt` (timestamp),
  `createdBy` (uid), `updatedBy` (uid).
- **Category values:** `panels | inverters | batteries | cables | mounts | lighting | accessories`.

### `transactions`
- **Purpose:** Immutable stock ledger; the audit trail.
- **Document id:** auto-ID (keep a `code` field like `TXN-0001` for display).
- **Fields:** `itemId`, `itemName`, `itemSku` (denormalised for display),
  `type` ("stockIn" | "stockOut" | "challanOut" | "adjustment"),
  `quantity` (int; signed for adjustment), `balanceAfter` (int),
  `date` (timestamp), `party`, `reference`, `notes`, `user` (name), `userUid`,
  `createdAt` (timestamp).
- **Note:** Transactions are append-only; never edit or delete (except cascade on item delete — see §8).

### `challans`
- **Purpose:** Delivery challans; deduct stock on issue.
- **Document id:** `OX-CH-<year>-<seq>` (file-safe form of the display number).
- **Fields:** `number` (display, `OX/CH/<year>/NNNN`), `customerName`, `siteName`,
  `address`, `contact`, `vehicleNo`, `date` (timestamp), `status` ("draft" | "issued"),
  `notes`, `preparedBy` (name), `preparedByUid`, `format` ("standard" | "classic"),
  `totalUnits` (int), `totalValue` (double),
  `lines` (array of objects), `createdAt` (timestamp).
- **`lines[]` shape:** `{ itemId, itemName, sku, unit, quantity, rate, availableBefore }`.

### `meta` (system documents)
- `meta/counters` — `{ challanYear, challanSeq }` for atomic challan numbering.
- `meta/company` — `{ name, tagline, address, phone, gstin, letterheadEnabled }`
  (drives challan PDF + Settings "Company profile").

### `settings` (per user, optional)
- **Document id:** Auth `uid`.
- **Fields:** `lowStockAlerts` (bool), `dailyDigest` (bool), `autoRefresh` (bool),
  `defaultChallanFormat` ("standard" | "classic").

### `skuIndex` (uniqueness guard)
- **Purpose:** Atomic unique-SKU enforcement (Firestore has no unique constraint).
- **Document id:** the SKU (uppercased).
- **Fields:** `itemId` (string), `sku` (string).
- **Rule:** created/updated/deleted in the **same transaction** as the item write, so duplicate SKUs cannot be saved even with concurrent users.

### `itemImages` (product photos — free storage)
- **Purpose:** Full-size product photo stored as base64 (no Firebase Storage / Blaze needed).
- **Document id:** the item id.
- **Fields:** `data` (base64 JPEG string), `updatedAt` (timestamp).
- **Note:** a small thumbnail (base64) is embedded in the `items` doc as `imageThumb` for fast list rendering; the full image loads lazily on the detail screen.

## 4. Relationships

- `items` 1 → many `transactions` (by `itemId`).
- `items` 1 → many `challans.lines` (by `line.itemId`, embedded).
- `users` 1 → many `transactions` / `challans` (by `userUid` / `preparedByUid`).
- No cross-document cascades except item delete (see §8).

## 5. Constraints

- **Required:** `items.name`, `items.category`, `items.unit`, `items.quantity`,
  `items.reorderLevel`; `challans.number`, `challans.customerName`, `challans.lines` (≥1);
  `transactions.type`, `transactions.itemId`, `transactions.quantity`.
- **Unique:** `items.sku` (enforced in-app + rules on create); `challans.number`.
- **Foreign keys (logical, enforced by app):** `transactions.itemId` → `items`;
  `challans.lines[].itemId` → `items`.
- **Value ranges:** `quantity ≥ 0` (items), `quantity > 0` (new transactions),
  `reorderLevel ≥ 0`, prices ≥ 0.

## 6. Indexes

| Index | Reason |
|---|---|
| `transactions`: `itemId` ASC, `date` DESC | Item ledger. |
| `transactions`: `date` DESC | Dashboard recent activity / chart. |
| `items`: `category` ASC, `name` ASC | Category filter + sort. |
| `items`: `quantity` ASC | Low-stock view. |
| `challans`: `status` ASC, `date` DESC | Challan list filter. |
| `challans`: `date` DESC | Default challan ordering. |
| `challans.lines.itemId` (array) | Find challans referencing an item (delete safety). |

## 7. Data Validation

- Enforce in **both** app (form validators) and rules/server (`SECURITY.md`).
- Name ≥ 3 chars; quantities integers; money ≥ 0; enum fields restricted to allowed values.
- `balanceAfter` must equal the item's quantity after applying the transaction.
- Challan issue must not drive any item below 0 unless an admin override flag is set.

## 8. Soft Delete

- **Items:** delete is **hard** in the MVP (removes item + its transactions +
  strips it from challan lines), matching current app behaviour. Revisit soft
  delete (`deletedAt`, `isDeleted`) if the client wants history preserved — see Open Questions.
- **Transactions:** never deleted individually (append-only ledger).
- **Challans:** issued challans are immutable; no delete in MVP.

## 9. Auditing

- **Created by / Updated by:** store `createdBy` / `updatedBy` (uid) on `items`;
  `userUid` on `transactions`; `preparedByUid` on `challans`.
- **Activity history:** the `transactions` collection *is* the stock activity history.
- Keep `createdAt`/`updatedAt` on mutable documents.

## 10. Sensitive Data

- **Sensitive fields:** employee emails, roles.
- **Protection:** only authenticated + `active` users may read `users`; only `admin`
  may write `users` and `meta/company`. See `SECURITY.md`.
- No passwords or secrets are ever stored in Firestore (Auth handles credentials).

## 11. Migration Rules

Schema changes must: 1) be documented here, 2) ship a migration/backfill script or
code path, 3) be tested against a staging project, 4) avoid breaking existing data.
Because the app starts from an empty database, the first "migration" is the seed below.

## 12. Seed Data

- **Company profile:** `meta/company` from `mock_data.dart` (Oxen Energies, tagline,
  address, phone, GSTIN).
- **Users:** create the 5 employee accounts in Firebase Auth + `users` docs (names/roles from client).
- **Items:** optionally seed the 16 demo items from `mock_data.dart` for the client
  demo/UAT, then replace with real stock before go-live.
- **Counters:** initialise `meta/counters.challanSeq` to the current YTD challan count.

## Open Questions (data)

- Hard vs soft delete for items?
- Are multiple warehouses/locations needed (`rack` suggests one location today)?
- Do we need a `customers` collection instead of free-text customer names?
