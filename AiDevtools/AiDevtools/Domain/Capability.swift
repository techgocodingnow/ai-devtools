import Foundation

/// What kind of agent capability we're referencing.
public nonisolated enum CapabilityKind: String, Codable, CaseIterable, Sendable, Hashable {
    case skill
    case plugin
    case connector
    case mcpServer
}

/// Stable typed reference to a capability across stores.
public nonisolated struct CapabilityRef: Codable, Hashable, Sendable {
    public let kind: CapabilityKind
    public let id: UUID

    public init(kind: CapabilityKind, id: UUID) {
        self.kind = kind
        self.id = id
    }
}

/// Per-project override of the global default for a capability.
public nonisolated enum CapabilityScopeOverride: String, Codable, Sendable, Hashable {
    case inherit
    case enabled
    case disabled
}

public nonisolated enum AgentType: String, Codable, Sendable, Hashable {
    case code
    case chat
}
