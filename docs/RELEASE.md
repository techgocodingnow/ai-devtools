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
3. `xcodebuild archive` (Release, Developer ID).
4. `xcodebuild -exportArchive` with `build-config/ExportOptions.plist`.
5. `create-dmg` produces `AiDevtools.dmg`.
6. `notarytool submit --wait` → `stapler staple`.
7. Generates changelog from `git log PREV_TAG..TAG`.
8. Publishes GitHub Release with the DMG attached.

## Manual rebuild without re-tagging

`Actions → Release → Run workflow → tag = vX.Y.Z` (must already exist).

## In-app update check

The app polls `https://api.github.com/repos/techgocodingnow/ai-devtools/releases/latest` on launch (6h throttle) and via **AiDevtools → Check for Updates… (⌘U)**. Drafts and prereleases are skipped.
