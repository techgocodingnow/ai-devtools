# PRD – macOS Swift/SwiftUI Agent Capability Manager

## 1. Overview

This product is a native macOS Swift/SwiftUI application that manages AI agent capabilities (skills, plugins, connectors, MCP servers) at both global and per‑project scope, inspired by Claude Desktop / Claude Code’s customization model.[web:38][web:52] The v1 is optimized for a single “Claude Code–style” agent but keeps the data model ready for multiple agents in future. Users should be able to easily install capabilities from a marketplace or GitHub, toggle them on/off globally or per project, and inspect details.

## 2. Goals and non‑goals

### 2.1 Goals

- Provide a unified UI to manage skills, plugins, connectors, and MCP servers globally and per project.
- Make it trivial to:
  - Turn capabilities on/off per project or globally via simple toggles.
  - Install new capabilities from a marketplace or directly from a GitHub repo.
  - Inspect details (description, source, files) of any skill/plugin/connector/MCP.
- Support configuration of a Claude Code–style agent that consumes the project’s effective toolset.
- Automatically detect projects that already contain Claude-style skills/plugins/MCP markers, and let users manually scan arbitrary folders.

### 2.2 Non‑goals (v1)

- Full chat/editor integration with Claude Code (v1 can stop at “config + export agent config”; UI for conversations is optional).
- Advanced team collaboration features (multi-user, sync, permissions).
- Rich auth flows (full OAuth UI flows per connector) – v1 can assume token-based/manual entry for most connectors.
- Complex marketplace management (ratings, billing, reviews, etc.).

## 3. Target users and personas

- **Indie / small-team developers** using Claude Code and MCP tools, wanting a local GUI to manage skills/plugins across many projects.
- **Power users** with multiple codebases and custom Claude plugins who want a central place to see what’s installed and where.[web:52][web:54]
- **Future**: organizations with standardized plugin sets and internal MCP servers (out of scope for v1).

## 4. Key concepts and terminology

The app mirrors Claude’s semantics for capabilities.[web:38][web:52][web:54]

- **Skill**  
  - A folder containing a `SKILL.md` file with YAML frontmatter and markdown instructions.[web:38][web:52]  
  - May live in global (`~/.claude/skills/`) or project-local directories (`./skills/`, `./.claude/skills/`, nested `.claude/skills/`).  
- **Plugin**  
  - A directory with `.claude-plugin/plugin.json` manifest plus optional `skills/`, `agents/`, `commands/`, `hooks/`, and `.mcp.json`.[web:38][web:48][web:52]  
- **Connector**  
  - An integration to an external service (e.g., Gmail, Slack) that exposes tools to the agent; may be backed by MCP servers.
- **MCP server**  
  - A Model Context Protocol endpoint exposing tools and context that the agent can call; may be local or remote.

- **Global configuration**  
  - Default on/off state for each capability, independent of any project.
- **Project configuration**  
  - Overrides to global state for a specific project (enable/disable/inherit per capability).
- **Agent**  
  - A logical AI assistant configuration (v1: “Claude Code”), consuming the effective capabilities for a project.

## 5. High-level UX

### 5.1 Main navigation

- macOS-style three-column layout using `NavigationSplitView`:
  - Sidebar: sections for **Projects**, **Global**, **Marketplace**, **MCP / Connectors**.[web:39][web:57]
  - Content: list of items for the current section (projects list, global capabilities, marketplace items, MCP servers).
  - Detail: details for the currently selected project or capability.

### 5.2 Core user flows

1. **Browse and configure global capabilities**
   - View a combined list of all installed skills, plugins, connectors, MCP servers.
   - Toggle them globally on/off.
   - Open detail pages to see description, location, and (for plugins) structure.

2. **Configure a project**
   - Select a project.
   - See tabs for Skills / Plugins / Connectors / MCP.
   - Each tab shows items, with:
     - Toggle to enable/disable in this project.
     - Indicator whether state is inherited or overridden.
   - User can reset any item to inherit global state.

3. **Project detection**
   - Optional automatic discovery:
     - On first launch, user is asked to opt in and define default scan roots (e.g., `~/Projects`, `~/Developer`).  
     - Scans for Claude markers (e.g., `.claude-plugin/plugin.json`, `skills/*/SKILL.md`, `.mcp.json`, `agents/`) and suggests discovered projects.[web:48][web:52]
   - Manual detection:
     - User picks a folder via folder picker.
     - App runs detection, summarizes counts (skills, plugins, MCP, agents), and lets user “Add as project”.

4. **Install from marketplace**
   - User opens Marketplace section.
   - Browse a catalog of capabilities (skills/plugins/connectors/MCP) from one or more JSON feeds.
   - Click “Install” to:
     - Download/clone GitHub repo.
     - Scan for `.claude-plugin/plugin.json` and `SKILL.md` skills.
     - Register new plugin/skills in the registry.

5. **Install from GitHub**
   - User selects “Install from GitHub…” and pastes a repo URL.
   - Same pipeline as marketplace install, but source is user-provided repo.

6. **Configure MCP servers**
   - MCP / Connectors section lists:
     - All MCP servers (from plugins, standalone configs).
     - Connectors referencing those MCP servers or native integrations.
   - User can:
     - Add/edit/delete MCP servers (URL, label, auth settings).
     - Test connection.
     - Toggle usage globally and per project.

7. **Export / use agent configuration**
   - For a given project and agent:
     - App computes effective capability set.
     - Produces a configuration object suitable for the Claude Code backend (system prompts from SKILL.md, tool definitions from connectors/MCP).
   - V1: this can be exposed as a JSON preview and/or an internal object used by a later chat UI.

## 6. Functional requirements

### 6.1 Global capability management

- List all installed skills, plugins, connectors, MCP servers with:
  - Name, type, short description, tags, source (GitHub/marketplace/local).
- Enable/disable any item globally via toggle.
- Detail view for each item:
  - Skills: show `SKILL.md` content rendered as markdown (optional v1) and disk location.[web:38][web:52]
  - Plugins: show manifest metadata, root directory, list of contained skills / agents / MCP servers.[web:48][web:52]
  - Connectors: show service type, backing MCP server if any, and connection status.
  - MCP servers: show URL, description, auth type, and test connection result.

### 6.2 Project management

- Create projects by:
  - Automatic discovery (user confirms).
  - Manual folder selection.
- For each project:
  - Show name and root path.
  - Store last scanned time and scan results (capabilities detected).
  - Allow per-capability override: inherit / enabled / disabled.

### 6.3 Project detection

- Configurable scan roots.
- Detection of Claude-style markers:
  - `skills/<skill-name>/SKILL.md`.
  - `.claude/skills/<skill-name>/SKILL.md`.
  - `.claude-plugin/plugin.json`.
  - `.mcp.json`.
  - `agents/` directories (optional v1 parsing).
- Project root detection via:
  - Walking up from marker directories to nearest `.git` or top-level folder.
- Background scanning and caching (avoid rescanning unchanged folders).

### 6.4 Marketplace integration

- Load catalog from one or more HTTP endpoints returning JSON arrays of items.
- Show item list with filters by type and tags.
- Perform install from repository URL embedded in each item.

### 6.5 GitHub installer

- Accept HTTPS GitHub repo URL.
- Download repo as ZIP (or via Git) to app data directory.
- Unpack and scan for:
  - `.claude-plugin/plugin.json` to create `Plugin` entities.
  - `skills/*/SKILL.md` to create `Skill` entities.
  - `.mcp.json` to create `MCPServer` entities.[web:48][web:52][web:54]

### 6.6 MCP / connector management

- Allow user to:
  - Add an MCP server (label, URL, optional token).
  - Edit / delete MCP server.
  - Test connection (basic handshake).
- Connectors:
  - Represent as a logical integration pointing to one or more MCP servers or native APIs.
  - Toggle globally and per project.

### 6.7 Agent configuration (Claude Code v1)

- Support at least one agent type: “Claude Code”.
- For each project:
  - Show effective capabilities that will be used by Claude Code.
  - Produce a JSON-like configuration object that:
    - Aggregates SKILL.md contents.
    - Lists tools/connectors/MCP servers with identifiers and URLs.[web:38][web:52][web:54]

## 7. Non-functional requirements

- Platform: macOS (latest 2–3 OS versions), Swift + SwiftUI.
- Persistence:
  - Use JSON or SQLite for app config; prefer Codable for model persistence.[web:49][web:53]
- Performance:
  - Background scanning of filesystem; do not block UI.
  - Avoid full-tree scans of massive directories.
- Security:
  - Store secrets (tokens, API keys) in Keychain.
  - Do not send local paths or contents to external services without explicit user action.
- UX:
  - Use `NavigationSplitView` for a native macOS sidebar+content+detail layout.[web:39][web:57]
  - Respect system appearance and accessibility where possible.

## 8. Out-of-scope (explicit)

- Running MCP servers themselves (only configuration/registration).
- Multi-user state sync or cloud backup.
- Plugin publishing tools (authoring plugins is out-of-scope; only installation/consumption).
