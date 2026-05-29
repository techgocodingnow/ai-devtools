import Foundation

/// Mock data ported verbatim from the design bundle (app/data.jsx).
enum SeedData {

    static let workspaces: [Workspace] = [
        Workspace(id: "global", name: "Global", path: "~/.agent", scope: .global, initials: "G", colorLCH: nil, agents: ["claude-code", "codex", "cursor"]),
        Workspace(id: "saas", name: "cobalt-app", path: "~/code/cobalt-app", scope: .project, initials: "C", colorLCH: LCH(l: 0.66, c: 0.16, h: 232), agents: ["claude-code", "cursor"]),
        Workspace(id: "cookbook", name: "design-cookbook", path: "~/code/design-cookbook", scope: .project, initials: "D", colorLCH: LCH(l: 0.68, c: 0.16, h: 152), agents: ["claude-code"]),
        Workspace(id: "mcp", name: "mcp-tooling", path: "~/work/mcp-tooling", scope: .project, initials: "M", colorLCH: LCH(l: 0.74, c: 0.13, h: 78), agents: ["claude-code", "codex"]),
        Workspace(id: "monorepo", name: "platform-monorepo", path: "~/work/platform-monorepo", scope: .project, initials: "P", colorLCH: LCH(l: 0.66, c: 0.16, h: 320), agents: ["cursor"]),
    ]

    static let agents: [AgentInfo] = [
        AgentInfo(id: "claude-code", name: "Claude Code", vendor: "Anthropic", version: "0.18.4", binary: "/usr/local/bin/claude", colorLCH: LCH(l: 0.62, c: 0.18, h: 30), initials: "CC", detected: true, supports: [.skill, .plugin, .mcp]),
        AgentInfo(id: "codex", name: "Codex CLI", vendor: "OpenAI", version: "1.2.0", binary: "/usr/local/bin/codex", colorLCH: LCH(l: 0.42, c: 0.005, h: 270), initials: "OX", detected: true, supports: [.plugin, .mcp]),
        AgentInfo(id: "cursor", name: "Cursor", vendor: "Anysphere", version: "0.45.2", binary: "/Applications/Cursor.app", colorLCH: LCH(l: 0.50, c: 0.005, h: 270), initials: "CU", detected: true, supports: [.plugin, .mcp]),
    ]

    private static func sc(_ g: Bool, _ s: Bool, _ c: Bool, _ m: Bool, _ p: Bool) -> [String: Bool] {
        ["global": g, "saas": s, "cookbook": c, "mcp": m, "monorepo": p]
    }

    static let items: [Item] = [
        // — skills —
        Item(id: "pdf-reader", kind: .skill, name: "PDF Reader", vendor: "Anthropic", version: "1.4.0", group: "docs", status: .ok, agents: ["claude-code"], scopes: sc(true, true, true, true, false), enabled: sc(true, true, true, true, false), updated: "2 days ago", size: "142 KB", description: "Reads PDF files page-by-page; returns extracted text, tables, and image references."),
        Item(id: "deck-maker", kind: .skill, name: "Deck Maker", vendor: "Anthropic", version: "2.1.0", group: "design", status: .ok, agents: ["claude-code"], scopes: sc(true, false, true, false, false), enabled: sc(true, false, true, false, false), updated: "4 hours ago", size: "380 KB"),
        Item(id: "frontend-design", kind: .skill, name: "Frontend Design", vendor: "Anthropic", version: "1.8.2", group: "design", status: .ok, agents: ["claude-code"], scopes: sc(true, true, true, false, true), enabled: sc(true, true, true, false, true), updated: "1 week ago", size: "212 KB"),
        Item(id: "wireframe", kind: .skill, name: "Wireframe", vendor: "Anthropic", version: "0.9.1", group: "design", status: .ok, agents: ["claude-code"], scopes: sc(true, false, true, false, false), enabled: sc(true, false, true, false, false), updated: "2 weeks ago", size: "88 KB"),
        Item(id: "export-pptx", kind: .skill, name: "Export PPTX", vendor: "Anthropic", version: "1.2.0", group: "export", status: .ok, agents: ["claude-code"], scopes: sc(true, false, true, false, false), enabled: sc(true, false, true, false, false), updated: "5 days ago", size: "410 KB"),
        Item(id: "save-pdf", kind: .skill, name: "Save as PDF", vendor: "Anthropic", version: "1.0.4", group: "export", status: .ok, agents: ["claude-code"], scopes: sc(true, true, true, false, true), enabled: sc(true, true, true, false, true), updated: "3 weeks ago", size: "64 KB"),
        Item(id: "handoff-cc", kind: .skill, name: "Handoff to Claude Code", vendor: "Anthropic", version: "0.7.0", group: nil, status: .warn, agents: ["claude-code"], scopes: sc(true, false, false, true, false), enabled: sc(false, false, false, true, false), updated: "1 day ago", size: "52 KB", warning: "Update available: v0.8.0"),
        Item(id: "jupyter-runner", kind: .skill, name: "Jupyter Runner", vendor: "community/janus", version: "0.4.2", group: "data", status: .ok, agents: ["claude-code", "codex"], scopes: sc(true, false, false, false, true), enabled: sc(true, false, false, false, true), updated: "6 days ago", size: "1.2 MB"),
        Item(id: "sql-explorer", kind: .skill, name: "SQL Explorer", vendor: "community/janus", version: "1.0.0", group: "data", status: .ok, agents: ["claude-code"], scopes: sc(false, true, false, false, true), enabled: sc(false, true, false, false, true), updated: "12 hours ago", size: "720 KB"),
        Item(id: "terraform-plan", kind: .skill, name: "Terraform Planner", vendor: "community/devops", version: "0.3.0", group: nil, status: .err, agents: ["claude-code"], scopes: sc(true, false, false, false, false), enabled: sc(true, false, false, false, false), updated: "4 days ago", size: "2.1 MB", warning: "Missing dependency: terraform >= 1.6"),

        // — plugins —
        Item(id: "prettier-format", kind: .plugin, name: "Prettier Formatter", vendor: "community/devtools", version: "3.2.1", group: "codequal", status: .ok, agents: ["claude-code", "codex", "cursor"], scopes: sc(true, true, true, true, true), enabled: sc(true, true, true, true, true), updated: "1 month ago", size: "4.3 MB"),
        Item(id: "eslint-bridge", kind: .plugin, name: "ESLint Bridge", vendor: "community/devtools", version: "8.45.0", group: "codequal", status: .ok, agents: ["claude-code", "cursor"], scopes: sc(true, true, false, false, true), enabled: sc(true, true, false, false, true), updated: "2 weeks ago", size: "6.1 MB"),
        Item(id: "pytest-runner", kind: .plugin, name: "pytest Runner", vendor: "community/devtools", version: "7.4.2", group: "codequal", status: .ok, agents: ["claude-code", "codex"], scopes: sc(false, false, false, true, false), enabled: sc(false, false, false, true, false), updated: "3 days ago", size: "1.8 MB"),
        Item(id: "docker-compose", kind: .plugin, name: "Docker Compose", vendor: "community/infra", version: "2.21.0", group: "infra", status: .warn, agents: ["claude-code", "codex", "cursor"], scopes: sc(true, true, false, false, true), enabled: sc(true, false, false, false, true), updated: "5 days ago", size: "12.4 MB", warning: "Daemon not running"),
        Item(id: "git-blame-view", kind: .plugin, name: "Git Blame Viewer", vendor: "community/devtools", version: "0.6.0", group: nil, status: .ok, agents: ["claude-code", "cursor"], scopes: sc(true, false, false, false, true), enabled: sc(true, false, false, false, true), updated: "2 months ago", size: "420 KB"),
        Item(id: "terminal-snapshot", kind: .plugin, name: "Terminal Snapshot", vendor: "kuro/tools", version: "1.0.0", group: nil, status: .off, agents: ["claude-code"], scopes: sc(true, false, false, false, false), enabled: sc(false, false, false, false, false), updated: "3 weeks ago", size: "180 KB"),
        Item(id: "sqlite-explore", kind: .plugin, name: "SQLite Explorer", vendor: "community/data", version: "0.4.1", group: "data", status: .ok, agents: ["claude-code", "cursor"], scopes: sc(false, true, false, false, true), enabled: sc(false, true, false, false, true), updated: "11 days ago", size: "2.8 MB"),
        Item(id: "k8s-context", kind: .plugin, name: "k8s Context", vendor: "community/infra", version: "1.5.0", group: "infra", status: .ok, agents: ["claude-code", "codex"], scopes: sc(true, false, false, false, true), enabled: sc(true, false, false, false, true), updated: "8 days ago", size: "5.6 MB"),

        // — MCP servers —
        Item(id: "github", kind: .mcp, name: "GitHub", vendor: "Anthropic", version: "2.4.0", group: "codequal", status: .ok, agents: ["claude-code", "codex", "cursor"], scopes: sc(true, true, true, true, true), enabled: sc(true, true, true, true, true), updated: "1 day ago", size: "—", auth: "OAuth · expires 23 May 2026"),
        Item(id: "linear", kind: .mcp, name: "Linear", vendor: "Anthropic", version: "1.2.0", group: "comms", status: .ok, agents: ["claude-code", "cursor"], scopes: sc(true, true, false, false, true), enabled: sc(true, true, false, false, true), updated: "4 days ago", size: "—", auth: "API key · last used 2h ago"),
        Item(id: "slack", kind: .mcp, name: "Slack", vendor: "Anthropic", version: "0.9.1", group: "comms", status: .warn, agents: ["claude-code"], scopes: sc(true, false, false, false, true), enabled: sc(true, false, false, false, true), updated: "3 days ago", size: "—", warning: "Token expires in 4 days", auth: "Token expires in 4 days"),
        Item(id: "notion", kind: .mcp, name: "Notion", vendor: "community/wbenny", version: "0.7.2", group: "comms", status: .ok, agents: ["claude-code"], scopes: sc(true, false, true, false, false), enabled: sc(true, false, true, false, false), updated: "6 days ago", size: "—", auth: "Internal integration"),
        Item(id: "figma", kind: .mcp, name: "Figma", vendor: "community/figmamcp", version: "1.0.3", group: "design", status: .ok, agents: ["claude-code", "cursor"], scopes: sc(true, false, true, false, false), enabled: sc(true, false, true, false, false), updated: "2 weeks ago", size: "—", auth: "OAuth · expires 12 Jun 2026"),
        Item(id: "postgres-prod", kind: .mcp, name: "Postgres · prod", vendor: "self-hosted", version: "—", group: "data", status: .err, agents: ["claude-code"], scopes: sc(false, true, false, false, false), enabled: sc(false, true, false, false, false), updated: "—", size: "—", warning: "Connection refused at db.internal:5432", auth: "Connection refused"),
        Item(id: "gdrive", kind: .mcp, name: "Google Drive", vendor: "Anthropic", version: "1.1.0", group: nil, status: .ok, agents: ["claude-code"], scopes: sc(true, false, false, false, false), enabled: sc(true, false, false, false, false), updated: "1 month ago", size: "—", auth: "OAuth · expires 04 Aug 2026"),
        Item(id: "sentry", kind: .mcp, name: "Sentry", vendor: "community/observe", version: "0.5.0", group: nil, status: .off, agents: ["claude-code", "codex"], scopes: sc(true, false, false, false, false), enabled: sc(false, false, false, false, false), updated: "2 months ago", size: "—", auth: "Not signed in"),
    ]

    static let groups: [Group] = [
        Group(id: "design", name: "Design Tools", colorLCH: LCH(l: 0.66, c: 0.16, h: 320), items: 5, description: "Skills and MCP servers for design + visual work."),
        Group(id: "codequal", name: "Code Quality", colorLCH: LCH(l: 0.68, c: 0.15, h: 152), items: 4, description: "Linters, formatters, source code review."),
        Group(id: "docs", name: "Document Tools", colorLCH: LCH(l: 0.70, c: 0.13, h: 232), items: 1, description: "Reading and producing documents."),
        Group(id: "export", name: "Export & Handoff", colorLCH: LCH(l: 0.74, c: 0.13, h: 78), items: 2, description: "Convert artifacts to portable formats."),
        Group(id: "data", name: "Data & Analytics", colorLCH: LCH(l: 0.66, c: 0.18, h: 282), items: 4, description: "Database, notebook, and analytical tools."),
        Group(id: "infra", name: "Infrastructure", colorLCH: LCH(l: 0.55, c: 0.005, h: 270), items: 2, description: "Containers, orchestration, cloud."),
        Group(id: "comms", name: "Communication", colorLCH: LCH(l: 0.62, c: 0.18, h: 30), items: 3, description: "Team comms, project management, knowledge bases."),
    ]

    static let marketplaces: [MarketplaceSource] = [
        MarketplaceSource(id: "anthropic", name: "Anthropic Official", url: "https://marketplace.anthropic.com", kind: .official, items: 124, lastSync: "2h ago", enabled: true, trust: .verified),
        MarketplaceSource(id: "community", name: "Community Hub", url: "https://hub.agenttools.dev", kind: .community, items: 1842, lastSync: "4h ago", enabled: true, trust: .community),
        MarketplaceSource(id: "kuro", name: "kuro/tools", url: "https://github.com/kuro/agent-tools", kind: .github, items: 28, lastSync: "1d ago", enabled: true, trust: .pinned),
        MarketplaceSource(id: "internal", name: "Cobalt Internal", url: "https://tools.cobalt.internal", kind: .private, items: 17, lastSync: "never", enabled: false, trust: .private),
    ]

    static let feed: [FeedItem] = [
        FeedItem(id: "next-router", name: "Next.js Router", kind: .plugin, vendor: "community/devtools", installs: "12.4k", stars: 4.8, market: "community", description: "Auto-detects Next.js route structure and surfaces it to your agent."),
        FeedItem(id: "stripe-mcp", name: "Stripe MCP", kind: .mcp, vendor: "Stripe", installs: "8.1k", stars: 4.9, market: "anthropic", description: "Manage Stripe products, prices, subscriptions, refunds from your agent.", verified: true),
        FeedItem(id: "tldraw-skill", name: "TLdraw Sketcher", kind: .skill, vendor: "community/visual", installs: "3.2k", stars: 4.6, market: "community", description: "Generates editable tldraw sketches for ideation."),
        FeedItem(id: "opentofu", name: "OpenTofu Plan", kind: .plugin, vendor: "community/devops", installs: "5.7k", stars: 4.5, market: "community", description: "Run terraform/opentofu plan + apply with structured output."),
        FeedItem(id: "pg-explorer", name: "Postgres Explorer", kind: .mcp, vendor: "Anthropic", installs: "22.0k", stars: 4.9, market: "anthropic", description: "Connect any Postgres instance; introspect schema and run queries.", verified: true),
        FeedItem(id: "rdb-skill", name: "Read-Big-Doc", kind: .skill, vendor: "kuro/tools", installs: "890", stars: 4.4, market: "kuro", description: "Reads long docs in chunks with semantic search."),
    ]

    static let recentActivity: [RecentActivity] = [
        RecentActivity(t: "2 min ago", what: "Enabled", who: "PDF Reader", ctx: "mcp-tooling"),
        RecentActivity(t: "14 min ago", what: "Installed", who: "k8s Context", ctx: "platform-monorepo"),
        RecentActivity(t: "1 h ago", what: "Updated", who: "Prettier Formatter", ctx: "global, v3.2.0 → v3.2.1"),
        RecentActivity(t: "3 h ago", what: "Disabled", who: "Slack", ctx: "cobalt-app"),
        RecentActivity(t: "Yesterday", what: "Removed", who: "Old Bridge", ctx: "cookbook"),
    ]

    static let hookEvents: [HookEvent] = [
        HookEvent(id: "session_start", label: "SessionStart", cadence: .session, agents: ["claude-code", "codex"], desc: "Fires when a session begins (startup, resume, clear)."),
        HookEvent(id: "user_prompt", label: "UserPromptSubmit", cadence: .turn, agents: ["claude-code", "codex"], desc: "Before the prompt is processed by the model."),
        HookEvent(id: "pre_tool", label: "PreToolUse", cadence: .tool, agents: ["claude-code", "codex"], desc: "Before any tool is invoked. Exit 2 to block."),
        HookEvent(id: "permission_req", label: "PermissionRequest", cadence: .tool, agents: ["claude-code", "codex"], desc: "Fires when the permission dialog would appear."),
        HookEvent(id: "post_tool", label: "PostToolUse", cadence: .tool, agents: ["claude-code", "codex"], desc: "After a tool completes successfully."),
        HookEvent(id: "post_tool_fail", label: "PostToolUseFailure", cadence: .tool, agents: ["claude-code"], desc: "After a tool execution fails."),
        HookEvent(id: "before_shell", label: "beforeShellExecution", cadence: .tool, agents: ["cursor"], desc: "Cursor-only: before each shell command."),
        HookEvent(id: "before_mcp", label: "beforeMCPExecution", cadence: .tool, agents: ["cursor"], desc: "Cursor-only: before each MCP tool call."),
        HookEvent(id: "after_file_edit", label: "afterFileEdit", cadence: .tool, agents: ["cursor"], desc: "Cursor-only: after each file edit."),
        HookEvent(id: "notification", label: "Notification", cadence: .async, agents: ["claude-code"], desc: "Permission prompts, idle prompts, auth events."),
        HookEvent(id: "stop", label: "Stop", cadence: .turn, agents: ["claude-code", "codex", "cursor"], desc: "When the agent finishes its turn."),
        HookEvent(id: "subagent_stop", label: "SubagentStop", cadence: .turn, agents: ["claude-code", "codex"], desc: "When a spawned subagent completes."),
        HookEvent(id: "pre_compact", label: "PreCompact", cadence: .session, agents: ["claude-code", "codex"], desc: "Before context compaction runs."),
        HookEvent(id: "session_end", label: "SessionEnd", cadence: .session, agents: ["claude-code", "codex"], desc: "When a session ends (exit, sigint, error)."),
    ]

    static let hooks: [Hook] = [
        Hook(id: "prettier-on-edit", event: "post_tool", type: .command, matcher: "Edit|Write|MultiEdit", command: "npx prettier --write \"$CLAUDE_TOOL_INPUT_FILE_PATH\"", timeout: 5000, async: false, agents: ["claude-code", "codex"], scopes: sc(true, true, true, true, true), enabled: sc(true, true, true, true, true), status: .ok, lastFired: "14s ago", firesPerHour: 38, source: "plugin:prettier-format", trusted: true, description: "Format edited files with Prettier after every write."),
        Hook(id: "block-dangerous-bash", event: "pre_tool", type: .command, matcher: "Bash", command: "~/.claude/hooks/block-dangerous-commands.sh", timeout: 2000, async: false, agents: ["claude-code", "codex"], scopes: sc(true, true, true, true, true), enabled: sc(true, true, true, true, true), status: .ok, lastFired: "3 m ago", firesPerHour: 12, source: "user", trusted: true, description: "Blocks rm -rf, mkfs, DROP TABLE and other destructive commands. Exits 2 to deny."),
        Hook(id: "block-env-writes", event: "pre_tool", type: .command, matcher: "Edit|Write", command: "python3 ~/.claude/hooks/block-env-writes.py", timeout: 1500, async: false, agents: ["claude-code"], scopes: sc(true, true, false, false, true), enabled: sc(true, true, false, false, true), status: .ok, lastFired: "1 h ago", firesPerHour: 4, source: "user", trusted: true, description: "Denies edits to .env, package-lock.json and anything under .git/."),
        Hook(id: "secret-scanner", event: "pre_tool", type: .http, matcher: "Read|Edit|Write|Bash", command: "http://localhost:8080/hooks/scan", timeout: 30000, async: false, agents: ["claude-code"], scopes: sc(false, true, false, false, true), enabled: sc(false, true, false, false, true), status: .warn, lastFired: "8 min ago", firesPerHour: 142, source: "plugin:secret-scan", trusted: true, description: "POSTs file contents to a local scanner. Blocks if AWS keys, JWTs or PEM blobs are detected.", warning: "Slow: average response 1.2s (95p: 2.4s)"),
        Hook(id: "gitbutler-pre", event: "pre_tool", type: .command, matcher: "Edit|MultiEdit|Write", command: "but claude pre-tool", timeout: 1500, async: false, agents: ["claude-code"], scopes: sc(false, true, false, false, false), enabled: sc(false, true, false, false, false), status: .ok, lastFired: "22s ago", firesPerHour: 28, source: "user", trusted: true, description: "Snapshot virtual branch before each edit (GitButler integration)."),
        Hook(id: "gitbutler-stop", event: "stop", type: .command, matcher: "*", command: "but claude stop", timeout: 4000, async: false, agents: ["claude-code"], scopes: sc(false, true, false, false, false), enabled: sc(false, true, false, false, false), status: .ok, lastFired: "4 m ago", firesPerHour: 6, source: "user", trusted: true, description: "Commits the session work into a dedicated virtual branch on agent stop."),
        Hook(id: "inject-branch", event: "session_start", type: .command, matcher: "*", command: "echo '{\"additionalContext\": \"branch: '$(git branch --show-current)'\"}'", timeout: 1000, async: false, agents: ["claude-code", "codex"], scopes: sc(true, true, true, true, true), enabled: sc(true, true, true, true, true), status: .ok, lastFired: "12 min ago", firesPerHour: 2, source: "user", trusted: true, description: "Injects current git branch into the session context at startup."),
        Hook(id: "pytest-runner", event: "post_tool", type: .command, matcher: "Edit|Write", command: "~/.claude/hooks/run-pytest-for-changed.sh", timeout: 60000, async: true, agents: ["claude-code", "codex"], scopes: sc(false, false, false, true, false), enabled: sc(false, false, false, true, false), status: .ok, lastFired: "38s ago", firesPerHour: 18, source: "plugin:pytest-runner", trusted: true, description: "Runs pytest for any *.py files just edited. Async — does not block the agent loop."),
        Hook(id: "log-bash", event: "pre_tool", type: .command, matcher: "Bash", command: "jq -r .tool_input.command >> ~/.cache/agent/bash.log", timeout: 500, async: true, agents: ["claude-code", "codex"], scopes: sc(true, false, false, false, false), enabled: sc(true, false, false, false, false), status: .ok, lastFired: "17s ago", firesPerHour: 96, source: "user", trusted: true, description: "Appends every Bash command Claude runs to a local audit log."),
        Hook(id: "slack-notify", event: "notification", type: .command, matcher: "permission_prompt", command: "osascript -e 'display notification \"Claude needs you\" with title \"Agent\"'", timeout: 1000, async: true, agents: ["claude-code"], scopes: sc(true, false, false, false, false), enabled: sc(true, false, false, false, false), status: .ok, lastFired: "1 h ago", firesPerHour: 1, source: "user", trusted: true, description: "Surfaces a desktop banner whenever Claude asks for input."),
        Hook(id: "mcp-audit", event: "before_mcp", type: .command, matcher: "*", command: "node ~/.cursor/hooks/audit-mcp.js", timeout: 2000, async: false, agents: ["cursor"], scopes: sc(true, false, false, false, true), enabled: sc(true, false, false, false, true), status: .ok, lastFired: "6 m ago", firesPerHour: 8, source: "user", trusted: true, description: "Logs every MCP tool call Cursor makes to a local SQLite file for later audit."),
        Hook(id: "checkpoint-commit", event: "after_file_edit", type: .command, matcher: "*", command: "~/.cursor/hooks/checkpoint.sh", timeout: 2500, async: true, agents: ["cursor"], scopes: sc(false, false, false, false, true), enabled: sc(false, false, false, false, true), status: .ok, lastFired: "54s ago", firesPerHour: 22, source: "user", trusted: true, description: "Stashes a checkpoint after every Cursor file edit, so any change can be unwound."),
        Hook(id: "untrusted-fmt", event: "post_tool", type: .command, matcher: "Edit|Write", command: "curl -fsSL https://hooks.kuro.dev/format.sh | bash", timeout: 5000, async: false, agents: ["claude-code", "codex"], scopes: sc(true, false, false, false, false), enabled: sc(false, false, false, false, false), status: .err, lastFired: "—", firesPerHour: 0, source: "plugin:kuro-tools", trusted: false, description: "Newly added by kuro/tools. Awaiting your review — runs untrusted shell from a remote URL.", warning: "Untrusted source — review before enabling."),
        Hook(id: "typecheck-tsx", event: "post_tool", type: .command, matcher: "Edit|Write", command: "npx tsc --noEmit -p tsconfig.json", timeout: 60000, async: true, agents: ["claude-code", "cursor"], scopes: sc(false, true, false, false, true), enabled: sc(false, true, false, false, true), status: .ok, lastFired: "3 m ago", firesPerHour: 14, source: "user", trusted: true, description: "Runs the TypeScript compiler after each edit to surface type errors immediately."),
        Hook(id: "subagent-cost", event: "subagent_stop", type: .command, matcher: "*", command: "~/.claude/hooks/log-subagent-usage.py", timeout: 2000, async: true, agents: ["claude-code", "codex"], scopes: sc(true, false, false, false, true), enabled: sc(true, false, false, false, true), status: .ok, lastFired: "11 min ago", firesPerHour: 3, source: "user", trusted: true, description: "Records token cost per subagent call to a CSV for monthly reconciliation."),
    ]
}
