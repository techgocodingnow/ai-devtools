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

3. **Hook toggles** ⬜ — currently in-memory. Real = rewrite `settings.json` (destructive).
4. **Hook trust/block + New-hook persist** ⬜.
5. **Sources add/edit/remove** ⬜ — writes `extraKnownMarketplaces` in settings.json.
6. **Install** (marketplace + Library) ⬜ — installs a plugin to disk.
7. **Remove** item ⬜ — deletes from disk (destructive).
8. **Edit** item/config ⬜ — open file in external editor.

## C. No on-disk concept (design decision)

9. **Groups CRUD** ⬜ — Claude has no on-disk grouping; would be our own persisted store.
10. **Agents** ⬜ — "Open shell" / "Configure" / add-custom-agent.

## D. Unreviewed

11. **Onboarding** + **Tweaks** ⬜ — confirm behaviors are real.
