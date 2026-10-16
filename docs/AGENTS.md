# AI Coding Agent Instructions (docs) — Oxen Energies Stock Manager

> This file lives in `docs/`. The repository-root `AGENTS.md` points here.
> These are operational instructions for any AI/code agent working on this project.

## 1. Project Context

- **Project:** Oxen Energies Stock Manager
- **Purpose:** Mobile inventory + delivery-challan app for a solar equipment supplier (single company, 5 employees).
- **Primary Users:** Store Manager (admin), Store Staff (staff), Owner/Accounts (viewer).
- **Stack:** Flutter + Riverpod + Firebase (Auth + Firestore). No custom server.

## 2. Source of Truth

Before significant changes, read the relevant docs **in `docs/`**:

- `PRD.md` — what and why, scope, acceptance criteria.
- `DESIGN_SYSTEM.md` — colours, type, spacing, icons, components.
- `ARCHITECTURE.md` — structure, layering, dependency rules.
- `DATABASE.md` — Firestore collections/fields/indexes.
- `SECURITY.md` — auth, roles, rules.
- `CODE_STYLE.md` — conventions.
- `TESTING.md` — validation.
- `UX_FLOWS.md` — journeys + states.
- `API.md` — repository contracts.
- `PHASES.md` — the current phase and checklist.

Do not contradict these documents without first identifying the conflict.

## 3. General Rules

- Understand existing code before modifying it.
- Reuse existing components (`core/widgets`) and utilities (`core/utils`).
- Follow the design system, architecture, database conventions, security requirements and code style.
- Do not invent business requirements — raise open questions instead.
- Do not expose secrets (no demo credentials in release builds).
- Avoid unnecessary dependencies.
- Avoid unrelated changes; keep diffs focused.

## 4. Planning

Before a non-trivial task: 1) read the relevant docs, 2) read the relevant code,
3) list affected files, 4) list dependencies, 5) note DB/API changes, 6) note tests
required, 7) write a concise plan. Work **one phase at a time** per `PHASES.md`.

## 5. Implementation

- Make focused changes; reuse established patterns (Riverpod providers, `Result`,
  `AppToast`, existing widgets).
- Preserve existing behaviour; avoid unnecessary rewrites.
- Keep business logic in notifiers/repositories, not widgets.
- UI must go through providers/repositories — never call Firestore from widgets.

## 6. Validation

After implementation: run `flutter analyze`, `dart format`, `flutter test`, and
(release) `flutter build apk`. Review changed files; check for unintended edits.

## 7. Documentation

Update docs when behaviour changes: product scope (`PRD.md`), architecture,
database schema, repository contracts (`API.md`), security rules, conventions.
Tick the relevant boxes in `PHASES.md`.

## 8. Conflict Handling

If requirements conflict, do not guess — identify the conflict and ask for
clarification. Known open questions live in `PRD.md §12` and `DATABASE.md`.

## 9. Completion Criteria

A task is complete only when: requirements are satisfied, `flutter analyze` is
clean, tests pass, the build succeeds, no unintended files changed, security rules
are respected, and docs are updated.
