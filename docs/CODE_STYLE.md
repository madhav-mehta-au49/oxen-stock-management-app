# Code Style & Conventions — Oxen Energies Stock Manager

> Keep the codebase consistent. Reuse existing patterns; make focused, readable changes.

## 1. General Principles

- Prefer readable code over clever code.
- Keep functions focused and short.
- Avoid unnecessary abstractions; the app is small.
- Reuse existing components (`core/widgets`) and utilities (`core/utils`).
- Prefer consistency over novelty.

## 2. Naming

- **Classes / widgets:** `PascalCase` (`StockListScreen`, `AppButton`).
- **Files:** `snake_case.dart` (`stock_list_screen.dart`).
- **Functions / variables:** `lowerCamelCase`.
- **Private members:** leading underscore (`_lines`, `_header`).
- **Constants:** `lowerCamelCase` (`kUnits`); `SCREAMING_SNAKE` only for true compile-time consts if needed.
- **Database fields:** `camelCase` (see `DATABASE.md`).
- **Enums:** values `lowerCamelCase` with a `label` for display (existing pattern).

## 3. Folder Structure

- Feature-first: `lib/features/<feature>/`.
- Shared UI: `lib/core/widgets/`. Theme: `lib/core/theme/`. Utils: `lib/core/utils/`.
- Data access: `lib/data/repositories/` (new). Models: `lib/models/`.
- No cross-feature imports except through `core/` or `models/`.

## 4. Imports

- Dart core, then packages, then project (relative) imports — grouped as today.
- Prefer relative imports within `lib/` for project files (current convention).
- Remove unused imports (enforced by lints).

## 5. Components

Components should:
- Have a single responsibility.
- Prefer reusable patterns (`AppButton`, `AppCard`, `AppSheet`, `AppTextField`,
  `EmptyState`, `StatusPill`, `SectionHeader`).
- Avoid duplication — if a widget appears twice, extract it to `core/widgets`.

## 6. Functions

- Do one logical thing; clear names.
- Async UI work: set `loading` state, `await`, guard with `if (!mounted) return;`
  (existing pattern — keep it).

## 7. Error Handling

- Use the existing `Result` (`ok` + `message`) for state mutations.
- Use `AppToast.success/error/info` for user feedback.
- Do not swallow exceptions silently; surface a friendly message and log the error.

## 8. Comments

- Explain **why**, tradeoffs, and non-obvious behaviour. Avoid restating code.
- Keep existing doc comments on public classes/methods.
- **Rule:** do not add comments that merely repeat the code.

## 9. Logging

- Use `debugPrint` in debug only; never log secrets/tokens/passwords.
- Log auth events, destructive actions and unexpected errors.

## 10. Formatting

- **Formatter:** `dart format`.
- **Linter:** `flutter_lints` via `analysis_options.yaml` (already configured).
- **Type checking:** `dart analyze` (must be clean; treat warnings as errors where practical).

## 11. Do

- Reuse existing patterns (widgets, providers, `Result`, toasts).
- Keep changes focused; one feature/phase at a time.
- Follow the design system (`DESIGN_SYSTEM.md`) for all UI.
- Remove dead code.

## 12. Don't

- Create duplicate utilities or near-identical widgets.
- Introduce new dependencies without a clear reason (check `pubspec.yaml` first).
- Ignore the existing architecture (UI → provider → repository → Firebase).
- Change unrelated files in a single change set.
- Store business logic in widgets; keep it in notifiers/repositories.
