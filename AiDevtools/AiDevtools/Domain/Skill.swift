import Foundation

/// A Claude-style skill: folder with SKILL.md + frontmatter.
public nonisolated struct Skill: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var summary: String
    public var tags: [String]
    public var location: URL
    public var skillFile: URL
    public var pluginID: UUID?
    public var origin: CapabilityOrigin

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        tags: [String] = [],
        location: URL,
        skillFile: URL,
        pluginID: UUID? = nil,
        origin: CapabilityOrigin = .manual
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.tags = tags
        self.location = location
        self.skillFile = skillFile
        self.pluginID = pluginID
        self.origin = origin
    }

    public var ref: CapabilityRef { CapabilityRef(kind: .skill, id: id) }

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, tags, location, skillFile, pluginID, origin
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        location = try c.decode(URL.self, forKey: .location)
        skillFile = try c.decode(URL.self, forKey: .skillFile)
        pluginID = try c.decodeIfPresent(UUID.self, forKey: .pluginID)
        origin = try c.decodeIfPresent(CapabilityOrigin.self, forKey: .origin) ?? .manual
    }
}
