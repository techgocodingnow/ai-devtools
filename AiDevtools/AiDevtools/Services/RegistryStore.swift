import Foundation
import Combine

/// In-memory registry of all known capabilities + global enable map.
///
/// Owns lookup tables so views can resolve a `CapabilityRef` to a concrete entity.
@MainActor
public final class RegistryStore: ObservableObject {
    @Published public var skills: [UUID: Skill] = [:]
    @Published public var plugins: [UUID: Plugin] = [:]
    @Published public var connectors: [UUID: Connector] = [:]
    @Published public var mcpServers: [UUID: MCPServer] = [:]
    @Published public var agents: [UUID: Agent] = [:]
    @Published public var globalEnabled: [CapabilityRef: Bool] = [:]

    public init() {}

    // MARK: - Global toggle

    public func isGloballyEnabled(_ ref: CapabilityRef) -> Bool {
        globalEnabled[ref] ?? true
    }

    public func setGlobal(_ ref: CapabilityRef, enabled: Bool) {
        globalEnabled[ref] = enabled
    }

    // MARK: - Insert

    public func upsert(_ skill: Skill) { skills[skill.id] = skill }
    public func upsert(_ plugin: Plugin) { plugins[plugin.id] = plugin }
    public func upsert(_ connector: Connector) { connectors[connector.id] = connector }
    public func upsert(_ server: MCPServer) { mcpServers[server.id] = server }
    public func upsert(_ agent: Agent) { agents[agent.id] = agent }

    // MARK: - Lookup

    public func skill(for ref: CapabilityRef) -> Skill? {
        guard ref.kind == .skill else { return nil }
        return skills[ref.id]
    }

    public func plugin(for ref: CapabilityRef) -> Plugin? {
        guard ref.kind == .plugin else { return nil }
        return plugins[ref.id]
    }

    public func connector(for ref: CapabilityRef) -> Connector? {
        guard ref.kind == .connector else { return nil }
        return connectors[ref.id]
    }

    public func mcpServer(for ref: CapabilityRef) -> MCPServer? {
        guard ref.kind == .mcpServer else { return nil }
        return mcpServers[ref.id]
    }

    /// Returns a human-friendly display name for any ref kind.
    public func displayName(for ref: CapabilityRef) -> String {
        switch ref.kind {
        case .skill: return skill(for: ref)?.name ?? "Unknown skill"
        case .plugin: return plugin(for: ref)?.name ?? "Unknown plugin"
        case .connector: return connector(for: ref)?.name ?? "Unknown connector"
        case .mcpServer: return mcpServer(for: ref)?.label ?? "Unknown MCP server"
        }
    }

    /// Aggregated list of every registered capability ref (skills + plugins + connectors + mcp).
    public var allRefs: [CapabilityRef] {
        skills.values.map(\.ref)
            + plugins.values.map(\.ref)
            + connectors.values.map(\.ref)
            + mcpServers.values.map(\.ref)
    }

    /// Origin of the capability if known. Connectors don't track origin yet.
    public func origin(for ref: CapabilityRef) -> CapabilityOrigin? {
        switch ref.kind {
        case .skill: return skill(for: ref)?.origin
        case .plugin: return plugin(for: ref)?.origin
        case .mcpServer: return mcpServer(for: ref)?.origin
        case .connector: return nil
        }
    }

    /// Logical domain (owner plugin, service type, namespace prefix) for grouping.
    public func domain(for ref: CapabilityRef) -> String {
        switch ref.kind {
        case .skill:
            guard let s = skill(for: ref) else { return "Unknown" }
            if let pid = s.pluginID, let p = plugins[pid] { return p.name }
            if let prefix = s.name.split(separator: ":").first, s.name.contains(":") {
                return String(prefix)
            }
            return "Standalone"
        case .plugin:
            return plugin(for: ref)?.name ?? "Unknown"
        case .connector:
            return connector(for: ref)?.serviceType ?? "Unknown"
        case .mcpServer:
            guard let m = mcpServer(for: ref) else { return "Unknown" }
            for plugin in plugins.values where plugin.mcpServerIDs.contains(m.id) {
                return plugin.name
            }
            return m.origin.displayLabel
        }
    }
}
