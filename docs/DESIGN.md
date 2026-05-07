# DESIGN – macOS Swift/SwiftUI Agent Capability Manager

## 1. Architecture overview

The app is a single-process SwiftUI macOS application with:

- A **UI layer** built with SwiftUI (using `NavigationSplitView` for macOS-style sidebar and content structure).[web:39][web:57]
- **Domain models** representing capabilities (skills, plugins, connectors, MCP servers), projects, and agents.
- **Stores/services** that own shared state: registry of capabilities, projects store, marketplace service, installer service, and project discovery service.
- A **persistence layer** that stores these models in JSON or SQLite using Codable.[web:49][web:53]
- Integration stubs for backend/Claude Code configuration export.

## 2. Technology choices

- Language: Swift (latest stable).
- UI: SwiftUI, using `NavigationSplitView` for three-column layout.[web:39][web:50][web:57]
- Persistence: Codable-based JSON storage (local files) for v1; future-proofed to swap to SQLite.
- Network: `URLSession` for HTTP calls (marketplace catalog, repo downloads).
- Unzipping: Apple’s `Archive` APIs or a minimal third-party zip library.
- Keychain: use Security framework for secure token storage.

## 3. Data model

### 3.1 Core structs

- `Skill`
  - `id: UUID`
  - `name: String`
  - `summary: String`
  - `tags: [String]`
  - `location: URL` (directory containing SKILL.md)
  - `skillFile: URL` (path to SKILL.md)
  - `pluginID: UUID?` (owner plugin if any)
- `Plugin`
  - `id: UUID`
  - `name: String`
  - `summary: String`
  - `version: String?`
  - `tags: [String]`
  - `rootDirectory: URL` (plugin root)
  - `skillIDs: [UUID]`
  - `mcpServerIDs: [UUID]`
- `MCPServer`
  - `id: UUID`
  - `label: String`
  - `serverURL: URL`
  - `description: String`
  - `authType: String?` (e.g., token, oauth)
  - `isGlobal: Bool`
- `Connector`
  - `id: UUID`
  - `name: String`
  - `serviceType: String`
  - `backingMCPServerID: UUID?`
  - `isGlobal: Bool`
- `Agent` (v1 mostly Claude Code)
  - `id: UUID`
  - `name: String`
  - `type: AgentType` (`.code`, `.chat` future)
  - `defaultCapabilities: [CapabilityRef]`
- `Project`
  - `id: UUID`
  - `name: String`
  - `rootPath: URL`
  - `lastScannedAt: Date?`
  - `overrides: [CapabilityRef: CapabilityScopeOverride]`

Auxiliary:

- `CapabilityKind`: `.skill`, `.plugin`, `.connector`, `.mcpServer`
- `CapabilityRef`: `{ kind: CapabilityKind, id: UUID }`
- `CapabilityScopeOverride`: `.inherit`, `.enabled`, `.disabled`

### 3.2 Manifest models

To parse Claude plugin manifests (`.claude-plugin/plugin.json`), define:

- `PluginManifest` (Codable):  
  - `name: String`  
  - `description: String`  
  - `version: String?`  
  - `tags: [String]?`  
  - `skills: [SkillEntry]?` where `SkillEntry { name: String; path: String }`.[web:38][web:48][web:52]

Optionally add other sections for `agents`, `commands`, `hooks`, `mcpServers` as the schema evolves.[web:38][web:52][web:54]

## 4. Stores & services

### 4.1 RegistryStore

- Responsibilities:
  - Holds in-memory maps for `skills`, `plugins`, `connectors`, `mcpServers`, `agents`.
  - Holds global enabled/disabled state: `[CapabilityRef: Bool]`.
  - Provides functions:
    - `isGloballyEnabled(_ ref: CapabilityRef) -> Bool`
    - `setGlobal(_ ref: CapabilityRef, enabled: Bool)`
    - lookups from `CapabilityRef` → concrete entity.
- Implementation:
  - `@Observable` (or `ObservableObject`) class injected into environment for SwiftUI binding.

### 4.2 ProjectsStore

- Responsibilities:
  - Manages `projects: [UUID: Project]`.
  - Keeps `selectedProjectID`.
  - API:
    - `addOrUpdate(_ project: Project)`
    - `setOverride(projectID, CapabilityRef, CapabilityScopeOverride)`
    - `effectiveState(for projectID, CapabilityRef, global: Bool) -> Bool`.

### 4.3 ProjectDiscoveryService

- Responsibilities:
  - Automatic and manual discovery of projects.
  - Maintain list of “discovered” candidates separate from “managed” projects.
- Logic:
  - Configurable scan roots (`[URL]`) from user settings.
  - For each root:
    - Enumerate child directories (shallow).
    - Detect markers:
      - `skills/*/SKILL.md` or `.claude/skills/*/SKILL.md`.
      - `.claude-plugin/plugin.json`.
      - `.mcp.json`.
      - `agents/` folders.[web:48][web:52]
    - Use “directory bubbling” from detected marker path up to repo root (nearest `.git` or top-level folder).
  - Cache last scan times and markers per path.

### 4.4 MarketplaceService

- Responsibilities:
  - Fetch marketplace catalog(s) from configured endpoints.
  - Expose `[MarketplaceItem]` and loading/error state.
- Implementation:
  - Simple Codable decode from JSON into `MarketplaceItem`.
  - Items include at minimum `id`, `name`, `summary`, `tags`, `repoURL`.

### 4.5 PluginInstaller

- Responsibilities:
  - Given a repo URL, download, unpack, and register plugin/skills/MCP servers.
- Steps:
  1. Compute ZIP download URL (e.g. GitHub `archive/refs/heads/main.zip`).
  2. Download to temporary file via `URLSession`.
  3. Unzip to `Application Support/<BundleID>/Packages/<random-or-slug>` directory.
  4. Search recursively for `.claude-plugin/plugin.json`.[web:48][web:52]
  5. Decode `PluginManifest` using `JSONDecoder`.[web:49][web:53]
  6. Construct `Plugin` + `Skill` + `MCPServer` entities and store them in `RegistryStore`.
- Error handling:
  - Provide user feedback (toast/alert) on failure to download, unzip, or parse manifest.

## 5. Persistence

- Use a `PersistenceService` that:
  - Serializes `RegistryStore` and `ProjectsStore` models to JSON in Application Support.
  - Loads on app startup and writes on changes (with debounce).
- Files:
  - `registry.json` – includes skills/plugins/connectors/MCP/agents metadata and global state (but not secrets).
  - `projects.json` – includes project records and overrides.
- Secrets (tokens) are stored separately in Keychain, referenced by identifiers from `Connector` or `MCPServer`.

## 6. Navigation and UI composition

### 6.1 Root navigation

- Use `NavigationSplitView` with:
  - Sidebar: `SidebarItem` enum with `.projects`, `.global`, `.marketplace`, `.mcpServers`.
  - Content: `View` depending on selected sidebar item:
    - `.projects` → `ProjectsListView`
    - `.global` → `GlobalCapabilitiesListView`
    - `.marketplace` → `MarketplaceView`
    - `.mcpServers` → `MCPServersListView`
  - Detail: `CapabilityDetailView` for selected capability.[web:39][web:50][web:57]

### 6.2 GlobalCapabilitiesListView

- Shows a flat list of all capabilities (skills, plugins, connectors, MCP).
- Each row:
  - Name + type/tag.
  - Global toggle bound to `RegistryStore`.
- Selection drives detail view.

### 6.3 ProjectsListView & ProjectDetailView

- ProjectsListView:
  - Left column: list of projects with name and path.
  - On selection: shows `ProjectDetailView`.
- ProjectDetailView:
  - Tabs for Skills / Plugins / Connectors / MCP.
  - Each tab reuses list row components but:
    - Displays effective state (computed from global + override).
    - Shows indicator “Inherited” vs “Overridden”.
  - Toggle writes to project overrides.

### 6.4 MarketplaceView

- Shows marketplace items (with filter by type/tags).
- “Install” button:
  - Calls `PluginInstaller.install(fromGitHubRepo:)`.
  - On success, updates registry.
- “Install from GitHub…”:
  - Presents modal to paste a repo URL.
  - Reuses same installer.

### 6.5 MCP / Connectors views

- MCPServersListView:
  - List of MCP servers.
  - Each row: label, URL, toggle global usage, connection status.
  - Detail: edit fields, “Test connection” button.
- ConnectorsView:
  - List of connectors with backing MCP servers and statuses.
  - Specific per-project connector toggles can be shown in ProjectDetailView under Connectors tab.

## 7. Project detection algorithm details

1. **Scan roots**: user-configured; default includes `~/Projects` and `~/Developer`.
2. **Enumerate folders**: shallow folder listing for each root; use heuristics to skip obviously irrelevant folders.
3. **Detect markers**:
   - Files: `SKILL.md` under known pattern directories, `.claude-plugin/plugin.json`, `.mcp.json`.[web:48][web:52]
   - Folders: `agents/` indicating presence of agents for a plugin.[web:52][web:54]
4. **Determine project root**:
   - If marker path is `.../my-project/.claude-plugin/plugin.json`, project root is `.../my-project`.
   - If marker path is `.../my-monorepo/packages/frontend/.claude/skills/...`, walk up until `.git` or top-level.
5. **Record discovered project**:
   - Generate `Project` record with path, lastScannedAt, and list of markers found.
   - Show in “Discovered” section until user accepts it as a managed project.

## 8. Agent configuration export

- Define an internal type:

  ```swift
  struct AgentSessionConfig: Codable {
      var agentID: UUID
      var projectID: UUID
      var skills: [SkillConfig]
      var tools: [ToolConfig] // connectors + MCP tools
      var systemPrompt: String
  }
	•	To build for Claude Code:
	•	Gather all enabled skills for project + agent, and concatenate SKILL.md instructions into  systemPrompt  or store as an array.
	•	Convert enabled connectors and MCP servers into  ToolConfig  objects suitable for the downstream Claude client.web:38web:52web:54
	•	This object can later be used by a chat/editor integration layer.
9. Security & privacy
	•	All filesystem scanning is local; no paths or contents are sent externally.
	•	SKILL.md / manifest contents are only parsed locally for UI display and configuration.
	•	Tokens and secrets are stored in Keychain, not in JSON or logs.
	•	UI clearly shows which connectors/MCP servers are active for each project and allows single-click revocation.
10. Future extensions
	•	Multi-agent UI:
	•	Allow plugins to define agents via  agents/  dirs and manifest entries.web:52web:54
	•	Let users choose different agents per project.
	•	Richer marketplace:
	•	Multiple catalogs, search, ratings.
	•	IDE integration:
	•	Export configuration into files consumed by other tools, or provide CLI.