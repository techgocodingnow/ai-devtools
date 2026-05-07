# Release pipeline

Tag-driven flow. Push `vX.Y.Z` → CI builds, signs, notarizes, staples, attaches DMG, generates changelog, creates GitHub Release.

## One-time setup (repo secrets)

Configure under **Settings → Secrets and variables → Actions**:

| Secret | Source |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i DeveloperID.p12` (Developer ID Application cert exported from Keychain Access). |
| `P12_PASSWORD` | Password set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any random string. CI uses it for an ephemeral keychain. |
| `NOTARY_APPLE_ID` | Apple ID email used for notarization. |
| `NOTARY_TEAM_ID` | `L23PD654Q3`. |
| `NOTARY_PASSWORD` | App-specific password from appleid.apple.com. |

### Generating the certificate

1. Keychain Access → Certificate Assistant → Request Certificate from CA.
2. Apple Developer portal → Certificates → `+` → **Developer ID Application**, upload the CSR.
3. Download `.cer`, double-click to install. Right-click the cert → Export → `.p12` with a strong password.
4. `base64 -i DeveloperID.p12 | pbcopy` → paste into `BUILD_CERTIFICATE_BASE64`.

## Local dry-run (recommended before tagging)

Mirror CI locally to catch signing / notarization failures before burning a tag.

### Setup once

```bash
brew install create-dmg jq

# Local .env (gitignored) — same values as GitHub secrets:
cat > .env <<'EOF'
BUILD_CERTIFICATE_BASE64=...
P12_PASSWORD=...
EOF

# Import Developer ID cert into login keychain:
scripts/import-cert.sh

# Store notary credentials in keychain:
xcrun notarytool store-credentials AI_DEVTOOLS_NOTARY \
  --apple-id "<apple-id>" \
  --team-id "L23PD654Q3" \
  --password "<app-specific-password>"
```

### Run

```bash
scripts/release-local.sh                  # build + sign + verify + dmg (no Apple round-trip)
scripts/release-local.sh --notarize       # full pipeline incl. notary submit
scripts/release-local.sh --notarize --staple   # full + staple ticket (matches CI)
```

What it catches:

- Missing Developer ID cert in keychain
- Hardened runtime not applied (fails before submit)
- Secure timestamp missing
- `codesign --verify --deep --strict` failures (unsigned nested binary)
- Notarization rejection — auto-prints Apple log

Output lands in `build/local/` (gitignored).

## Cutting a release

```bash
scripts/release.sh 1.1.0           # stable
scripts/release.sh 1.2.0-beta.1    # prerelease (auto-flagged)
git push origin main
git push origin v1.1.0
```

CI on tag push:

1. Bumps `MARKETING_VERSION` + `CURRENT_PROJECT_VERSION` in `project.pbxproj`.
2. Imports cert into ephemeral keychain.
3. `xcodebuild archive` with `ENABLE_HARDENED_RUNTIME=YES` + `--timestamp --options=runtime`.
4. `xcodebuild -exportArchive` with `build-config/ExportOptions.plist`.
5. **Verify signing** — fails fast if hardened runtime / timestamp / deep verify fail.
6. `create-dmg` produces `AiDevtools.dmg`.
7. `notarytool submit --wait` (JSON output, captures submission ID).
8. On rejection: dumps `notarytool log` automatically.
9. `stapler staple` + validate.
10. Generates changelog from `git log PREV_TAG..TAG`.
11. Publishes GitHub Release with the DMG attached.

The CI workflow (`ci.yml`) skips on release commits (`chore: release v*`) since the release workflow already covers that build.

## Manual rebuild without re-tagging

`Actions → Release → Run workflow → tag = vX.Y.Z` (must already exist).

## In-app update check

The app polls `https://api.github.com/repos/techgocodingnow/ai-devtools/releases/latest` on launch (6h throttle) and via **AiDevtools → Check for Updates… (⌘U)**. Drafts and prereleases are skipped.

## Troubleshooting

**Notarization status: Invalid**

Common causes:

| Cause | Fix |
|---|---|
| Hardened runtime not enabled | `ENABLE_HARDENED_RUNTIME=YES` (already set in workflow) |
| Secure timestamp missing | `--timestamp` in `OTHER_CODE_SIGN_FLAGS` (already set) |
| `get-task-allow=true` in entitlements | Remove from Release-config entitlements |
| Unsigned nested binary / framework | `codesign --verify --deep --strict` exposes; sign all helpers |

Fetch log for any submission:

```bash
xcrun notarytool log <submission-id> --keychain-profile AI_DEVTOOLS_NOTARY
```
