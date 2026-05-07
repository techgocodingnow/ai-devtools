import Foundation

/// Read/write `~/Library/Application Support/Claude/claude_desktop_config.json`.
///
/// Schema:
/// ```json
/// {
///   "mcpServers": {
///     "github": { "url": "https://...", "headers": { "Authorization": "Bearer ..." } },
///     "filesystem": { "command": "npx", "args": ["-y", "@mcp/server-fs", "/path"], "env": { ... } }
///   }
/// }
/// ```
@MainActor
public final class ClaudeDesktopConfigService {
    public let configURL: URL
    private let fileManager: FileManager

    public init(configURL: URL? = nil, fileManager: FileManager = .default) {
        self.configURL = configURL ?? Self.defaultConfigURL()
        self.fileManager = fileManager
    }

    public static func defaultConfigURL() -> URL {
        let home: URL = {
            if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
                return URL(fileURLWithPath: String(cString: dir))
            }
            return FileManager.default.homeDirectoryForCurrentUser
        }()
        return home
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
    }

    public var fileExists: Bool {
        fileManager.fileExists(atPath: configURL.path)
    }

    // MARK: - Read

    /// Decode the file into `MCPServer` records. Returns empty array if file missing.
    public func loadServers() -> [MCPServer] {
        guard let data = try? Data(contentsOf: configURL) else { return [] }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        guard let serversBlob = object["mcpServers"] as? [String: Any] else { return [] }

        var results: [MCPServer] = []
        for (label, value) in serversBlob {
            guard let dict = value as? [String: Any] else { continue }
            results.append(decode(label: label, dict: dict))
        }
        return results.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func decode(label: String, dict: [String: Any]) -> MCPServer {
        let env = (dict["env"] as? [String: String]) ?? [:]
        let description = (dict["description"] as? String) ?? ""

        if let urlStr = dict["url"] as? String, let url = URL(string: urlStr) {
            let headers = dict["headers"] as? [String: String]
            let authType = headers?["Authorization"] != nil ? "bearer" : nil
            return MCPServer(
                label: label,
                serverURL: url,
                env: env,
                description: description,
                authType: authType,
                isGlobal: true,
                origin: .claudeDesktop
            )
        }

        let command = dict["command"] as? String
        let args = (dict["args"] as? [String]) ?? []
        return MCPServer(
            label: label,
            command: command,
            args: args,
            env: env,
            description: description,
            isGlobal: true,
            origin: .claudeDesktop
        )
    }

    // MARK: - Write

    /// Persist the supplied `claudeDesktop`-origin servers back to the config file.
    /// Other top-level keys (if any) are preserved.
    public func saveServers(_ servers: [MCPServer]) throws {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }

        var blob: [String: Any] = [:]
        for server in servers where server.origin == .claudeDesktop {
            blob[server.label] = encode(server)
        }
        root["mcpServers"] = blob

        try fileManager.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: configURL, options: [.atomic])
    }

    private func encode(_ server: MCPServer) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let url = server.serverURL {
            dict["url"] = url.absoluteString
        } else if let command = server.command {
            dict["command"] = command
            if !server.args.isEmpty { dict["args"] = server.args }
        }
        if !server.env.isEmpty { dict["env"] = server.env }
        if !server.description.isEmpty { dict["description"] = server.description }
        return dict
    }
}
