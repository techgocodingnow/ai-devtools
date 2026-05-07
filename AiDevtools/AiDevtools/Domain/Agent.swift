import Foundation

/// Logical AI assistant config (v1: Claude Code).
public nonisolated struct Agent: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var type: AgentType
    public var defaultCapabilities: [CapabilityRef]

    public init(
        id: UUID = UUID(),
        name: String,
        type: AgentType = .code,
        defaultCapabilities: [CapabilityRef] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.defaultCapabilities = defaultCapabilities
    }
}
