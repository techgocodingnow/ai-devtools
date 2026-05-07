import Foundation

/// External-service integration; may delegate to one or more MCP servers.
public nonisolated struct Connector: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var serviceType: String
    public var backingMCPServerID: UUID?
    public var isGlobal: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        serviceType: String,
        backingMCPServerID: UUID? = nil,
        isGlobal: Bool = true
    ) {
        self.id = id
        self.name = name
        self.serviceType = serviceType
        self.backingMCPServerID = backingMCPServerID
        self.isGlobal = isGlobal
    }

    public var ref: CapabilityRef { CapabilityRef(kind: .connector, id: id) }
}
