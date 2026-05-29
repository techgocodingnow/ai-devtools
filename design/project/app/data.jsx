// AgentToolKit · mock data

const WORKSPACES = [
  { id: 'global',    name: 'Global',                path: '~/.agent',                  scope: 'global', initials: 'G',  agents: ['claude-code', 'codex', 'cursor'] },
  { id: 'saas',      name: 'cobalt-app',            path: '~/code/cobalt-app',         scope: 'project', initials: 'C', color: 'oklch(0.66 0.16 232)', agents: ['claude-code', 'cursor'] },
  { id: 'cookbook',  name: 'design-cookbook',       path: '~/code/design-cookbook',    scope: 'project', initials: 'D', color: 'oklch(0.68 0.16 152)', agents: ['claude-code'] },
  { id: 'mcp',       name: 'mcp-tooling',           path: '~/work/mcp-tooling',        scope: 'project', initials: 'M', color: 'oklch(0.74 0.13 78)',  agents: ['claude-code', 'codex'] },
  { id: 'monorepo',  name: 'platform-monorepo',     path: '~/work/platform-monorepo',  scope: 'project', initials: 'P', color: 'oklch(0.66 0.16 320)', agents: ['cursor'] },
];

const AGENTS = [
  { id: 'claude-code', name: 'Claude Code', vendor: 'Anthropic', version: '0.18.4', binary: '/usr/local/bin/claude', color: 'oklch(0.62 0.18 30)',  initials: 'CC', detected: true,  supports: ['skill', 'plugin', 'mcp'] },
  { id: 'codex',       name: 'Codex CLI',  vendor: 'OpenAI',     version: '1.2.0',  binary: '/usr/local/bin/codex',  color: 'oklch(0.42 0.005 270)', initials: 'OX', detected: true,  supports: ['plugin', 'mcp'] },
  { id: 'cursor',      name: 'Cursor',     vendor: 'Anysphere',  version: '0.45.2', binary: '/Applications/Cursor.app', color: 'oklch(0.50 0.005 270)', initials: 'CU', detected: true, supports: ['plugin', 'mcp'] },
];

// id, kind: 'skill'|'plugin'|'mcp', name, vendor, version,
// installed: { scope: bool | version } — global / per-workspace,
// enabled: { scope: bool },
// group: optional group id,
// status: 'ok'|'warn'|'err'|'off',
// agents: which agents it targets
// description
const ITEMS = [
  // — skills —
  { id: 'pdf-reader',         kind: 'skill', name: 'PDF Reader',         vendor: 'Anthropic', version: '1.4.0', group: 'docs',     status: 'ok',   agents: ['claude-code'], scopes: { global: true, saas: true, cookbook: true, mcp: true, monorepo: false }, enabled: { global: true, saas: true, cookbook: true, mcp: true, monorepo: false }, updated: '2 days ago', size: '142 KB', description: 'Reads PDF files page-by-page; returns extracted text, tables, and image references.' },
  { id: 'deck-maker',         kind: 'skill', name: 'Deck Maker',         vendor: 'Anthropic', version: '2.1.0', group: 'design',   status: 'ok',   agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, updated: '4 hours ago', size: '380 KB' },
  { id: 'frontend-design',    kind: 'skill', name: 'Frontend Design',    vendor: 'Anthropic', version: '1.8.2', group: 'design',   status: 'ok',   agents: ['claude-code'], scopes: { global: true, saas: true, cookbook: true, mcp: false, monorepo: true }, enabled: { global: true, saas: true, cookbook: true, mcp: false, monorepo: true }, updated: '1 week ago', size: '212 KB' },
  { id: 'wireframe',          kind: 'skill', name: 'Wireframe',          vendor: 'Anthropic', version: '0.9.1', group: 'design',   status: 'ok',   agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, updated: '2 weeks ago', size: '88 KB' },
  { id: 'export-pptx',        kind: 'skill', name: 'Export PPTX',        vendor: 'Anthropic', version: '1.2.0', group: 'export',   status: 'ok',   agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, updated: '5 days ago', size: '410 KB' },
  { id: 'save-pdf',           kind: 'skill', name: 'Save as PDF',        vendor: 'Anthropic', version: '1.0.4', group: 'export',   status: 'ok',   agents: ['claude-code'], scopes: { global: true, saas: true, cookbook: true, mcp: false, monorepo: true }, enabled: { global: true, saas: true, cookbook: true, mcp: false, monorepo: true }, updated: '3 weeks ago', size: '64 KB' },
  { id: 'handoff-cc',         kind: 'skill', name: 'Handoff to Claude Code', vendor: 'Anthropic', version: '0.7.0', group: null,    status: 'warn', agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: false, mcp: true, monorepo: false }, enabled: { global: false, saas: false, cookbook: false, mcp: true, monorepo: false }, updated: '1 day ago', size: '52 KB', warning: 'Update available: v0.8.0' },
  { id: 'jupyter-runner',     kind: 'skill', name: 'Jupyter Runner',     vendor: 'community/janus', version: '0.4.2', group: 'data', status: 'ok', agents: ['claude-code', 'codex'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, updated: '6 days ago', size: '1.2 MB' },
  { id: 'sql-explorer',       kind: 'skill', name: 'SQL Explorer',       vendor: 'community/janus', version: '1.0.0', group: 'data', status: 'ok', agents: ['claude-code'], scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true }, enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true }, updated: '12 hours ago', size: '720 KB' },
  { id: 'terraform-plan',     kind: 'skill', name: 'Terraform Planner',  vendor: 'community/devops', version: '0.3.0', group: null, status: 'err', agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false }, updated: '4 days ago', size: '2.1 MB', warning: 'Missing dependency: terraform >= 1.6' },

  // — plugins —
  { id: 'prettier-format',    kind: 'plugin', name: 'Prettier Formatter', vendor: 'community/devtools', version: '3.2.1', group: 'codequal', status: 'ok', agents: ['claude-code','codex','cursor'], scopes: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true }, enabled: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true }, updated: '1 month ago', size: '4.3 MB' },
  { id: 'eslint-bridge',      kind: 'plugin', name: 'ESLint Bridge',      vendor: 'community/devtools', version: '8.45.0', group: 'codequal', status: 'ok', agents: ['claude-code','cursor'], scopes: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true }, updated: '2 weeks ago', size: '6.1 MB' },
  { id: 'pytest-runner',      kind: 'plugin', name: 'pytest Runner',      vendor: 'community/devtools', version: '7.4.2', group: 'codequal', status: 'ok', agents: ['claude-code','codex'], scopes: { global: false, saas: false, cookbook: false, mcp: true, monorepo: false }, enabled: { global: false, saas: false, cookbook: false, mcp: true, monorepo: false }, updated: '3 days ago', size: '1.8 MB' },
  { id: 'docker-compose',     kind: 'plugin', name: 'Docker Compose',     vendor: 'community/infra', version: '2.21.0', group: 'infra', status: 'warn', agents: ['claude-code','codex','cursor'], scopes: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, updated: '5 days ago', size: '12.4 MB', warning: 'Daemon not running' },
  { id: 'git-blame-view',     kind: 'plugin', name: 'Git Blame Viewer',   vendor: 'community/devtools', version: '0.6.0', group: null, status: 'ok', agents: ['claude-code','cursor'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, updated: '2 months ago', size: '420 KB' },
  { id: 'terminal-snapshot',  kind: 'plugin', name: 'Terminal Snapshot',  vendor: 'kuro/tools', version: '1.0.0', group: null, status: 'off', agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false }, enabled: { global: false, saas: false, cookbook: false, mcp: false, monorepo: false }, updated: '3 weeks ago', size: '180 KB' },
  { id: 'sqlite-explore',     kind: 'plugin', name: 'SQLite Explorer',    vendor: 'community/data', version: '0.4.1', group: 'data', status: 'ok', agents: ['claude-code','cursor'], scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true }, enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true }, updated: '11 days ago', size: '2.8 MB' },
  { id: 'k8s-context',        kind: 'plugin', name: 'k8s Context',        vendor: 'community/infra', version: '1.5.0', group: 'infra', status: 'ok', agents: ['claude-code','codex'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, updated: '8 days ago', size: '5.6 MB' },

  // — MCP servers —
  { id: 'github',             kind: 'mcp', name: 'GitHub',          vendor: 'Anthropic', version: '2.4.0', group: 'codequal', status: 'ok', agents: ['claude-code','codex','cursor'], scopes: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true }, enabled: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true }, updated: '1 day ago', size: '—', auth: 'OAuth · expires 23 May 2026' },
  { id: 'linear',             kind: 'mcp', name: 'Linear',          vendor: 'Anthropic', version: '1.2.0', group: 'comms', status: 'ok', agents: ['claude-code','cursor'], scopes: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true }, updated: '4 days ago', size: '—', auth: 'API key · last used 2h ago' },
  { id: 'slack',              kind: 'mcp', name: 'Slack',           vendor: 'Anthropic', version: '0.9.1', group: 'comms', status: 'warn', agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true }, updated: '3 days ago', size: '—', auth: 'Token expires in 4 days', warning: 'Token expires in 4 days' },
  { id: 'notion',             kind: 'mcp', name: 'Notion',          vendor: 'community/wbenny', version: '0.7.2', group: 'comms', status: 'ok', agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, updated: '6 days ago', size: '—', auth: 'Internal integration' },
  { id: 'figma',              kind: 'mcp', name: 'Figma',           vendor: 'community/figmamcp', version: '1.0.3', group: 'design', status: 'ok', agents: ['claude-code','cursor'], scopes: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: true, mcp: false, monorepo: false }, updated: '2 weeks ago', size: '—', auth: 'OAuth · expires 12 Jun 2026' },
  { id: 'postgres-prod',      kind: 'mcp', name: 'Postgres · prod', vendor: 'self-hosted', version: '—', group: 'data', status: 'err', agents: ['claude-code'], scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: false }, enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: false }, updated: '—', size: '—', auth: 'Connection refused', warning: 'Connection refused at db.internal:5432' },
  { id: 'gdrive',             kind: 'mcp', name: 'Google Drive',    vendor: 'Anthropic', version: '1.1.0', group: null, status: 'ok', agents: ['claude-code'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false }, enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false }, updated: '1 month ago', size: '—', auth: 'OAuth · expires 04 Aug 2026' },
  { id: 'sentry',             kind: 'mcp', name: 'Sentry',          vendor: 'community/observe', version: '0.5.0', group: null, status: 'off', agents: ['claude-code','codex'], scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false }, enabled: { global: false, saas: false, cookbook: false, mcp: false, monorepo: false }, updated: '2 months ago', size: '—', auth: 'Not signed in' },
];

const GROUPS = [
  { id: 'design',    name: 'Design Tools',     color: 'oklch(0.66 0.16 320)', items: 5,  description: 'Skills and MCP servers for design + visual work.' },
  { id: 'codequal',  name: 'Code Quality',     color: 'oklch(0.68 0.15 152)', items: 4,  description: 'Linters, formatters, source code review.' },
  { id: 'docs',      name: 'Document Tools',   color: 'oklch(0.70 0.13 232)', items: 1,  description: 'Reading and producing documents.' },
  { id: 'export',    name: 'Export & Handoff', color: 'oklch(0.74 0.13 78)',  items: 2,  description: 'Convert artifacts to portable formats.' },
  { id: 'data',      name: 'Data & Analytics', color: 'oklch(0.66 0.18 282)', items: 4,  description: 'Database, notebook, and analytical tools.' },
  { id: 'infra',     name: 'Infrastructure',   color: 'oklch(0.55 0.005 270)', items: 2, description: 'Containers, orchestration, cloud.' },
  { id: 'comms',     name: 'Communication',    color: 'oklch(0.62 0.18 30)',  items: 3,  description: 'Team comms, project management, knowledge bases.' },
];

const MARKETPLACES = [
  { id: 'anthropic',  name: 'Anthropic Official', url: 'https://marketplace.anthropic.com', kind: 'official', items: 124, lastSync: '2h ago', enabled: true,  trust: 'verified' },
  { id: 'community',  name: 'Community Hub',      url: 'https://hub.agenttools.dev',         kind: 'community', items: 1842, lastSync: '4h ago', enabled: true,  trust: 'community' },
  { id: 'kuro',       name: 'kuro/tools',         url: 'https://github.com/kuro/agent-tools', kind: 'github', items: 28, lastSync: '1d ago', enabled: true,  trust: 'pinned' },
  { id: 'internal',   name: 'Cobalt Internal',    url: 'https://tools.cobalt.internal',      kind: 'private', items: 17, lastSync: 'never', enabled: false, trust: 'private' },
];

const MARKETPLACE_FEED = [
  { id: 'next-router',  name: 'Next.js Router',    kind: 'plugin',   vendor: 'community/devtools', installs: '12.4k', stars: 4.8, market: 'community', description: 'Auto-detects Next.js route structure and surfaces it to your agent.' },
  { id: 'stripe-mcp',   name: 'Stripe MCP',        kind: 'mcp', vendor: 'Stripe', installs: '8.1k', stars: 4.9, market: 'anthropic', description: 'Manage Stripe products, prices, subscriptions, refunds from your agent.', verified: true },
  { id: 'tldraw-skill', name: 'TLdraw Sketcher',   kind: 'skill',    vendor: 'community/visual', installs: '3.2k', stars: 4.6, market: 'community', description: 'Generates editable tldraw sketches for ideation.' },
  { id: 'opentofu',     name: 'OpenTofu Plan',     kind: 'plugin',   vendor: 'community/devops', installs: '5.7k', stars: 4.5, market: 'community', description: 'Run terraform/opentofu plan + apply with structured output.' },
  { id: 'pg-explorer',  name: 'Postgres Explorer', kind: 'mcp', vendor: 'Anthropic', installs: '22.0k', stars: 4.9, market: 'anthropic', description: 'Connect any Postgres instance; introspect schema and run queries.', verified: true },
  { id: 'rdb-skill',    name: 'Read-Big-Doc',      kind: 'skill',    vendor: 'kuro/tools', installs: '890', stars: 4.4, market: 'kuro', description: 'Reads long docs in chunks with semantic search.' },
];

const RECENT_ACTIVITY = [
  { t: '2 min ago',   what: 'Enabled',  who: 'PDF Reader',     ctx: 'mcp-tooling' },
  { t: '14 min ago',  what: 'Installed', who: 'k8s Context',   ctx: 'platform-monorepo' },
  { t: '1 h ago',     what: 'Updated',  who: 'Prettier Formatter', ctx: 'global, v3.2.0 → v3.2.1' },
  { t: '3 h ago',     what: 'Disabled', who: 'Slack',          ctx: 'cobalt-app' },
  { t: 'Yesterday',   what: 'Removed',  who: 'Old Bridge',     ctx: 'cookbook' },
];

// — Hooks —
// Hook events surfaced across the three supported agents. Codex + Claude Code
// share names; Cursor uses camelCase for tool-specific events. We unify under
// a normalized id and show agent compat per-row.
const HOOK_EVENTS = [
  { id: 'session_start',   label: 'SessionStart',       cadence: 'session', agents: ['claude-code', 'codex'],          desc: 'Fires when a session begins (startup, resume, clear).' },
  { id: 'user_prompt',     label: 'UserPromptSubmit',   cadence: 'turn',    agents: ['claude-code', 'codex'],          desc: 'Before the prompt is processed by the model.' },
  { id: 'pre_tool',        label: 'PreToolUse',         cadence: 'tool',    agents: ['claude-code', 'codex'],          desc: 'Before any tool is invoked. Exit 2 to block.' },
  { id: 'permission_req',  label: 'PermissionRequest',  cadence: 'tool',    agents: ['claude-code', 'codex'],          desc: 'Fires when the permission dialog would appear.' },
  { id: 'post_tool',       label: 'PostToolUse',        cadence: 'tool',    agents: ['claude-code', 'codex'],          desc: 'After a tool completes successfully.' },
  { id: 'post_tool_fail',  label: 'PostToolUseFailure', cadence: 'tool',    agents: ['claude-code'],                   desc: 'After a tool execution fails.' },
  { id: 'before_shell',    label: 'beforeShellExecution', cadence: 'tool',  agents: ['cursor'],                        desc: 'Cursor-only: before each shell command.' },
  { id: 'before_mcp',      label: 'beforeMCPExecution', cadence: 'tool',    agents: ['cursor'],                        desc: 'Cursor-only: before each MCP tool call.' },
  { id: 'after_file_edit', label: 'afterFileEdit',      cadence: 'tool',    agents: ['cursor'],                        desc: 'Cursor-only: after each file edit.' },
  { id: 'notification',    label: 'Notification',       cadence: 'async',   agents: ['claude-code'],                   desc: 'Permission prompts, idle prompts, auth events.' },
  { id: 'stop',            label: 'Stop',               cadence: 'turn',    agents: ['claude-code', 'codex', 'cursor'], desc: 'When the agent finishes its turn.' },
  { id: 'subagent_stop',   label: 'SubagentStop',       cadence: 'turn',    agents: ['claude-code', 'codex'],          desc: 'When a spawned subagent completes.' },
  { id: 'pre_compact',     label: 'PreCompact',         cadence: 'session', agents: ['claude-code', 'codex'],          desc: 'Before context compaction runs.' },
  { id: 'session_end',     label: 'SessionEnd',         cadence: 'session', agents: ['claude-code', 'codex'],          desc: 'When a session ends (exit, sigint, error).' },
];

// Realistic mocked hooks. type: command | http | prompt | agent
// scopes/enabled mirror item shape so workspace toggles work the same way.
const HOOKS = [
  {
    id: 'prettier-on-edit', event: 'post_tool', type: 'command',
    matcher: 'Edit|Write|MultiEdit',
    command: 'npx prettier --write "$CLAUDE_TOOL_INPUT_FILE_PATH"',
    timeout: 5000, async: false, agents: ['claude-code', 'codex'],
    scopes: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true },
    enabled: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true },
    status: 'ok', lastFired: '14s ago', firesPerHour: 38, source: 'plugin:prettier-format', trusted: true,
    description: 'Format edited files with Prettier after every write.',
  },
  {
    id: 'block-dangerous-bash', event: 'pre_tool', type: 'command',
    matcher: 'Bash',
    command: '~/.claude/hooks/block-dangerous-commands.sh',
    timeout: 2000, async: false, agents: ['claude-code', 'codex'],
    scopes: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true },
    enabled: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true },
    status: 'ok', lastFired: '3 m ago', firesPerHour: 12, source: 'user', trusted: true,
    description: 'Blocks rm -rf, mkfs, DROP TABLE and other destructive commands. Exits 2 to deny.',
  },
  {
    id: 'block-env-writes', event: 'pre_tool', type: 'command',
    matcher: 'Edit|Write',
    command: 'python3 ~/.claude/hooks/block-env-writes.py',
    timeout: 1500, async: false, agents: ['claude-code'],
    scopes: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true },
    enabled: { global: true, saas: true, cookbook: false, mcp: false, monorepo: true },
    status: 'ok', lastFired: '1 h ago', firesPerHour: 4, source: 'user', trusted: true,
    description: 'Denies edits to .env, package-lock.json and anything under .git/.',
  },
  {
    id: 'secret-scanner', event: 'pre_tool', type: 'http',
    matcher: 'Read|Edit|Write|Bash',
    command: 'http://localhost:8080/hooks/scan',
    timeout: 30000, async: false, agents: ['claude-code'],
    scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true },
    enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true },
    status: 'warn', lastFired: '8 min ago', firesPerHour: 142, source: 'plugin:secret-scan', trusted: true,
    description: 'POSTs file contents to a local scanner. Blocks if AWS keys, JWTs or PEM blobs are detected.',
    warning: 'Slow: average response 1.2s (95p: 2.4s)',
  },
  {
    id: 'gitbutler-pre',  event: 'pre_tool',  type: 'command',
    matcher: 'Edit|MultiEdit|Write',
    command: 'but claude pre-tool',
    timeout: 1500, async: false, agents: ['claude-code'],
    scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: false },
    enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: false },
    status: 'ok', lastFired: '22s ago', firesPerHour: 28, source: 'user', trusted: true,
    description: 'Snapshot virtual branch before each edit (GitButler integration).',
  },
  {
    id: 'gitbutler-stop',  event: 'stop',  type: 'command',
    matcher: '*',
    command: 'but claude stop',
    timeout: 4000, async: false, agents: ['claude-code'],
    scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: false },
    enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: false },
    status: 'ok', lastFired: '4 m ago', firesPerHour: 6, source: 'user', trusted: true,
    description: 'Commits the session work into a dedicated virtual branch on agent stop.',
  },
  {
    id: 'inject-branch', event: 'session_start', type: 'command',
    matcher: '*',
    command: `echo '{"additionalContext": "branch: '$(git branch --show-current)'"}'`,
    timeout: 1000, async: false, agents: ['claude-code', 'codex'],
    scopes: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true },
    enabled: { global: true, saas: true, cookbook: true, mcp: true, monorepo: true },
    status: 'ok', lastFired: '12 min ago', firesPerHour: 2, source: 'user', trusted: true,
    description: 'Injects current git branch into the session context at startup.',
  },
  {
    id: 'pytest-runner', event: 'post_tool', type: 'command',
    matcher: 'Edit|Write',
    command: '~/.claude/hooks/run-pytest-for-changed.sh',
    timeout: 60000, async: true, agents: ['claude-code', 'codex'],
    scopes: { global: false, saas: false, cookbook: false, mcp: true, monorepo: false },
    enabled: { global: false, saas: false, cookbook: false, mcp: true, monorepo: false },
    status: 'ok', lastFired: '38s ago', firesPerHour: 18, source: 'plugin:pytest-runner', trusted: true,
    description: 'Runs pytest for any *.py files just edited. Async — does not block the agent loop.',
  },
  {
    id: 'log-bash', event: 'pre_tool', type: 'command',
    matcher: 'Bash',
    command: 'jq -r .tool_input.command >> ~/.cache/agent/bash.log',
    timeout: 500, async: true, agents: ['claude-code', 'codex'],
    scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false },
    enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false },
    status: 'ok', lastFired: '17s ago', firesPerHour: 96, source: 'user', trusted: true,
    description: 'Appends every Bash command Claude runs to a local audit log.',
  },
  {
    id: 'slack-notify', event: 'notification', type: 'command',
    matcher: 'permission_prompt',
    command: 'osascript -e \'display notification "Claude needs you" with title "Agent"\'',
    timeout: 1000, async: true, agents: ['claude-code'],
    scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false },
    enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false },
    status: 'ok', lastFired: '1 h ago', firesPerHour: 1, source: 'user', trusted: true,
    description: 'Surfaces a desktop banner whenever Claude asks for input.',
  },
  {
    id: 'mcp-audit', event: 'before_mcp', type: 'command',
    matcher: '*',
    command: 'node ~/.cursor/hooks/audit-mcp.js',
    timeout: 2000, async: false, agents: ['cursor'],
    scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true },
    enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true },
    status: 'ok', lastFired: '6 m ago', firesPerHour: 8, source: 'user', trusted: true,
    description: 'Logs every MCP tool call Cursor makes to a local SQLite file for later audit.',
  },
  {
    id: 'checkpoint-commit', event: 'after_file_edit', type: 'command',
    matcher: '*',
    command: '~/.cursor/hooks/checkpoint.sh',
    timeout: 2500, async: true, agents: ['cursor'],
    scopes: { global: false, saas: false, cookbook: false, mcp: false, monorepo: true },
    enabled: { global: false, saas: false, cookbook: false, mcp: false, monorepo: true },
    status: 'ok', lastFired: '54s ago', firesPerHour: 22, source: 'user', trusted: true,
    description: 'Stashes a checkpoint after every Cursor file edit, so any change can be unwound.',
  },
  {
    id: 'untrusted-fmt', event: 'post_tool', type: 'command',
    matcher: 'Edit|Write',
    command: 'curl -fsSL https://hooks.kuro.dev/format.sh | bash',
    timeout: 5000, async: false, agents: ['claude-code', 'codex'],
    scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: false },
    enabled: { global: false, saas: false, cookbook: false, mcp: false, monorepo: false },
    status: 'err', lastFired: '—', firesPerHour: 0, source: 'plugin:kuro-tools', trusted: false,
    description: 'Newly added by kuro/tools. Awaiting your review — runs untrusted shell from a remote URL.',
    warning: 'Untrusted source — review before enabling.',
  },
  {
    id: 'typecheck-tsx', event: 'post_tool', type: 'command',
    matcher: 'Edit|Write',
    command: 'npx tsc --noEmit -p tsconfig.json',
    timeout: 60000, async: true, agents: ['claude-code', 'cursor'],
    scopes: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true },
    enabled: { global: false, saas: true, cookbook: false, mcp: false, monorepo: true },
    status: 'ok', lastFired: '3 m ago', firesPerHour: 14, source: 'user', trusted: true,
    description: 'Runs the TypeScript compiler after each edit to surface type errors immediately.',
  },
  {
    id: 'subagent-cost', event: 'subagent_stop', type: 'command',
    matcher: '*',
    command: '~/.claude/hooks/log-subagent-usage.py',
    timeout: 2000, async: true, agents: ['claude-code', 'codex'],
    scopes: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true },
    enabled: { global: true, saas: false, cookbook: false, mcp: false, monorepo: true },
    status: 'ok', lastFired: '11 min ago', firesPerHour: 3, source: 'user', trusted: true,
    description: 'Records token cost per subagent call to a CSV for monthly reconciliation.',
  },
];

Object.assign(window, { WORKSPACES, AGENTS, ITEMS, GROUPS, MARKETPLACES, MARKETPLACE_FEED, RECENT_ACTIVITY, HOOK_EVENTS, HOOKS });
