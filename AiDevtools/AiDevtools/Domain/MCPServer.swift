import Foundation

/// MCP server endpoint config; secrets are referenced separately via Keychain.
///
/// Two transports:
///   - HTTP — `serverURL` set, `command` nil.
///   - Stdio — `command` + `args` set, `serverURL` nil.
public nonisolated struct MCPServer: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var serverURL: URL?
    public var command: String?
    public var args: [String]
    public var env: [String: String]
    public var description: String
    public var authType: String?
    public var isGlobal: Bool
    public var origin: MCPOrigin

    public init(
        id: UUID = UUID(),
        label: String,
        serverURL: URL? = nil,
        command: String? = nil,
        args: [String] = [],
        env: [String: String] = [:],
        description: String = "",
        authType: String? = nil,
        isGlobal: Bool = true,
        origin: MCPOrigin = .manual
    ) {
        self.id = id
        self.label = label
        self.serverURL = serverURL
        self.command = command
        self.args = args
        self.env = env
        self.description = description
        self.authType = authType
        self.isGlobal = isGlobal
        self.origin = origin
    }

    public var ref: CapabilityRef { CapabilityRef(kind: .mcpServer, id: id) }

    public var transportSummary: String {
        if let url = serverURL { return url.absoluteString }
        if let command { return ([command] + args).joined(separator: " ") }
        return "—"
    }

    public var isStdio: Bool { command != nil }

    private enum CodingKeys: String, CodingKey {
        case id, label, serverURL, command, args, env, description, authType, isGlobal, origin
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        serverURL = try c.decodeIfPresent(URL.self, forKey: .serverURL)
        command = try c.decodeIfPresent(String.self, forKey: .command)
        args = try c.decodeIfPresent([String].self, forKey: .args) ?? []
        env = try c.decodeIfPresent([String: String].self, forKey: .env) ?? [:]
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        authType = try c.decodeIfPresent(String.self, forKey: .authType)
        isGlobal = try c.decodeIfPresent(Bool.self, forKey: .isGlobal) ?? true
        origin = try c.decodeIfPresent(MCPOrigin.self, forKey: .origin) ?? .manual
    }
}
