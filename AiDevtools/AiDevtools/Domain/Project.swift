import Foundation

/// A managed project with per-capability override map.
public nonisolated struct Project: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var rootPath: URL
    public var lastScannedAt: Date?
    public var overrides: [CapabilityRef: CapabilityScopeOverride]
    public var detectedMarkers: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        rootPath: URL,
        lastScannedAt: Date? = nil,
        overrides: [CapabilityRef: CapabilityScopeOverride] = [:],
        detectedMarkers: [String] = []
    ) {
        self.id = id
        self.name = name
        self.rootPath = rootPath
        self.lastScannedAt = lastScannedAt
        self.overrides = overrides
        self.detectedMarkers = detectedMarkers
    }

    // CapabilityRef is not directly String-keyable for JSON; encode overrides as array.
    private enum CodingKeys: String, CodingKey {
        case id, name, rootPath, lastScannedAt, overrides, detectedMarkers
    }

    private struct OverrideEntry: Codable {
        var ref: CapabilityRef
        var value: CapabilityScopeOverride
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        rootPath = try c.decode(URL.self, forKey: .rootPath)
        lastScannedAt = try c.decodeIfPresent(Date.self, forKey: .lastScannedAt)
        detectedMarkers = try c.decodeIfPresent([String].self, forKey: .detectedMarkers) ?? []
        let entries = try c.decodeIfPresent([OverrideEntry].self, forKey: .overrides) ?? []
        overrides = Dictionary(uniqueKeysWithValues: entries.map { ($0.ref, $0.value) })
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(rootPath, forKey: .rootPath)
        try c.encodeIfPresent(lastScannedAt, forKey: .lastScannedAt)
        try c.encode(detectedMarkers, forKey: .detectedMarkers)
        let entries = overrides.map { OverrideEntry(ref: $0.key, value: $0.value) }
        try c.encode(entries, forKey: .overrides)
    }
}
