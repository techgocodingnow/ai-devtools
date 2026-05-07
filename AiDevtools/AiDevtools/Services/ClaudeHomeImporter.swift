import Foundation

/// Imports skills/plugins/MCP servers already installed in `~/.claude/` into the registry.
///
/// Idempotent: existing entries (matched by on-disk path) are kept; new entries are added.
/// Reads only public metadata files. Does not read `settings.json` or `.credentials.json`.
@MainActor
public struct ClaudeHomeImporter {
    public let homeURL: URL
    public let registry: RegistryStore
    private let fileManager: FileManager

    public init(
        homeURL: URL? = nil,
        registry: RegistryStore,
        fileManager: FileManager = .default
    ) {
        self.homeURL = homeURL ?? Self.realHomeDirectory().appendingPathComponent(".claude", isDirectory: true)
        self.registry = registry
        self.fileManager = fileManager
    }

    /// Real user home directory — bypasses sandbox container redirection.
    /// `FileManager.homeDirectoryForCurrentUser` returns the container under sandbox;
    /// `getpwuid` returns the actual home (`/Users/<name>`).
    public static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public struct ImportSummary: Sendable {
        public var skillsAdded: Int = 0
        public var pluginsAdded: Int = 0
        public var mcpServersAdded: Int = 0
    }

    @discardableResult
    public func runImport() -> ImportSummary {
        var summary = ImportSummary()

        // Drop existing duplicates from prior runs (keep first occurrence per name/label).
        dedupeRegistry()

        var importedSkillNames = Set(registry.skills.values.map { $0.name.lowercased() })
        var importedMCPLabels = Set(registry.mcpServers.values.map { $0.label.lowercased() })

        importSkills(into: &summary, seen: &importedSkillNames)
        importPlugins(into: &summary, seenSkills: &importedSkillNames, seenMCP: &importedMCPLabels)
        importTopLevelMCP(into: &summary, seen: &importedMCPLabels)
        return summary
    }

    private func dedupeRegistry() {
        var seenSkill: Set<String> = []
        var keptSkills: [UUID: Skill] = [:]
        for skill in registry.skills.values.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let key = skill.name.lowercased()
            if seenSkill.contains(key) { continue }
            seenSkill.insert(key)
            keptSkills[skill.id] = skill
        }
        registry.skills = keptSkills

        var seenMCP: Set<String> = []
        var keptMCP: [UUID: MCPServer] = [:]
        for server in registry.mcpServers.values.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let key = server.label.lowercased()
            if seenMCP.contains(key) { continue }
            seenMCP.insert(key)
            keptMCP[server.id] = server
        }
        registry.mcpServers = keptMCP

        var seenPlugin: Set<String> = []
        var keptPlugins: [UUID: Plugin] = [:]
        for plugin in registry.plugins.values.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let key = plugin.rootDirectory.standardizedFileURL.path
            if seenPlugin.contains(key) { continue }
            seenPlugin.insert(key)
            keptPlugins[plugin.id] = plugin
        }
        registry.plugins = keptPlugins
    }

    // MARK: - Skills

    private func importSkills(into summary: inout ImportSummary, seen: inout Set<String>) {
        let skillsRoot = homeURL.appendingPathComponent("skills", isDirectory: true)
        guard fileManager.fileExists(atPath: skillsRoot.path) else { return }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: skillsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for dir in entries where isDirectory(dir) {
            let skillFile = dir.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFile.path) else { continue }

            let frontmatter = readFrontmatter(at: skillFile)
            let name = frontmatter["name"] ?? dir.lastPathComponent
            let key = name.lowercased()
            if seen.contains(key) { continue }

            let description = frontmatter["description"] ?? ""
            let skill = Skill(
                name: name,
                summary: description,
                tags: [],
                location: dir,
                skillFile: skillFile,
                pluginID: nil,
                origin: .claudeHome
            )
            registry.upsert(skill)
            if registry.globalEnabled[skill.ref] == nil {
                registry.setGlobal(skill.ref, enabled: true)
            }
            seen.insert(key)
            summary.skillsAdded += 1
        }
    }

    // MARK: - Plugins

    private func importPlugins(
        into summary: inout ImportSummary,
        seenSkills: inout Set<String>,
        seenMCP: inout Set<String>
    ) {
        let installedListURL = homeURL
            .appendingPathComponent("plugins")
            .appendingPathComponent("installed_plugins.json")
        guard let data = try? Data(contentsOf: installedListURL) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        guard let plugins = json["plugins"] as? [String: Any] else { return }

        let existingPluginPaths = Set(registry.plugins.values.map(\.rootDirectory.standardizedFileURL.path))

        for (qualifiedName, value) in plugins {
            guard let entries = value as? [[String: Any]] else { continue }
            for entry in entries {
                guard let installPath = entry["installPath"] as? String else { continue }
                let pluginRoot = URL(fileURLWithPath: installPath)
                if existingPluginPaths.contains(pluginRoot.standardizedFileURL.path) { continue }

                let manifestURL = pluginRoot
                    .appendingPathComponent(".claude-plugin")
                    .appendingPathComponent("plugin.json")
                let manifest: PluginManifest? = readManifest(at: manifestURL)

                let displayName = manifest?.name ?? qualifiedName.split(separator: "@").first.map(String.init) ?? qualifiedName
                let version = (entry["version"] as? String) ?? manifest?.version

                var skillIDs: [UUID] = []
                var mcpIDs: [UUID] = []

                let plugin = Plugin(
                    name: displayName,
                    summary: manifest?.description ?? "",
                    version: version,
                    tags: manifest?.tags ?? [],
                    rootDirectory: pluginRoot,
                    origin: .claudeHome
                )

                // Pull child skills from manifest entries OR from a `skills/` subdirectory.
                if let manifestSkills = manifest?.skills, !manifestSkills.isEmpty {
                    for s in manifestSkills {
                        let key = s.name.lowercased()
                        if seenSkills.contains(key) { continue }
                        let dir = pluginRoot.appendingPathComponent(s.path, isDirectory: true)
                        let file = dir.appendingPathComponent("SKILL.md")
                        let skill = Skill(
                            name: s.name,
                            location: dir,
                            skillFile: file,
                            pluginID: plugin.id,
                            origin: .plugin
                        )
                        registry.upsert(skill)
                        if registry.globalEnabled[skill.ref] == nil {
                            registry.setGlobal(skill.ref, enabled: true)
                        }
                        skillIDs.append(skill.id)
                        seenSkills.insert(key)
                        summary.skillsAdded += 1
                    }
                } else {
                    // Fallback: scan `<plugin>/skills/*/SKILL.md`.
                    let skillsDir = pluginRoot.appendingPathComponent("skills", isDirectory: true)
                    if let children = try? fileManager.contentsOfDirectory(
                        at: skillsDir,
                        includingPropertiesForKeys: [.isDirectoryKey]
                    ) {
                        for child in children where isDirectory(child) {
                            let file = child.appendingPathComponent("SKILL.md")
                            guard fileManager.fileExists(atPath: file.path) else { continue }
                            let frontmatter = readFrontmatter(at: file)
                            let name = frontmatter["name"] ?? child.lastPathComponent
                            let key = name.lowercased()
                            if seenSkills.contains(key) { continue }
                            let skill = Skill(
                                name: name,
                                summary: frontmatter["description"] ?? "",
                                location: child,
                                skillFile: file,
                                pluginID: plugin.id,
                                origin: .plugin
                            )
                            registry.upsert(skill)
                            if registry.globalEnabled[skill.ref] == nil {
                                registry.setGlobal(skill.ref, enabled: true)
                            }
                            skillIDs.append(skill.id)
                            seenSkills.insert(key)
                            summary.skillsAdded += 1
                        }
                    }
                }

                // Pull MCP servers from `.mcp.json` if present.
                let pluginMCPFile = pluginRoot.appendingPathComponent(".mcp.json")
                for mcp in readMCPServers(at: pluginMCPFile, origin: .plugin) {
                    let key = mcp.label.lowercased()
                    if seenMCP.contains(key) { continue }
                    registry.upsert(mcp)
                    if registry.globalEnabled[mcp.ref] == nil {
                        registry.setGlobal(mcp.ref, enabled: true)
                    }
                    mcpIDs.append(mcp.id)
                    seenMCP.insert(key)
                    summary.mcpServersAdded += 1
                }

                let final = Plugin(
                    id: plugin.id,
                    name: plugin.name,
                    summary: plugin.summary,
                    version: plugin.version,
                    tags: plugin.tags,
                    rootDirectory: plugin.rootDirectory,
                    skillIDs: skillIDs,
                    mcpServerIDs: mcpIDs,
                    origin: plugin.origin
                )
                registry.upsert(final)
                if registry.globalEnabled[final.ref] == nil {
                    registry.setGlobal(final.ref, enabled: true)
                }
                summary.pluginsAdded += 1
            }
        }
    }

    // MARK: - MCP servers

    private func importTopLevelMCP(into summary: inout ImportSummary, seen: inout Set<String>) {
        let mcpFile = homeURL.appendingPathComponent(".mcp.json")
        for mcp in readMCPServers(at: mcpFile) {
            let key = mcp.label.lowercased()
            if seen.contains(key) { continue }
            registry.upsert(mcp)
            if registry.globalEnabled[mcp.ref] == nil {
                registry.setGlobal(mcp.ref, enabled: true)
            }
            seen.insert(key)
            summary.mcpServersAdded += 1
        }
    }

    // MARK: - File helpers

    private func readManifest(at url: URL) -> PluginManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PluginManifest.self, from: data)
    }

    /// Decode entries from a `.mcp.json` of the shape `{ "mcpServers": { "label": { "url": "..." } } }`.
    /// Falls back to a flat list if the file is an array.
    private func readMCPServers(at url: URL, origin: MCPOrigin = .claudeHome) -> [MCPServer] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }

        var results: [MCPServer] = []
        let appendIfValid = { (label: String, dict: [String: Any]) in
            let description = (dict["description"] as? String) ?? ""
            let authType = dict["authType"] as? String
            let env = (dict["env"] as? [String: String]) ?? [:]

            if let urlStr = (dict["url"] as? String) ?? (dict["serverUrl"] as? String) ?? (dict["server_url"] as? String),
               let parsed = URL(string: urlStr) {
                results.append(MCPServer(
                    label: label,
                    serverURL: parsed,
                    env: env,
                    description: description,
                    authType: authType,
                    isGlobal: true,
                    origin: origin
                ))
            } else if let cmd = dict["command"] as? String {
                let args = (dict["args"] as? [String]) ?? []
                results.append(MCPServer(
                    label: label,
                    command: cmd,
                    args: args,
                    env: env,
                    description: description,
                    isGlobal: true,
                    origin: origin
                ))
            }
        }

        if let dict = object as? [String: Any], let servers = dict["mcpServers"] as? [String: Any] {
            for (label, value) in servers {
                if let entry = value as? [String: Any] {
                    appendIfValid(label, entry)
                }
            }
        }
        return results
    }

    /// Parse the top YAML-ish frontmatter block delimited by `---` lines into a flat key/value map.
    private func readFrontmatter(at url: URL) -> [String: String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }

        var result: [String: String] = [:]
        var lastKey: String?
        for raw in lines.dropFirst() {
            let line = String(raw)
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            if let colon = line.firstIndex(of: ":"), !line.hasPrefix("  ") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                result[key] = value
                lastKey = key
            } else if let key = lastKey {
                // Continuation line — append.
                result[key]? += " " + line.trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
