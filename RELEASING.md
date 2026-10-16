# Releasing & Auto-Update (Android APK via GitHub Releases)

This app is distributed **directly as an APK** (not on Google Play). Installed
apps check **GitHub Releases** for a newer version and offer an in-app update.
There is no server and no credential embedded in the app (the repo is public).

---

## How it works

1. You push a version tag (e.g. `v1.0.2`).
2. GitHub Actions (`.github/workflows/release.yml`) verifies the tag matches
   `pubspec.yaml`, runs analyze + tests, builds a **signed** release APK and
   creates a GitHub Release with the APK attached (`oxen-energies-v1.0.2.apk`).
3. The installed app calls `api.github.com/.../releases/latest`, compares the
   version (semver, `v`-prefix optional, drafts/prereleases ignored) and, if
   newer, shows an **Update available** dialog → downloads over HTTPS →
   launches Android's installer (content:// via FileProvider).

Everything is best-effort: if GitHub is unreachable or anything fails, the app
opens normally.

---

## One-time setup

### 1. Release keystore
A dedicated release keystore was created (kept **outside** the repo, e.g.
`D:\office work\oxen-keys\oxen-release.jks`). Keep it safe and **never commit it**.

- Alias: `oxen`
- Store/key password: (stored separately — see your password manager / secrets)
- SHA-256: `0E:76:18:51:B4:DE:F7:62:F6:52:4D:79:CC:C1:9E:66:08:A4:5D:83:D0:27:98:91:42:B7:53:DB:21:B1:E6:FC`

> ⚠️ **Important:** APKs already installed with the old **debug** key cannot be
> updated in place. Those devices need a **one-time uninstall + reinstall** of a
> release-signed build. Every update after that installs in place.

### 2. GitHub Secrets
Repository → Settings → Secrets and variables → Actions → add:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | base64 of the `.jks` file |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | `oxen` |
| `KEY_PASSWORD` | key password |

Generate the base64 (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\office work\oxen-keys\oxen-release.jks")) | Set-Clipboard
```

### 3. Local release builds (optional)
Already configured via `android/key.properties` (git-ignored). `flutter build apk --release`
is signed with the release key locally. In CI the same file is generated from Secrets.

---

## Publishing a new version

The **first** release is `1.0.0` (already set in `pubspec.yaml`):

```bash
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

For every release **after** that, bump the version first:

```bash
# 1. Bump version (versionName AND versionCode must both increase)
#    pubspec.yaml:  version: 1.0.1+2
# 2. Commit
git add -A
git commit -m "Release 1.0.1"

# 3. Tag (tag name must equal the versionName, optional "v" prefix)
git tag v1.0.1

# 4. Push
git push origin main
git push origin v1.0.1
```

GitHub Actions then builds and publishes the release. Existing installs detect
`1.0.2` and offer the update.

> The workflow **fails** if the tag and `pubspec.yaml` version differ, so you
> can never publish a mis-versioned APK.

---

## Testing the updater

- **Installed = latest** → no dialog.
- **Newer release exists** → dialog appears a few seconds after login (once per session).
- **GitHub down / no release** → app opens normally (check is swallowed).
- **Download fails** → error toast; retry.
- **"Install unknown apps" disabled** → app explains and opens the Android setting.
- **Successful update** → Android installs in place (same package ID + cert).

To force-test without a real release: temporarily lower the installed version
(build with an older `pubspec.yaml` version) or publish a draft-free test tag.

---

## Limitations

- Update delivery happens **when the app is opened** (no background push).
- Only **APKs** from this repo's releases are accepted; HTTPS only; the download
  is validated (ZIP/APK magic bytes) before the installer is launched.
- The repository is **public**, so the source is publicly visible. If you later
  make it private, move the APK to a separate **public releases-only** repository
  and point `GitHubUpdateService` at it (do **not** embed a token in the app).
