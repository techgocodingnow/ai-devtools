import SwiftUI
import Combine

enum Screen: Hashable {
    case library, itemDetail, marketplace, sources, groups, agents, hooks
    var label: String {
        switch self {
        case .library, .itemDetail: return "Library"
        case .marketplace: return "Marketplace"
        case .sources: return "Sources"
        case .groups: return "Groups"
        case .agents: return "Agents"
        case .hooks: return "Hooks"
        }
    }
}

enum StatusFilter: String { case all, enabled, disabled, issues }
enum ViewMode: String { case list, grid }
enum DetailTab: String, CaseIterable { case overview, config, permissions, logs, source
    var label: String {
        switch self {
        case .overview: return "Overview"
        case .config: return "Configuration"
        case .permissions: return "Permissions"
        case .logs: return "Activity"
        case .source: return "Source"
        }
    }
}
enum HookStatusFilter: String { case all, enabled, disabled, untrusted, issues }

/// Single source of truth for the redesigned UI.
///
/// Backed by the real on-disk registry (`~/.claude`), Claude Desktop config, project
/// discovery, installed-agent detection, and `settings.json` hooks. The published arrays
/// the screens read are projections of those stores; mutations write back through the
/// stores and persist. There is no seeded fallback — empty disk state yields empty screens.
@MainActor
final class AppStore: ObservableObject {
    // navigation
    @Published var screen: Screen = .library
    @Published var openItemId: String?
    @Published var detailTab: DetailTab = .overview
    @Published var showOnboarding = false

    // workspace
    @Published var workspace: String = "global"
    @Published var wsMenuOpen = false

    // data (projections of the real stores)
    @Published var items: [Item] = []
    @Published var agents: [AgentInfo] = []
    @Published var groups: [Group] = []
    @Published var marketplaces: [MarketplaceSource] = []
    @Published var feed: [FeedItem] = []
    @Published var hooks: [Hook] = []
    @Published var hookEvents: [HookEvent] = SeedData.hookEvents   // lifecycle taxonomy (reference data)
    @Published var workspaces: [Workspace] = []

    // library filters
    @Published var kindFilter: ItemKind?
    @Published var groupFilter: String?
    @Published var statusFilter: StatusFilter = .all
    @Published var viewMode: ViewMode = .list
    @Published var search = ""

    // marketplace filters
    @Published var marketKindFilter: ItemKind?
    @Published var marketSource: String = "all"

    // groups
    @Published var selectedGroup: String = ""

    // hooks
    @Published var hookEventFilter: String?
    @Published var hookAgentFilter: String?
    @Published var hookStatusFilter: HookStatusFilter = .all
    @Published var selectedHookId: String?
    @Published var showHookForm = false
    @Published var collapsedEvents: Set<String> = []

    // misc
    @Published var scanning = false
    @Published var loaded = false

    // MARK: - Real backing stores / services

    private let registry = RegistryStore()
    private let projectsStore = ProjectsStore()
    private let persistence = PersistenceService()
    private lazy var importer = ClaudeHomeImporter(registry: registry)
    private let desktopConfig = ClaudeDesktopConfigService()
    private let settings = ClaudeSettingsService()
    private let discovery = ProjectDiscoveryService()
    private let detector = AgentDetectionService()
    private let catalog = MarketplaceCatalogService()

    /// UI item id → registry ref, so mutations resolve back to the right entity.
    private var itemRefs: [String: CapabilityRef] = [:]
    /// workspace id → managed project id (global has none).
    private var projectIDByWorkspace: [String: UUID] = [:]

    init() {
        Task { await load() }
    }

    // MARK: - Load

    /// Full load from disk: restore persisted state, import `~/.claude`, read Desktop config,
    /// detect agents, discover projects, read hooks, then project everything into the UI arrays.
    func load() async {
        try? persistence.loadRegistry(into: registry)
        try? persistence.loadProjects(into: projectsStore)

        importer.runImport()
        for server in desktopConfig.loadServers() {
            if !registry.mcpServers.values.contains(where: { $0.label.lowercased() == server.label.lowercased() }) {
                registry.upsert(server)
                if registry.globalEnabled[server.ref] == nil { registry.setGlobal(server.ref, enabled: true) }
            }
        }

        let detected = await detector.detect()
        let discoveredProjects = await discovery.discoverProjects()
        for project in discoveredProjects { projectsStore.promoteDiscovered(project) }

        rebuildAll(detected: detected)
        loaded = true
        persist()
        await loadFeed()
    }

    /// Fetch the plugin catalog for each GitHub-backed marketplace and project it into the feed.
    /// Also backfills each source's item count. Network-best-effort; failures leave the feed empty.
    func loadFeed() async {
        let sources = marketplaces.compactMap { MarketplaceCatalogService.source(id: $0.id, url: $0.url) }
        guard !sources.isEmpty else { return }
        let results = await catalog.fetchAll(sources)

        var feedItems: [FeedItem] = []
        for result in results {
            let verified = marketplaces.first { $0.id == result.marketID }?.trust == .verified
            if let i = marketplaces.firstIndex(where: { $0.id == result.marketID }) {
                marketplaces[i].items = result.items.count
                marketplaces[i].lastSync = "just now"
            }
            for item in result.items {
                feedItems.append(FeedItem(
                    id: item.id, name: item.name, kind: .plugin, vendor: item.vendor,
                    installs: "—", stars: 0, market: result.marketID,
                    description: item.description, verified: verified
                ))
            }
        }
        feed = feedItems.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var detectedAgents: [AgentDetectionService.DetectedAgent] = []

    private func rebuildAll(detected: [AgentDetectionService.DetectedAgent]) {
        detectedAgents = detected
        rebuildAgents()
        rebuildWorkspaces()
        rebuildItems()
        rebuildGroups()
        rebuildMarketplaces()
        rebuildHooks()
        if selectedGroup.isEmpty { selectedGroup = groups.first?.id ?? "" }
    }

    // MARK: - Derived

    var currentWorkspace: Workspace {
        workspaces.first { $0.id == workspace } ?? workspaces.first ?? Workspace(
            id: "global", name: "Global", path: "~/.claude", scope: .global, initials: "G", colorLCH: nil, agents: []
        )
    }
    func agent(_ id: String) -> AgentInfo? { agents.first { $0.id == id } }
    func group(_ id: String?) -> Group? { id.flatMap { gid in groups.first { $0.id == gid } } }
    var openItem: Item? { openItemId.flatMap { id in items.first { $0.id == id } } }

    // MARK: - Navigation

    func nav(_ screen: Screen, kind: ItemKind? = nil, group: String? = nil) {
        self.screen = screen
        kindFilter = kind
        groupFilter = group
        wsMenuOpen = false
        openItemId = nil
    }

    func openItem(_ id: String) {
        screen = .itemDetail
        openItemId = id
        detailTab = .overview
    }

    // MARK: - Workspace

    func switchWorkspace(_ id: String) {
        workspace = id
        wsMenuOpen = false
    }

    private var detectedAgentIDs: [String] { detectedAgents.filter(\.detected).map(\.id) }

    // MARK: - Item mutations (write through to the registry / project overrides)

    func toggleEnabled(_ id: String, _ value: Bool) {
        applyEnable(id, ws: workspace, value)
    }
    func setScopeEnabled(_ id: String, ws: String, _ value: Bool) {
        applyEnable(id, ws: ws, value)
    }
    func installScope(_ id: String, ws: String) {
        guard let ref = itemRefs[id] else { return }
        if ws == "global" {
            registry.setGlobal(ref, enabled: true)
        } else if let pid = projectIDByWorkspace[ws] {
            projectsStore.setOverride(projectID: pid, ref: ref, value: .enabled)
        }
        rebuildItems()
        persist()
    }

    private func applyEnable(_ id: String, ws: String, _ value: Bool) {
        guard let ref = itemRefs[id] else { return }
        if ws == "global" {
            registry.setGlobal(ref, enabled: value)
        } else if let pid = projectIDByWorkspace[ws] {
            projectsStore.setOverride(projectID: pid, ref: ref, value: value ? .enabled : .disabled)
        }
        rebuildItems()
        persist()
    }

    private func persist() {
        persistence.scheduleSave(registry: registry, projects: projectsStore)
    }

    // MARK: - Marketplace

    func toggleMarketplace(_ id: String, _ value: Bool) {
        guard let i = marketplaces.firstIndex(where: { $0.id == id }) else { return }
        marketplaces[i].enabled = value
    }

    // MARK: - Hooks (read-only backed; toggles are in-memory — we never rewrite the user's settings.json)

    func toggleEvent(_ id: String) {
        if collapsedEvents.contains(id) { collapsedEvents.remove(id) } else { collapsedEvents.insert(id) }
    }
    func toggleHook(_ id: String, _ value: Bool) {
        guard let i = hooks.firstIndex(where: { $0.id == id }) else { return }
        hooks[i].enabled[workspace] = value
    }
    func setHookScope(_ id: String, ws: String, _ value: Bool) {
        guard let i = hooks.firstIndex(where: { $0.id == id }) else { return }
        hooks[i].enabled[ws] = value
    }
    func addHookScope(_ id: String, ws: String) {
        guard let i = hooks.firstIndex(where: { $0.id == id }) else { return }
        hooks[i].scopes[ws] = true
        hooks[i].enabled[ws] = true
    }
    var selectedHook: Hook? { selectedHookId.flatMap { id in hooks.first { $0.id == id } } }

    // MARK: - Rescan (real)

    func rescan() {
        guard !scanning else { return }
        scanning = true
        Task { @MainActor in
            let detected = await detector.detect()
            let discoveredProjects = await discovery.discoverProjects()
            for project in discoveredProjects { projectsStore.promoteDiscovered(project) }
            importer.runImport()
            rebuildAll(detected: detected)
            persist()
            scanning = false
            await loadFeed()
        }
    }

    // MARK: - Projections

    private func rebuildAgents() {
        agents = detectedAgents.map { d in
            AgentInfo(
                id: d.id,
                name: d.name,
                vendor: d.vendor,
                version: d.version ?? "—",
                binary: d.binaryPath,
                colorLCH: Self.agentColor(d.id),
                initials: Self.agentInitials(d.id),
                detected: d.detected,
                supports: Self.agentSupports(d.id)
            )
        }
    }

    private func rebuildWorkspaces() {
        var result: [Workspace] = [
            Workspace(id: "global", name: "Global", path: "~/.claude", scope: .global,
                      initials: "G", colorLCH: nil, agents: detectedAgentIDs)
        ]
        projectIDByWorkspace = [:]
        for project in projectsStore.orderedProjects {
            let wsID = project.id.uuidString
            projectIDByWorkspace[wsID] = project.id
            let hue = Double(abs(project.name.hashValue) % 360)
            result.append(Workspace(
                id: wsID,
                name: project.name,
                path: Self.abbreviate(project.rootPath.path),
                scope: .project,
                initials: String(project.name.prefix(1)).uppercased(),
                colorLCH: LCH(l: 0.66, c: 0.16, h: hue),
                agents: detectedAgentIDs
            ))
        }
        workspaces = result
        if !workspaces.contains(where: { $0.id == workspace }) { workspace = "global" }
    }

    private func rebuildItems() {
        var result: [Item] = []
        var seenIDs: Set<String> = []
        itemRefs = [:]

        func uid(_ base: String) -> String {
            var candidate = base.isEmpty ? "item" : base
            var n = 2
            while seenIDs.contains(candidate) { candidate = "\(base)-\(n)"; n += 1 }
            seenIDs.insert(candidate)
            return candidate
        }

        // Skills
        for skill in registry.skills.values {
            let id = uid(Self.slug(skill.name))
            itemRefs[id] = skill.ref
            let exists = FileManager.default.fileExists(atPath: skill.skillFile.path)
            result.append(makeItem(
                id: id, kind: .skill, ref: skill.ref, name: skill.name,
                version: "—",
                group: groupKey(skillPluginID: skill.pluginID, name: skill.name, tags: skill.tags),
                location: skill.location,
                summary: skill.summary, origin: skill.origin,
                ok: exists, missingMessage: "SKILL.md not found at \(skill.location.lastPathComponent)",
                auth: nil
            ))
        }
        // Plugins
        for plugin in registry.plugins.values {
            let id = uid(Self.slug(plugin.name))
            itemRefs[id] = plugin.ref
            let exists = FileManager.default.fileExists(atPath: plugin.rootDirectory.path)
            result.append(makeItem(
                id: id, kind: .plugin, ref: plugin.ref, name: plugin.name,
                version: plugin.version ?? "—",
                group: plugin.tags.first.map(Self.slug),
                location: plugin.rootDirectory,
                summary: plugin.summary, origin: plugin.origin,
                ok: exists, missingMessage: "Install path missing",
                auth: nil
            ))
        }
        // MCP servers
        for server in registry.mcpServers.values {
            let id = uid(Self.slug(server.label))
            itemRefs[id] = server.ref
            result.append(makeItem(
                id: id, kind: .mcp, ref: server.ref, name: server.label,
                version: "—",
                group: ownerPluginGroup(forMCP: server.id),
                location: nil,
                summary: server.description, origin: server.origin,
                ok: true, missingMessage: nil,
                auth: server.authType
            ))
        }

        items = result.sorted {
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func makeItem(
        id: String, kind: ItemKind, ref: CapabilityRef, name: String, version: String,
        group: String?, location: URL?, summary: String, origin: CapabilityOrigin,
        ok: Bool, missingMessage: String?, auth: String?
    ) -> Item {
        var scopes: [String: Bool] = [:]
        var enabled: [String: Bool] = [:]
        let global = registry.isGloballyEnabled(ref)
        for ws in workspaces {
            if ws.scope == .global {
                scopes[ws.id] = true
                enabled[ws.id] = global
            } else if let pid = projectIDByWorkspace[ws.id] {
                let installed = projectsStore.projects[pid]?.overrides[ref] != nil
                scopes[ws.id] = installed
                enabled[ws.id] = installed ? projectsStore.effectiveState(projectID: pid, ref: ref, global: global) : false
            }
        }
        let supported = detectedAgents.filter { Self.agentSupports($0.id).contains(kind) }.map(\.id)
        return Item(
            id: id, kind: kind, name: name, vendor: origin.displayLabel, version: version,
            group: group, status: ok ? .ok : .err, agents: supported,
            scopes: scopes, enabled: enabled,
            updated: location.map(Self.relativeModified) ?? "—",
            size: location.map(Self.directorySize) ?? "—",
            description: summary.isEmpty ? nil : summary,
            warning: ok ? nil : missingMessage,
            auth: auth
        )
    }

    private func groupKey(skillPluginID: UUID?, name: String, tags: [String]) -> String? {
        if let pid = skillPluginID, let p = registry.plugins[pid] { return Self.slug(p.name) }
        if name.contains(":"), let prefix = name.split(separator: ":").first { return Self.slug(String(prefix)) }
        return tags.first.map(Self.slug)
    }

    private func ownerPluginGroup(forMCP id: UUID) -> String? {
        for plugin in registry.plugins.values where plugin.mcpServerIDs.contains(id) {
            return Self.slug(plugin.name)
        }
        return nil
    }

    private func rebuildGroups() {
        var counts: [String: Int] = [:]
        for item in items { if let g = item.group { counts[g, default: 0] += 1 } }
        groups = counts.keys.sorted().map { key in
            let hue = Double(abs(key.hashValue) % 360)
            return Group(
                id: key,
                name: Self.prettify(key),
                colorLCH: LCH(l: 0.66, c: 0.16, h: hue),
                items: counts[key] ?? 0,
                description: "\(counts[key] ?? 0) item\(counts[key] == 1 ? "" : "s") in this group."
            )
        }
    }

    private func rebuildMarketplaces() {
        marketplaces = settings.loadKnownMarketplaces().map { m in
            let isOfficial = m.id.localizedCaseInsensitiveContains("official") || m.url.contains("anthropics")
            let kind: MarketSourceKind = isOfficial ? .official : (m.kind == "github" || m.kind == "git" ? .github : .community)
            let trust: MarketTrust = isOfficial ? .verified : (kind == .github ? .pinned : .community)
            return MarketplaceSource(
                id: m.id, name: Self.prettify(m.id), url: m.url,
                kind: kind, items: 0, lastSync: "—", enabled: true, trust: trust
            )
        }
        feed = []   // no catalog endpoint configured yet → real empty state
    }

    private func rebuildHooks() {
        var result: [Hook] = []
        var seen: Set<String> = []

        func add(_ parsed: [ClaudeSettingsService.ParsedHook], wsID: String) {
            for (idx, h) in parsed.enumerated() {
                let eventID = Self.mapEvent(h.event)
                var base = "\(eventID)-\(Self.slug(h.command).prefix(20))"
                if base.hasSuffix("-") { base = String(base.dropLast()) }
                var id = base
                var n = 2
                while seen.contains(id) { id = "\(base)-\(n)"; n += 1 }
                seen.insert(id)

                let eventAgents = hookEvents.first { $0.id == eventID }?.agents ?? ["claude-code"]
                result.append(Hook(
                    id: id,
                    event: eventID,
                    type: HookType(rawValue: h.type) ?? .command,
                    matcher: h.matcher,
                    command: h.command,
                    timeout: Int(h.timeoutSeconds * 1000),
                    async: h.async,
                    agents: eventAgents,
                    scopes: [wsID: true],
                    enabled: [wsID: true],
                    status: .ok,
                    lastFired: "—",
                    firesPerHour: 0,
                    source: h.source,
                    trusted: true,
                    description: h.statusMessage ?? "Runs on \(hookEvents.first { $0.id == eventID }?.label ?? h.event).",
                    warning: nil
                ))
            }
        }

        add(settings.loadHooks(), wsID: "global")
        for project in projectsStore.orderedProjects {
            let projectSettings = project.rootPath
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")
            if FileManager.default.fileExists(atPath: projectSettings.path) {
                add(settings.loadHooks(from: projectSettings, source: "project"), wsID: project.id.uuidString)
            }
        }
        hooks = result
    }

    // MARK: - Static mapping helpers

    static func agentColor(_ id: String) -> LCH {
        switch id {
        case "claude-code": return LCH(l: 0.62, c: 0.18, h: 30)
        case "codex":       return LCH(l: 0.42, c: 0.005, h: 270)
        case "cursor":      return LCH(l: 0.50, c: 0.005, h: 270)
        case "gemini":      return LCH(l: 0.66, c: 0.16, h: 232)
        default:            return LCH(l: 0.60, c: 0.10, h: 270)
        }
    }
    static func agentInitials(_ id: String) -> String {
        switch id {
        case "claude-code": return "CC"
        case "codex":       return "OX"
        case "cursor":      return "CU"
        case "gemini":      return "GE"
        default:            return String(id.prefix(2)).uppercased()
        }
    }
    static func agentSupports(_ id: String) -> [ItemKind] {
        id == "claude-code" ? [.skill, .plugin, .mcp] : [.plugin, .mcp]
    }

    static func mapEvent(_ raw: String) -> String {
        switch raw {
        case "SessionStart": return "session_start"
        case "UserPromptSubmit": return "user_prompt"
        case "PreToolUse": return "pre_tool"
        case "PermissionRequest": return "permission_req"
        case "PostToolUse": return "post_tool"
        case "PostToolUseFailure": return "post_tool_fail"
        case "beforeShellExecution": return "before_shell"
        case "beforeMCPExecution": return "before_mcp"
        case "afterFileEdit": return "after_file_edit"
        case "Notification": return "notification"
        case "Stop": return "stop"
        case "SubagentStop": return "subagent_stop"
        case "PreCompact": return "pre_compact"
        case "SessionEnd": return "session_end"
        default: return raw.lowercased()
        }
    }

    static func slug(_ s: String) -> String {
        let lowered = s.lowercased()
        var out = ""
        var lastDash = false
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch); lastDash = false
            } else if !lastDash, !out.isEmpty {
                out.append("-"); lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out
    }

    static func prettify(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    static func abbreviate(_ path: String) -> String {
        let home = ClaudeHomeImporter.realHomeDirectory().path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func relativeModified(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return "—" }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    static func directorySize(_ url: URL) -> String {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return "—" }
        var total: Int64 = 0
        if isDir.boolValue {
            if let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let f as URL in e {
                    total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
            }
        } else {
            total = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return humanBytes(total)
    }

    static func humanBytes(_ bytes: Int64) -> String {
        if bytes <= 0 { return "—" }
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
        return unit == 0 ? "\(Int(value)) B" : String(format: "%.0f %@", value, units[unit])
    }
}
