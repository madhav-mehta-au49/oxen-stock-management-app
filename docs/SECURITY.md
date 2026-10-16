# Security — Oxen Energies Stock Manager

> Security is a project requirement. Firebase config values in the app are
> **not** secrets; access is protected by Firebase Auth + Firestore Rules.

## 1. Authentication

- **Authentication Provider:** Firebase Authentication.
- **Methods:** Email/password (primary). Self-service password reset (secondary).
- **Rules:**
  - No unauthenticated access to any screen beyond Login (auth gate in `app.dart`).
  - Accounts are created by an **admin** (no public sign-up for this internal tool).
  - Session persists across app restarts (Firebase default); sign-out clears it.
  - The demo constructor credentials in `auth_service.dart` are **removed** from production builds.

## 2. Authorization

- **Roles:** `admin`, `staff`, `viewer`.
- **Permissions:**

### Admin
- Everything staff can do.
- Create/deactivate users and set roles.
- Edit company profile (`meta/company`).
- Delete items; use admin override to issue below-zero stock.

### Staff
- Create/edit items, record movements, create/issue challans, edit own device settings.

### Viewer
- Read-only: dashboard, item list, ledger, challan history. No writes.

- **Enforcement:** Authorization is enforced in **Firestore Security Rules**
  (server-side). UI gating (hiding buttons) is a convenience only, never the control.

## 3. Secrets

- Never hard-code credentials, API keys for privileged services, or service-account JSON.
- Never commit production secrets (add to `.gitignore`).
- Never expose private secrets to the client app.
- Firebase client config (`google-services.json` / `firebase_options.dart`) is
  acceptable in the app but must be accompanied by restrictive rules.
- Rotate any leaked credential immediately; enable Firebase App Check in production.

## 4. Environment Variables

- **Public (safe in app):** `firebase_options.dart` values (apiKey, appId, projectId,
  messagingSenderId, storageBucket) — safe *only with* correct rules + App Check.
- **Private (never in repo):** none required for MVP (no admin SDK / service accounts in this repo).

## 5. API Security

There is no custom API; Firestore rules act as the API boundary.

- **Input validation:** client validators + rules; reject unknown/over-range fields.
- **Rate limiting:** Firebase platform-level; acceptable for 5 users.
- **CORS:** N/A (mobile).
- **Authentication:** every rule requires `request.auth != null`.
- **Authorization:** role lookup via `users/{uid}.role`; write rules check role + ownership.

## 6. Data Protection

- **Sensitive data:** employee emails, roles, company GSTIN.
- **Encryption:** in transit (TLS by default); at rest (Google-managed) — no extra config.
- **Retention:** keep ledger history; no automatic deletion.
- **Deletion:** only admin; cascades as defined in `DATABASE.md`.

## 7. Logging

- **Never log:** passwords, tokens, full auth payloads, sensitive personal data.
- **Log:** authentication events (success/failure), destructive actions (delete),
  permission denials, unexpected errors.
- Do not print secrets to `debugPrint`/console in release builds.

## 8. File Uploads

- **MVP:** none (no item photos; challan PDFs are generated in-app and shared,
  not uploaded). If Firebase Storage is added later:
  - Allowed types: `image/jpeg`, `image/png`, `application/pdf`.
  - Max size: e.g. 5 MB per file.
  - Validate content type + size in rules; scope paths per company/user.

## 9. Deployed Firestore Rules

The live rules live in [`firestore.rules`](../firestore.rules) and are deployed with
`firebase deploy --only firestore:rules`.

For the first cut (a trusted 5-person team) the policy is:
- All access requires `request.auth != null` (no anonymous access).
- `users/{uid}`: any signed-in user may read; you may create/update your **own**
  doc; admins manage everyone.
- `items`, `transactions`, `challans`, `meta`: any **active** signed-in employee
  may read/write.
- `settings/{uid}`: only the owner.
- Everything else: denied.

> This is intentionally permissive for internal use and is tightened with real
> roles once all 5 employee profiles exist (role-based checks are already
> scaffolded as `isAdmin()`). Review before public release.

### Earlier starter (reference)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function signedIn() { return request.auth != null; }
    function profile()  { return get(/databases/$(db)/documents/users/$(request.auth.uid)).data; }
    function active()   { return signedIn() && profile().active == true; }
    function isAdmin()  { return active() && profile().role == 'admin'; }
    ...
  }
}
```

## 10. Security Checklist

- [ ] Authentication implemented (Firebase Auth, no demo creds in release)
- [ ] Authorization implemented (rules + roles; verified by rules tests)
- [ ] Server-side validation (rules reject invalid/over-range writes)
- [ ] Secrets protected (nothing sensitive committed)
- [ ] Sensitive data protected (users/meta gated by role)
- [ ] Rate limiting considered (platform-level; App Check enabled)
- [ ] File uploads validated (N/A in MVP; documented for later)
- [ ] Errors do not expose sensitive details (friendly messages)
- [ ] Dependencies reviewed (`flutter pub outdated`, advisories)
