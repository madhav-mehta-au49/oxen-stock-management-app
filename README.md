# Oxen Energies — Stock Manager

A Flutter (Android) inventory and delivery-challan app for a solar-equipment
supplier. Backed by Firebase (Authentication + Cloud Firestore). No custom
server.

## Features

- Email/password sign-in with "Remember me" and OS password-manager autofill
- Live inventory: items, stock in/out, per-item ledger (Firestore, real time)
- Delivery challans with PDF rendered on the company letter pad
- Dashboard with live figures and 7-day / 30-day movement charts
- Low-stock notifications, in-app notification centre, and a daily summary
- Optional product photos stored free in Firestore (thumbnails + lazy full image)
- In-app self-update via GitHub Releases (no store, no server)

## Stack

Flutter 3.41 · Riverpod · Firebase Auth + Cloud Firestore · `pdf`/`printing`
· `flutter_local_notifications`

## Getting started

```bash
flutter pub get
flutter run
```

## Documentation

See [`docs/`](./docs) — PRD, design system, architecture, database, security,
testing, UX flows, phases, and agent instructions.

## Releasing

See [`RELEASING.md`](./RELEASING.md) for building and publishing a new version.
