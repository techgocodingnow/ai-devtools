import Foundation

/// A Claude-style plugin: directory with `.claude-plugin/plugin.json`.
public nonisolated struct Plugin: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var summary: String
    public var version: String?
    public var tags: [String]
    public var rootDirectory: URL
    public var skillIDs: [UUID]
    public var mcpServerIDs: [UUID]
    public var origin: CapabilityOrigin

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        version: String? = nil,
        tags: [String] = [],
        rootDirectory: URL,
        skillIDs: [UUID] = [],
        mcpServerIDs: [UUID] = [],
        origin: CapabilityOrigin = .manual
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.version = version
        self.tags = tags
        self.rootDirectory = rootDirectory
        self.skillIDs = skillIDs
        self.mcpServerIDs = mcpServerIDs
        self.origin = origin
    }

    public var ref: CapabilityRef { CapabilityRef(kind: .plugin, id: id) }

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, version, tags, rootDirectory, skillIDs, mcpServerIDs, origin
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        version = try c.decodeIfPresent(String.self, forKey: .version)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        rootDirectory = try c.decode(URL.self, forKey: .rootDirectory)
        skillIDs = try c.decodeIfPresent([UUID].self, forKey: .skillIDs) ?? []
        mcpServerIDs = try c.decodeIfPresent([UUID].self, forKey: .mcpServerIDs) ?? []
        origin = try c.decodeIfPresent(CapabilityOrigin.self, forKey: .origin) ?? .manual
    }
}

/// On-disk plugin manifest as decoded from `.claude-plugin/plugin.json`.
public nonisolated struct PluginManifest: Codable, Sendable {
    public var name: String
    public var description: String?
    public var version: String?
    public var tags: [String]?
    public var skills: [SkillEntry]?
    public var mcpServers: [MCPServerEntry]?

    public struct SkillEntry: Codable, Sendable {
        public var name: String
        public var path: String
    }

    public struct MCPServerEntry: Codable, Sendable {
        public var label: String
        public var url: String
        public var description: String?
        public var authType: String?
    }
}
