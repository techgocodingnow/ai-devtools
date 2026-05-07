# AiDevtools

Native macOS app to manage AI agent capabilities — skills, plugins, connectors, MCP servers — at both global and per-project scope. Inspired by Claude Desktop / Claude Code's customization model.

## Install

Download the latest signed + notarized DMG from [Releases](https://github.com/techgocodingnow/ai-devtools/releases/latest), open it, drag **AiDevtools.app** to **Applications**.

First launch may pause briefly for Gatekeeper verification.

## Features

- Unified UI for skills, plugins, connectors, and MCP servers.
- Toggle capabilities on/off per project or globally.
- Install from a marketplace or directly from a GitHub repo.
- Inspect details (description, source, files) of any capability.
- Auto-detect projects with existing Claude-style skills / plugins / MCP markers.
- In-app update check via GitHub Releases (⌘U or auto on launch, 6h throttle).

See [docs/PRD.md](docs/PRD.md) and [docs/DESIGN.md](docs/DESIGN.md) for full product + design specs.

## Build from source

Requires Xcode 16+, macOS 14+.

```bash
open AiDevtools/AiDevtools.xcodeproj
```

Build + run with **⌘R**.

## Deployment

Releases are produced by [`.github/workflows/release.yml`](.github/workflows/release.yml). Tag-driven: push a `vX.Y.Z` tag and CI builds, signs, notarizes, staples, and publishes a GitHub Release with the DMG attached.

### CI pipeline

On push of tag `v*.*.*` (or manual `workflow_dispatch` with an existing tag):

1. **Resolve tag** — validates `vMAJOR.MINOR.PATCH[-PRERELEASE]` format.
2. **Set version** — patches `MARKETING_VERSION` (from tag) + `CURRENT_PROJECT_VERSION` (= `github.run_number`) in `project.pbxproj`.
3. **Import cert** — decodes `BUILD_CERTIFICATE_BASE64` into an ephemeral keychain.
4. **Archive** — `xcodebuild archive` Release config with `ENABLE_HARDENED_RUNTIME=YES`, `--timestamp --options=runtime`, Developer ID identity.
5. **Export** — Developer ID `.app` via `build-config/ExportOptions.plist`.
6. **Verify signing** — fails fast if hardened runtime / secure timestamp / deep verify fails.
7. **Create DMG** — `create-dmg` with drag-to-Applications layout.
8. **Notarize** — `notarytool submit --wait` with JSON output. On non-Accepted status, dumps `notarytool log` and exits.
9. **Staple** — `stapler staple` + validate.
10. **Generate changelog** — from `git log <prev-tag>..<tag>` + install instructions.
11. **Publish** — `softprops/action-gh-release` attaches DMG, marks prerelease if tag contains `-`.
12. **Cleanup** — deletes ephemeral keychain.

CI workflow ([`ci.yml`](.github/workflows/ci.yml)) runs Debug builds on push to `main` + PRs, but **skips on `chore: release v*` commits** since the release workflow already covers tag builds.

### Required GitHub secrets

| Secret | Purpose |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i DeveloperID.p12` of Developer ID Application cert |
| `P12_PASSWORD` | Password set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Random string for ephemeral keychain |
| `NOTARY_APPLE_ID` | Apple ID email for notarization |
| `NOTARY_TEAM_ID` | `L23PD654Q3` |
| `NOTARY_PASSWORD` | App-specific password from appleid.apple.com |

### Cutting a release

```bash
# 1. (Optional but recommended) Local dry-run — catch sign/notarize errors pre-tag:
scripts/release-local.sh --notarize --staple

# 2. Bump version + create tag:
scripts/release.sh 1.1.0           # stable
scripts/release.sh 1.2.0-beta.1    # prerelease (auto-flagged from `-`)

# 3. Push:
git push origin main && git push origin v1.1.0
```

CI publishes Release in ~3–5 min. Watch with `gh run watch`.

### Manual rebuild without re-tagging

`Actions → Release → Run workflow → tag = vX.Y.Z` (must already exist).

### Local setup for dry-run

```bash
brew install create-dmg jq

# .env (gitignored) with same values as GitHub secrets:
echo 'BUILD_CERTIFICATE_BASE64=...'  >> .env
echo 'P12_PASSWORD=...'              >> .env

scripts/import-cert.sh               # one-time: import Developer ID cert into login keychain

xcrun notarytool store-credentials AI_DEVTOOLS_NOTARY \
  --apple-id "<apple-id>" --team-id "L23PD654Q3" --password "<app-specific-pw>"
```

Full troubleshooting: [docs/RELEASE.md](docs/RELEASE.md).

## Repo layout

```
AiDevtools/              Xcode project + Swift sources
build-config/            ExportOptions.plist for Developer ID export
docs/                    PRD, DESIGN, RELEASE
scripts/
  release.sh             Bump + tag (drives CI release)
  release-local.sh       Local mirror of CI pipeline
  import-cert.sh         Import Developer ID cert from .env into login keychain
.github/workflows/
  ci.yml                 Debug build on PR / main push
  release.yml            Tag-driven sign + notarize + publish
```

## License

See [LICENSE](LICENSE) if present, otherwise all rights reserved.
