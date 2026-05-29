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
6. **Install** ✅ (copy-command) — there's no safe way to drive Claude's plugin installer
   from here (its cache + installed_plugins.json + enabledPlugins are fragile to replicate,
   and the sandbox blocks spawning git/unzip). So Install copies the **real** command
   `/plugin install <plugin>@<marketplace>` to the clipboard + shows a toast to run it in
   Claude. Library "Install…" now opens the Marketplace. Verified: clipboard held
   `/plugin install agent-sdk-dev@claude-plugins-official`.
   - Alternative left dormant: `PluginInstaller` (downloads repo zip → app Packages dir →
     registry as origin:manual) — app-only visibility, sandbox-unzip risk. Not wired.
7. **Remove** ✅ (copy-command) — symmetric with Install; no destructive disk ops.
   Plugin-bundled items copy `/plugin uninstall <plugin>@<marketplace>` (qualified name
   resolved from `enabledPlugins`); standalone skills copy their folder path; MCP entries
   point at their config file. Global toast surfaces the result. Verified: agent-eval →
   `/plugin uninstall ecc@ecc`. (Real "move-to-backup" delete of standalone skills
   considered but not taken — copy-command chosen for safety/consistency.)
8. **Edit / Reveal / Check for updates** ✅ — Edit opens the item's real file
   (SKILL.md / plugin.json / .mcp.json / desktop config) in the default editor via
   NSWorkspace; Reveal selects it in Finder; Check-for-updates copies
   `/plugin update <plugin>@<marketplace>`. Verified: agent-eval →
   `/plugin update ecc@ecc`. (Library row ⋯ menu still a stub — future affordance.)

## C. No on-disk concept (design decision)

9. **Groups CRUD** ✅ (app-side) — derived groups (plugin/namespace) stay read-only;
   user-created groups are a persisted overlay (`custom_groups.json` in the container) with
   create / rename / delete / add-member (searchable sheet) / remove-member. Per-group
   toggle flips every member's enabled state in the **current workspace** (via the item
   toggle path → registry.globalEnabled or project overrides). Claude never sees custom
   groups. Verified: create "My Stack" → add github → delete → sidecar back to `[]`.
10. **Agents** ⬜ — "Open shell" / "Configure" / add-custom-agent.

## D. Unreviewed

11. **Onboarding** + **Tweaks** ⬜ — confirm behaviors are real.
