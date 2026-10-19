# AGENTS.md

This repository uses the documentation set in [`docs/`](./docs). Before making
significant changes, read the relevant documents there.

**Project:** Oxen Energies Stock Manager — a Flutter (Android) inventory +
delivery-challan app for a solar equipment supplier, backed by Firebase
(Authentication + Cloud Firestore). No custom server.

## Read first (in order)

1. `docs/PRD.md` — requirements, scope, acceptance criteria.
2. `docs/PHASES.md` — the current phase and its checklist (**work one phase at a time**).
3. `docs/DESIGN_SYSTEM.md` — colours (brand blue + green from the logo), type, spacing, icons.
4. `docs/ARCHITECTURE.md` — layering: UI → provider → repository → Firebase.
5. `docs/DATABASE.md` — Firestore schema and indexes.
6. `docs/SECURITY.md` — auth, roles, Firestore rules.
7. `docs/CODE_STYLE.md` — conventions.
8. `docs/TESTING.md` — how to validate.
9. `docs/UX_FLOWS.md` — user journeys and states.
10. `docs/API.md` — repository contracts.
11. `docs/AGENTS.md` — detailed agent instructions.

## Quick rules

- Reuse existing widgets/utilities; follow the design system.
- UI never talks to Firestore directly — go through `lib/data/repositories/` and providers.
- Keep business logic out of widgets.
- Do not invent requirements; open questions are listed in `docs/PRD.md §12`.
- Do not commit secrets or demo credentials to release builds.
- Before finishing: `flutter analyze` (clean), `dart format`, `flutter test`, and update docs + `docs/PHASES.md`.

## Current status

Phases 0–2 and 4–6 are complete; Phase 3 (Stitch) was skipped by client decision.
Firebase Auth + Firestore are live (`oxen-stock-management`). The client's
GST/Wp/customers/challan-edit work is implemented (dynamic categories with GST,
HSN-free panel Wp pricing, customers master, Bill/Ship To, 2-decimal prices,
round-off, challan edit/cancel). **Next: full QA pass + release 1.0.3.**
See `docs/PHASES.md`.
