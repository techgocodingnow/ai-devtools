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

## Releasing

Tag-driven: push `vX.Y.Z` → CI builds, signs, notarizes, staples, publishes GitHub Release with DMG.

```bash
scripts/release-local.sh --notarize --staple   # local dry-run (catch issues pre-tag)
scripts/release.sh 1.1.0                       # bump + tag
git push origin main && git push origin v1.1.0
```

Full pipeline + troubleshooting: [docs/RELEASE.md](docs/RELEASE.md).

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
