# Testing Strategy — Oxen Energies Stock Manager

> Do not stop at "the code looks correct." Run the app and verify the critical journeys.

## 1. Testing Goals

Critical functionality:
- Authentication (sign in / sign out / session).
- Stock in / out with balance integrity.
- Item create / edit / delete.
- Challan create → stock deduction → PDF on the letter pad.
- Dashboard figures computed from real data.

## 2. Test Types

### Unit Testing
- Formatters (`Fmt`), `Result`, and pure business logic in `StockNotifier`
  (e.g. `stockOut` rejects over-draw; `upsertItem` writes an adjustment row).
- Model mapping (document ⇄ `StockItem` / `Challan`).

### Integration Testing
- Repository ↔ Firestore against the **Firebase Emulator Suite** (Auth + Firestore).
- Firestore **Security Rules** unit tests (`@firebase/rules-unit-testing`).

### End-to-End / Manual (device)
- Sign in → add item → stock in → stock out → create challan → generate/share PDF →
  verify stock deducted → replica on a second device reflects the change.

## 3. Testing Tools

- **Unit / Widget:** `flutter_test` (already present).
- **Integration:** `integration_test` + Firebase Emulator Suite.
- **Rules:** Firebase Emulator + `@firebase/rules-unit-testing`.
- **Manual:** Android device/emulator checklist (below).

## 4. Test File Structure

```
test/
  unit/            # notifier, formatters, mappers
  widget/          # screen/widget tests
integration_test/  # emulator-backed flows
```

## 5. Critical User Flows

- **Flow: Sign in** — enter valid creds → arrives at Dashboard; invalid → error banner.
  Expected: only authenticated users reach the shell.
- **Flow: Stock In** — select item, qty 10, confirm → quantity +10, ledger row, balance matches.
- **Flow: Stock Out over-draw** — request > available → blocked; enable admin override → allowed.
- **Flow: Challan** — add 2 lines → confirm → stock deducted by line qty; challan status Issued;
  PDF renders on letter pad; reprint works.
- **Flow: Realtime sync** — change on device A; device B updates without manual refresh.
- **Flow: Offline** — go offline, make a stock-in, reconnect → write syncs, no data loss.

## 6. Coverage

- **Target:** focus on critical business logic and data mutations (not a raw % target).
- Prioritise: authentication, stock mutations, challan issuing, delete cascade, rules.

## 7. Commands

- **Analyze:** `flutter analyze`
- **Test:** `flutter test`
- **Format:** `dart format .`
- **Build (Android):** `flutter build apk --release` (or `flutter build appbundle`)
- **Emulators:** `firebase emulators:start`

## 8. Definition of Done

- [ ] Tests pass (`flutter test`)
- [ ] Build passes (`flutter build apk`)
- [ ] Lint/analyze passes (`flutter analyze` — 0 issues)
- [ ] Critical flows verified on a real device
- [ ] No blocking errors on any screen
- [ ] Firestore rules tests pass

## 9. Manual QA Checklist (per release)

- [ ] Every screen opens at 360 dp width without overflow (no yellow/black stripes).
- [ ] Bottom nav reaches all 4 tabs; back navigation behaves.
- [ ] Long lists scroll; empty states appear when there is no data.
- [ ] Loading indicators show during network writes; buttons disable while working.
- [ ] Toasts read correctly (success/error/info).
- [ ] Challan PDF prints and shares; letterhead correct on page 1.
- [ ] Sign out → Login; re-login restores state.
