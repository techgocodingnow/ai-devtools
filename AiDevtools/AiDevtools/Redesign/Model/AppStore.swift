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

/// Single source of truth for the redesigned UI — ports the `reducer` + `initialState` in main.jsx.
@MainActor
final class AppStore: ObservableObject {
    // navigation
    @Published var screen: Screen = .library
    @Published var openItemId: String?
    @Published var detailTab: DetailTab = .overview
    @Published var showOnboarding = false

    // workspace
    @Published var workspace: String = "mcp"
    @Published var wsMenuOpen = false

    // data
    @Published var items: [Item] = SeedData.items
    @Published var agents: [AgentInfo] = SeedData.agents
    @Published var groups: [Group] = SeedData.groups
    @Published var marketplaces: [MarketplaceSource] = SeedData.marketplaces
    @Published var feed: [FeedItem] = SeedData.feed
    @Published var hooks: [Hook] = SeedData.hooks
    @Published var hookEvents: [HookEvent] = SeedData.hookEvents
    let workspaces: [Workspace] = SeedData.workspaces

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
    @Published var selectedGroup: String = "design"

    // hooks
    @Published var hookEventFilter: String?
    @Published var hookAgentFilter: String?
    @Published var hookStatusFilter: HookStatusFilter = .all
    @Published var selectedHookId: String?
    @Published var showHookForm = false
    @Published var collapsedEvents: Set<String> = []

    // misc
    @Published var scanning = false

    // MARK: derived

    var currentWorkspace: Workspace { workspaces.first { $0.id == workspace } ?? workspaces[0] }
    func agent(_ id: String) -> AgentInfo? { agents.first { $0.id == id } }
    func group(_ id: String?) -> Group? { id.flatMap { gid in groups.first { $0.id == gid } } }
    var openItem: Item? { openItemId.flatMap { id in items.first { $0.id == id } } }

    // MARK: navigation

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

    // MARK: workspace

    func switchWorkspace(_ id: String) {
        workspace = id
        wsMenuOpen = false
    }

    // MARK: item mutations

    func toggleEnabled(_ id: String, _ value: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].enabled[workspace] = value
    }
    func setScopeEnabled(_ id: String, ws: String, _ value: Bool) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].enabled[ws] = value
    }
    func installScope(_ id: String, ws: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].scopes[ws] = true
        items[i].enabled[ws] = true
    }

    // MARK: marketplace

    func toggleMarketplace(_ id: String, _ value: Bool) {
        guard let i = marketplaces.firstIndex(where: { $0.id == id }) else { return }
        marketplaces[i].enabled = value
    }

    // MARK: hooks

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

    // MARK: rescan (simulated)

    func rescan() {
        scanning = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            scanning = false
        }
    }
}
