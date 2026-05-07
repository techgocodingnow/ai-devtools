import Combine
import Foundation
import SwiftUI

/// Top-level UI selection state — one of the sidebar sections + currently selected detail item.
public enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case projects
    case global
    case claudeCode
    case claudeDesktop
    case marketplace
    case mcpServers

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .projects: return "Projects"
        case .global: return "Global"
        case .claudeCode: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        case .marketplace: return "Marketplace"
        case .mcpServers: return "MCP / Connectors"
        }
    }

    public var systemImage: String {
        switch self {
        case .projects: return "folder"
        case .global: return "globe"
        case .claudeCode: return "terminal"
        case .claudeDesktop: return "macwindow"
        case .marketplace: return "bag"
        case .mcpServers: return "network"
        }
    }
}

/// Selection in the content column. Either a capability ref or a managed/discovered project.
public enum ContentSelection: Hashable {
    case capability(CapabilityRef)
    case project(UUID)
    case discoveredProject(URL)
    case marketplaceItem(String)
    case mcpServer(UUID)
}

/// Bag of stores + services injected into the SwiftUI environment.
@MainActor
public final class AppEnvironment: ObservableObject {
    public let registry: RegistryStore
    public let projects: ProjectsStore
    public let persistence: PersistenceService
    public let discovery: ProjectDiscoveryService
    public let marketplace: MarketplaceService
    public let installer: PluginInstaller
    public let keychain: KeychainService
    public let claudeDesktop: ClaudeDesktopConfigService

    @Published public var sidebar: SidebarSection = .projects {
        didSet {
            Task { @MainActor [weak self] in
                self?.contentSelection = nil
            }
        }
    }
    @Published public var contentSelection: ContentSelection?

    public init(
        registry: RegistryStore? = nil,
        projects: ProjectsStore? = nil,
        persistence: PersistenceService? = nil,
        discovery: ProjectDiscoveryService = ProjectDiscoveryService(),
        marketplace: MarketplaceService? = nil,
        installer: PluginInstaller = PluginInstaller(),
        keychain: KeychainService = KeychainService(),
        claudeDesktop: ClaudeDesktopConfigService? = nil
    ) {
        self.registry = registry ?? RegistryStore()
        self.projects = projects ?? ProjectsStore()
        self.persistence = persistence ?? PersistenceService()
        self.discovery = discovery
        self.marketplace = marketplace ?? MarketplaceService()
        self.installer = installer
        self.keychain = keychain
        self.claudeDesktop = claudeDesktop ?? ClaudeDesktopConfigService()
    }

    public func bootstrap() {
        try? persistence.loadRegistry(into: registry)
        try? persistence.loadProjects(into: projects)
        importClaudeHome()
        importClaudeDesktopMCP()
        ensureDefaultAgent()
        saveSoon()
    }

    /// Pull skills/plugins/MCP servers already installed in `~/.claude/` into the registry.
    public func importClaudeHome() {
        let importer = ClaudeHomeImporter(registry: registry)
        _ = importer.runImport()
    }

    /// Pull MCP servers defined in Claude Desktop's `claude_desktop_config.json`.
    /// Replaces any prior `.claudeDesktop`-origin entries to mirror the file.
    public func importClaudeDesktopMCP() {
        let fresh = claudeDesktop.loadServers()
        let priorByLabel = Dictionary(
            uniqueKeysWithValues: registry.mcpServers.values
                .filter { $0.origin == .claudeDesktop }
                .map { ($0.label, $0) }
        )
        // Drop existing claudeDesktop servers; re-add from disk so deletes/renames sync.
        for server in priorByLabel.values {
            registry.mcpServers.removeValue(forKey: server.id)
        }
        for var server in fresh {
            // Preserve existing UUID + global toggle if same label.
            if let prior = priorByLabel[server.label] {
                server.id = prior.id
            }
            registry.upsert(server)
            if registry.globalEnabled[server.ref] == nil {
                registry.setGlobal(server.ref, enabled: true)
            }
        }
    }

    /// Persist Claude-Desktop-origin MCP servers back to `claude_desktop_config.json`.
    public func saveClaudeDesktopMCP() throws {
        let servers = registry.mcpServers.values.filter { $0.origin == .claudeDesktop }
        try claudeDesktop.saveServers(Array(servers))
    }

    public func saveSoon() {
        persistence.scheduleSave(registry: registry, projects: projects)
    }

    public func discoverInBackground() {
        Task {
            let candidates = await discovery.discoverProjects()
            // Filter out any candidates already managed.
            let managedPaths = Set(projects.projects.values.map(\.rootPath.path))
            projects.discovered = candidates.filter { !managedPaths.contains($0.rootPath.path) }
        }
    }

    public func install(_ repoURL: URL, branch: String = "main") async throws {
        let result = try await installer.install(fromGitHubRepo: repoURL, branch: branch)
        registry.upsert(result.plugin)
        for skill in result.skills { registry.upsert(skill) }
        for mcp in result.mcpServers { registry.upsert(mcp) }
        registry.setGlobal(result.plugin.ref, enabled: true)
        for skill in result.skills { registry.setGlobal(skill.ref, enabled: true) }
        for mcp in result.mcpServers { registry.setGlobal(mcp.ref, enabled: true) }
        saveSoon()
    }

    /// Ensure at least one Claude Code agent exists.
    private func ensureDefaultAgent() {
        if registry.agents.isEmpty {
            let agent = Agent(name: "Claude Code", type: .code)
            registry.upsert(agent)
        }
    }

    public var defaultAgent: Agent {
        registry.agents.values.first ?? Agent(name: "Claude Code", type: .code)
    }
}
