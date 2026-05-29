# Pending / Unwired Features

Tracks UI surfaces not yet backed by real data or real actions. Reviewed one by one
with the maintainer before execution. Status legend: ✅ done · 🟡 partial · ⬜ not started.

## A. Fabricated data to replace

### 1. ItemDetail tabs — 🟡 in progress
- **Overview** ✅ Files = real directory listing + sizes; Capabilities = real
  (SKILL.md frontmatter for skills, manifest skill/MCP counts + tags for plugins,
  transport/auth for MCP servers). "Signed by" pill replaced with honest origin label.
- **Config** ✅ Reads the real config file body: `SKILL.md` (skill), `plugin.json`
  (plugin), or synthesized `.mcp.json` entry (MCP). Empty state when none.
- **Source** ✅ Real install path + origin; renders the real file body (capped).
- **Permissions** ⬜ No real source yet. Shows honest "not yet wired" state.
  **Plan:** parse `~/.claude/settings.json` `permissions.{allow,deny,ask}` and match
  rules relevant to the item (e.g. an MCP server's tool names, a plugin's commands).
  Per-item permission scoping does not exist on disk today — these are global rules,
  so the tab will present the global rules that *apply to* this item.
- **Activity** ⬜ No real source yet. Shows honest "not yet wired" state.
  **Plan:** mine local logs for events referencing the item —
  `~/.claude/history.jsonl`, `~/.claude/projects/*/` session transcripts,
  `bash-commands.log`, `telemetry/`. Needs a log-indexing pass; deferred.

### 2. Hooks metrics — ✅ (read-only telemetry)
- Found a real, non-invasive source: Claude already writes `tengu_run_hook` events to
  `~/.claude/telemetry/*.json` (`additional_metadata` is base64 JSON with `hookName`
  = `event:matcher`, `numCommands`). `HookTelemetryService` reads + decodes them.
- `lastFired` = real last matching fire; `firesPerHour` repurposed as **observed-fire
  count** ("N× seen" / "Observed fires"); detail "Recent invocations" lists real fires
  with an empty state. Agents scan card shows the real candidate count.
- **Did NOT** wrap/rewrite the user's live hooks (the originally-considered shim) — the
  read-only telemetry is safer and sufficient.
- Caveats (acceptable): telemetry is a sparse sample (mostly failed-upload events) and
  attributes fires at the `event+matcher` level, not the exact command. Noted in-UI.
- **Future:** for dense, per-command metrics we'd need our own opt-in invocation logger.

## B. Write-back actions (mutate disk/system — sign-off each)

3. **Hook enable/disable** ✅ (global) — real, reversible. Disable backs up settings.json
   to `~/.claude/backups/settings-<epoch>.json`, removes the entry, and stashes the full
   entry in a sidecar (`disabled_hooks.json` in the app container). Enable re-inserts it.
   `ClaudeSettingsWriter` does atomic, backup-first writes preserving all other keys.
   Verified: disable→enable round-trip leaves settings.json semantically identical.
   - **Sandbox:** required broadening the entitlement — `~/.claude/` moved from read-only
     to read-write (`AiDevtools.entitlements`). `~/.claude.json` stays read-only.
   - **Note:** writes reserialize the whole file (pretty + sorted keys), so formatting
     changes on first write (content preserved; backup taken).
   - **Project-scoped hooks** still ⬜ — they live outside `~/.claude` (sandbox blocks).
     `setHookScope`/`addHookScope` are intentional no-ops for now; needs an NSOpenPanel
     folder grant per project. Global hooks only this round.
4. **New-hook form** ✅ (global) — submit appends to `~/.claude/settings.json` via the
   backup-first `ClaudeSettingsWriter`. Event picker restricted to real Claude events
   (`rawEventName` inverse map); non-writable/cursor-only events are filtered out.
   Verified: a new PostToolUse hook was written correctly. Project scope still deferred.
   **Trust/block + untrusted banner**: kept in place but **inert** — settings.json has no
   "untrusted hook" concept, so these never trigger with real data. Left for a future
   trust model rather than removed. The untrusted status filter is likewise dormant.
5. **Sources add/remove + toggle** ✅ (global) — Add-form appends a marketplace to
   `extraKnownMarketplaces` (git URL → git/url, `owner/repo` → github/repo); per-source
   trash removes it (with a confirm dialog). Both backup-first via `ClaudeSettingsWriter`.
   Enable/disable is an **app-persisted fetch flag** (`disabled_sources.json` sidecar) —
   extraKnownMarketplaces has no enabled field — and it filters which sources `loadFeed`
   pulls catalogs from. Verified: add (8→9) + remove (9→8) round-trip; settings.json
   restored identical. **Edit** still ⬜ (do as remove+re-add).
6. **Install** (marketplace + Library) ⬜ — installs a plugin to disk.
7. **Remove** item ⬜ — deletes from disk (destructive).
8. **Edit** item/config ⬜ — open file in external editor.

## C. No on-disk concept (design decision)

9. **Groups CRUD** ⬜ — Claude has no on-disk grouping; would be our own persisted store.
10. **Agents** ⬜ — "Open shell" / "Configure" / add-custom-agent.

## D. Unreviewed

11. **Onboarding** + **Tweaks** ⬜ — confirm behaviors are real.
