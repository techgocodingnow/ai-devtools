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

/// Real, on-demand detail for one item — read from disk when the detail screen opens.
struct ItemDetailData {
    var origin: String = "—"
    var locationPath: String?                       // abbreviated install path
    var files: [FileEntry] = []                     // directory listing
    var capabilities: [Capability] = []             // real metadata facts
    var configFileName: String?                     // e.g. "SKILL.md", "plugin.json"
    var configText: String?                         // real file body (capped)
    var sourcePath: String?                         // where it came from / lives

    struct FileEntry: Identifiable, Hashable { var id: String { name }; let name: String; let size: String }
    struct Capability: Identifiable, Hashable { var id: String { label }; let label: String; let detail: String }
}

/// Everything needed to locate a hook command in a settings.json and to re-add it.
/// Used both for active hooks (in-memory) and disabled ones (persisted sidecar).
struct HookRecord: Codable, Hashable {
    var id: String
    var wsID: String
    var settingsPath: String
    var rawEvent: String
    var matcher: String
    var type: String
    var command: String
    var timeoutSeconds: Double
    var async: Bool
    var statusMessage: String?
}

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
    @Published var hookActionError: String?
    @Published var sourceActionError: String?

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
    private let hookTelemetry = HookTelemetryService()
    private let settingsWriter = ClaudeSettingsWriter()

    /// Real hook fires read from `~/.claude/telemetry` (sparse, read-only).
    private var hookFires: [HookTelemetryService.Fire] = []
    /// Locator for each active hook (id → on-disk record), rebuilt with the hook list.
    private var hookRecords: [String: HookRecord] = [:]
    /// Hooks the user disabled — removed from settings.json, stashed here so they can be re-enabled.
    private var disabledHooks: [String: HookRecord] = [:]
    /// Marketplace ids the user turned off (app-persisted; extraKnownMarketplaces has no enabled flag).
    private var disabledSources: Set<String> = []
    /// Number of agent candidates the detector probes (for the scan card).
    @Published var agentCandidateCount: Int = 0

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
        loadDisabledHooks()
        loadDisabledSources()

        importer.runImport()
        for server in desktopConfig.loadServers() {
            if !registry.mcpServers.values.contains(where: { $0.label.lowercased() == server.label.lowercased() }) {
                registry.upsert(server)
                if registry.globalEnabled[server.ref] == nil { registry.setGlobal(server.ref, enabled: true) }
            }
        }

        let detected = await detector.detect()
        agentCandidateCount = detector.candidateCount
        let discoveredProjects = await discovery.discoverProjects()
        for project in discoveredProjects { projectsStore.promoteDiscovered(project) }
        hookFires = await hookTelemetry.loadFires()

        rebuildAll(detected: detected)
        loaded = true
        persist()
        await loadFeed()
    }

    /// Fetch the plugin catalog for each GitHub-backed marketplace and project it into the feed.
    /// Also backfills each source's item count. Network-best-effort; failures leave the feed empty.
    func loadFeed() async {
        let sources = marketplaces
            .filter { $0.enabled }
            .compactMap { MarketplaceCatalogService.source(id: $0.id, url: $0.url) }
        guard !sources.isEmpty else { feed = []; return }
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

    // MARK: - Marketplace sources

    /// Enable/disable a source for feed fetching. App-persisted (not in settings.json).
    func toggleMarketplace(_ id: String, _ value: Bool) {
        if value { disabledSources.remove(id) } else { disabledSources.insert(id) }
        saveDisabledSources()
        rebuildMarketplaces()
        Task { await loadFeed() }
    }

    /// Add a marketplace to `extraKnownMarketplaces`. `input` is a full git URL or `owner/repo`.
    func addSource(name: String, input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { sourceActionError = "Repository is empty."; return }
        let id = Self.slug(name.isEmpty ? trimmed : name)
        guard !id.isEmpty else { sourceActionError = "Couldn't derive a source id."; return }

        let kind: String, key: String
        if trimmed.contains("://") { kind = "git"; key = "url" }
        else if trimmed.split(separator: "/").count == 2 { kind = "github"; key = "repo" }
        else { sourceActionError = "Enter a git URL or owner/repo."; return }

        do {
            try settingsWriter.addMarketplace(at: settings.settingsURL, id: id, sourceKind: kind, locationKey: key, location: trimmed)
            rebuildMarketplaces()
            Task { await loadFeed() }
        } catch { sourceActionError = "Couldn't add source: \(error.localizedDescription)" }
    }

    /// Remove a marketplace key from `extraKnownMarketplaces`.
    func removeSource(_ id: String) {
        do {
            let removed = try settingsWriter.removeMarketplace(at: settings.settingsURL, id: id)
            guard removed else { sourceActionError = "Source not found."; return }
            disabledSources.remove(id)
            saveDisabledSources()
            rebuildMarketplaces()
            Task { await loadFeed() }
        } catch { sourceActionError = "Couldn't remove source: \(error.localizedDescription)" }
    }

    private var disabledSourcesURL: URL { persistence.paths.directory.appendingPathComponent("disabled_sources.json") }
    private func loadDisabledSources() {
        guard let data = try? Data(contentsOf: disabledSourcesURL),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return }
        disabledSources = Set(arr)
    }
    private func saveDisabledSources() {
        if let data = try? JSONEncoder().encode(Array(disabledSources)) {
            try? data.write(to: disabledSourcesURL, options: [.atomic])
        }
    }

    // MARK: - Hooks (real enable/disable: backup settings.json, stash entry in sidecar)

    func toggleEvent(_ id: String) {
        if collapsedEvents.contains(id) { collapsedEvents.remove(id) } else { collapsedEvents.insert(id) }
    }

    /// Enable = re-insert the stashed entry into settings.json. Disable = remove + stash.
    /// Every write is backed up under ~/.claude/backups/ first.
    func toggleHook(_ id: String, _ value: Bool) {
        if value {
            guard let rec = disabledHooks[id] else { return }
            let url = URL(fileURLWithPath: rec.settingsPath)
            let entry = ClaudeSettingsWriter.entry(
                type: rec.type, command: rec.command, timeoutSeconds: rec.timeoutSeconds,
                async: rec.async, statusMessage: rec.statusMessage
            )
            do {
                try settingsWriter.addHookEntry(at: url, event: rec.rawEvent, matcher: rec.matcher, entry: entry)
                disabledHooks.removeValue(forKey: id)
                saveDisabledHooks()
                rebuildHooks()
            } catch { hookActionError = "Couldn't enable hook: \(error.localizedDescription)" }
        } else {
            guard let rec = hookRecords[id] else { return }
            let url = URL(fileURLWithPath: rec.settingsPath)
            do {
                let removed = try settingsWriter.removeHookEntry(
                    at: url, event: rec.rawEvent, matcher: rec.matcher, command: rec.command
                )
                guard removed else { hookActionError = "Hook not found in settings.json"; return }
                disabledHooks[id] = rec
                saveDisabledHooks()
                rebuildHooks()
            } catch { hookActionError = "Couldn't disable hook: \(error.localizedDescription)" }
        }
    }

    /// Per-workspace hook scoping isn't wired yet (a hook lives in one settings file).
    /// Left as no-ops so the scope UI stays inert rather than lying. See docs/PENDING.md #4.
    func setHookScope(_ id: String, ws: String, _ value: Bool) {}
    func addHookScope(_ id: String, ws: String) {}

    /// Events that can actually be written to `~/.claude/settings.json` (real Claude events).
    var writableHookEvents: [HookEvent] { hookEvents.filter { Self.rawEventName($0.id) != nil } }

    /// Append a new hook to the global settings.json (backup-first). Global scope only.
    func addNewHook(eventID: String, matcher: String, type: HookType, command: String, timeoutMS: Int, async: Bool) {
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { hookActionError = "Command is empty."; return }
        guard let raw = Self.rawEventName(eventID) else {
            let label = hookEvents.first { $0.id == eventID }?.label ?? eventID
            hookActionError = "“\(label)” isn’t a Claude settings.json event."
            return
        }
        let entry = ClaudeSettingsWriter.entry(
            type: type.rawValue, command: cmd,
            timeoutSeconds: Double(timeoutMS) / 1000, async: async, statusMessage: nil
        )
        do {
            try settingsWriter.addHookEntry(
                at: settings.settingsURL, event: raw,
                matcher: matcher.isEmpty ? "*" : matcher, entry: entry
            )
            rebuildHooks()
        } catch { hookActionError = "Couldn't add hook: \(error.localizedDescription)" }
    }

    var selectedHook: Hook? { selectedHookId.flatMap { id in hooks.first { $0.id == id } } }

    private var disabledHooksURL: URL { persistence.paths.directory.appendingPathComponent("disabled_hooks.json") }
    private func loadDisabledHooks() {
        guard let data = try? Data(contentsOf: disabledHooksURL),
              let arr = try? JSONDecoder().decode([HookRecord].self, from: data) else { return }
        disabledHooks = Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0) })
    }
    private func saveDisabledHooks() {
        let arr = Array(disabledHooks.values)
        if let data = try? JSONEncoder().encode(arr) { try? data.write(to: disabledHooksURL, options: [.atomic]) }
    }

    // MARK: - Rescan (real)

    func rescan() {
        guard !scanning else { return }
        scanning = true
        Task { @MainActor in
            let detected = await detector.detect()
            agentCandidateCount = detector.candidateCount
            let discoveredProjects = await discovery.discoverProjects()
            for project in discoveredProjects { projectsStore.promoteDiscovered(project) }
            importer.runImport()
            hookFires = await hookTelemetry.loadFires()
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
                kind: kind, items: 0, lastSync: "—", enabled: !disabledSources.contains(m.id), trust: trust
            )
        }
        feed = []   // no catalog endpoint configured yet → real empty state
    }

    private func rebuildHooks() {
        var result: [Hook] = []
        var seen: Set<String> = []
        hookRecords = [:]

        func makeHook(eventID: String, matcher: String, command: String, type: HookType,
                      timeoutMS: Int, async: Bool, source: String, enabled: Bool,
                      wsID: String, statusMessage: String?, id: String) -> Hook {
            let eventAgents = hookEvents.first { $0.id == eventID }?.agents ?? ["claude-code"]
            let stat = fireStat(eventID: eventID, matcher: matcher)
            return Hook(
                id: id, event: eventID, type: type, matcher: matcher, command: command,
                timeout: timeoutMS, async: async, agents: eventAgents,
                scopes: [wsID: true], enabled: [wsID: enabled], status: .ok,
                lastFired: stat.last.map(Self.relativeDate) ?? "—",
                firesPerHour: stat.count,   // repurposed: observed fires (docs/PENDING.md #2)
                source: source, trusted: true,
                description: statusMessage ?? "Runs on \(hookEvents.first { $0.id == eventID }?.label ?? eventID).",
                warning: nil
            )
        }

        func uniqueID(_ base: String) -> String {
            var b = base
            if b.hasSuffix("-") { b = String(b.dropLast()) }
            var id = b; var n = 2
            while seen.contains(id) { id = "\(b)-\(n)"; n += 1 }
            seen.insert(id)
            return id
        }

        func add(_ parsed: [ClaudeSettingsService.ParsedHook], wsID: String, fileURL: URL) {
            for h in parsed {
                let eventID = Self.mapEvent(h.event)
                let id = uniqueID("\(eventID)-\(Self.slug(h.command).prefix(20))")
                hookRecords[id] = HookRecord(
                    id: id, wsID: wsID, settingsPath: fileURL.path, rawEvent: h.event,
                    matcher: h.matcher, type: h.type, command: h.command,
                    timeoutSeconds: h.timeoutSeconds, async: h.async, statusMessage: h.statusMessage
                )
                result.append(makeHook(
                    eventID: eventID, matcher: h.matcher, command: h.command,
                    type: HookType(rawValue: h.type) ?? .command, timeoutMS: Int(h.timeoutSeconds * 1000),
                    async: h.async, source: h.source, enabled: true, wsID: wsID,
                    statusMessage: h.statusMessage, id: id
                ))
            }
        }

        add(settings.loadHooks(), wsID: "global", fileURL: settings.settingsURL)
        for project in projectsStore.orderedProjects {
            let projectSettings = project.rootPath
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")
            if FileManager.default.fileExists(atPath: projectSettings.path) {
                add(settings.loadHooks(from: projectSettings, source: "project"),
                    wsID: project.id.uuidString, fileURL: projectSettings)
            }
        }

        // Merge disabled hooks (removed from settings.json, kept in the sidecar) as off rows.
        for rec in disabledHooks.values {
            seen.insert(rec.id)
            let eventID = Self.mapEvent(rec.rawEvent)
            result.append(makeHook(
                eventID: eventID, matcher: rec.matcher, command: rec.command,
                type: HookType(rawValue: rec.type) ?? .command, timeoutMS: Int(rec.timeoutSeconds * 1000),
                async: rec.async, source: "user", enabled: false, wsID: rec.wsID,
                statusMessage: rec.statusMessage, id: rec.id
            ))
        }

        hooks = result
    }

    // MARK: - Hook telemetry matching (real, read-only)

    /// Fires attributed to an event(+matcher) group. Matching is fuzzy by design —
    /// telemetry only records `event:matcher`, not the exact command.
    private func firesMatching(eventID: String, matcher: String) -> [HookTelemetryService.Fire] {
        hookFires.filter { fire in
            guard Self.mapEvent(fire.event) == eventID else { return false }
            guard let fm = fire.matcher, fm != "other", !fm.isEmpty else { return true }
            if matcher == "*" || matcher.isEmpty { return true }
            return matcher == fm || matcher.split(separator: "|").map(String.init).contains(fm)
        }
    }

    private func fireStat(eventID: String, matcher: String) -> (count: Int, last: Date?) {
        let matched = firesMatching(eventID: eventID, matcher: matcher)
        return (matched.count, matched.map(\.date).max())
    }

    /// Real recent invocations for the hook detail panel (most recent first, capped).
    func hookInvocations(_ id: String) -> [(when: String, label: String)] {
        guard let hook = hooks.first(where: { $0.id == id }) else { return [] }
        let label = hookEvents.first { $0.id == hook.event }?.label ?? hook.event
        return firesMatching(eventID: hook.event, matcher: hook.matcher)
            .prefix(8)
            .map { (Self.relativeDate($0.date), label) }
    }

    // MARK: - On-demand item detail (real, read from disk)

    func loadDetail(_ id: String) -> ItemDetailData {
        guard let ref = itemRefs[id] else { return ItemDetailData() }
        switch ref.kind {
        case .skill:     return skillDetail(ref)
        case .plugin:    return pluginDetail(ref)
        case .mcpServer: return mcpDetail(ref)
        case .connector: return ItemDetailData()
        }
    }

    private func skillDetail(_ ref: CapabilityRef) -> ItemDetailData {
        guard let s = registry.skills[ref.id] else { return ItemDetailData() }
        var d = ItemDetailData(origin: s.origin.displayLabel)
        d.locationPath = Self.abbreviate(s.location.path)
        d.sourcePath = Self.abbreviate(s.skillFile.path)
        d.files = Self.listDirectory(s.location)
        d.capabilities = Self.frontmatterFacts(s.skillFile)
        d.configFileName = "SKILL.md"
        d.configText = Self.readCapped(s.skillFile)
        return d
    }

    private func pluginDetail(_ ref: CapabilityRef) -> ItemDetailData {
        guard let p = registry.plugins[ref.id] else { return ItemDetailData() }
        var d = ItemDetailData(origin: p.origin.displayLabel)
        d.locationPath = Self.abbreviate(p.rootDirectory.path)
        d.sourcePath = Self.abbreviate(p.rootDirectory.path)
        d.files = Self.listDirectory(p.rootDirectory)
        var caps: [ItemDetailData.Capability] = [
            .init(label: "version", detail: p.version ?? "—"),
            .init(label: "skills", detail: "\(p.skillIDs.count)"),
            .init(label: "mcp servers", detail: "\(p.mcpServerIDs.count)"),
        ]
        if !p.tags.isEmpty { caps.append(.init(label: "tags", detail: p.tags.joined(separator: ", "))) }
        d.capabilities = caps
        let manifest = p.rootDirectory.appendingPathComponent(".claude-plugin/plugin.json")
        d.configFileName = "plugin.json"
        d.configText = Self.readCapped(manifest)
        return d
    }

    private func mcpDetail(_ ref: CapabilityRef) -> ItemDetailData {
        guard let m = registry.mcpServers[ref.id] else { return ItemDetailData() }
        var d = ItemDetailData(origin: m.origin.displayLabel)
        d.capabilities = [
            .init(label: "transport", detail: m.isStdio ? "stdio" : "http"),
            .init(label: "endpoint", detail: m.transportSummary),
            .init(label: "auth", detail: m.authType ?? "none"),
            .init(label: "env vars", detail: "\(m.env.count)"),
        ]
        switch m.origin {
        case .claudeDesktop: d.sourcePath = Self.abbreviate(desktopConfig.configURL.path)
        case .claudeHome:    d.sourcePath = "~/.claude/.mcp.json"
        case .plugin:        d.sourcePath = ownerPluginPath(forMCP: m.id)
        case .manual:        d.sourcePath = "Added in-app"
        }
        d.configFileName = ".mcp.json"
        d.configText = Self.mcpConfigJSON(m)
        return d
    }

    private func ownerPluginPath(forMCP id: UUID) -> String? {
        for plugin in registry.plugins.values where plugin.mcpServerIDs.contains(id) {
            return Self.abbreviate(plugin.rootDirectory.appendingPathComponent(".mcp.json").path)
        }
        return nil
    }

    static func mcpConfigJSON(_ m: MCPServer) -> String {
        var entry: [String: Any] = [:]
        if let url = m.serverURL { entry["url"] = url.absoluteString }
        if let cmd = m.command { entry["command"] = cmd; if !m.args.isEmpty { entry["args"] = m.args } }
        if !m.env.isEmpty { entry["env"] = m.env }
        if !m.description.isEmpty { entry["description"] = m.description }
        if let auth = m.authType { entry["authType"] = auth }
        let root: [String: Any] = ["mcpServers": [m.label: entry]]
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func listDirectory(_ url: URL, max: Int = 60) -> [ItemDetailData.FileEntry] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        let sorted = entries.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        return sorted.prefix(max).map { entry in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: entry.path, isDirectory: &isDir)
            let name = entry.lastPathComponent + (isDir.boolValue ? "/" : "")
            return ItemDetailData.FileEntry(name: name, size: isDir.boolValue ? "dir" : directorySize(entry))
        }
    }

    /// Read a text file, capped so the UI never tries to render a huge blob.
    static func readCapped(_ url: URL, maxBytes: Int = 16_384) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let slice = data.prefix(maxBytes)
        guard var text = String(data: slice, encoding: .utf8) else { return nil }
        if data.count > maxBytes { text += "\n… (truncated)" }
        return text
    }

    /// Top-level YAML-ish frontmatter keys → capability facts.
    static func frontmatterFacts(_ url: URL) -> [ItemDetailData.Capability] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [] }
        var facts: [ItemDetailData.Capability] = []
        for raw in lines.dropFirst() {
            let line = String(raw)
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            if let colon = line.firstIndex(of: ":"), !line.hasPrefix("  "), !line.hasPrefix("-") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if value.count > 140 { value = String(value.prefix(140)) + "…" }
                if !key.isEmpty { facts.append(.init(label: key, detail: value)) }
            }
        }
        return facts
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

    /// Inverse of `mapEvent`, restricted to events Claude actually reads from settings.json.
    /// Returns nil for cursor-only / non-writable events (so we never write a no-op hook).
    static func rawEventName(_ id: String) -> String? {
        switch id {
        case "session_start": return "SessionStart"
        case "user_prompt": return "UserPromptSubmit"
        case "pre_tool": return "PreToolUse"
        case "post_tool": return "PostToolUse"
        case "notification": return "Notification"
        case "stop": return "Stop"
        case "subagent_stop": return "SubagentStop"
        case "pre_compact": return "PreCompact"
        case "session_end": return "SessionEnd"
        default: return nil
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
        return relativeDate(date)
    }

    static func relativeDate(_ date: Date) -> String {
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
