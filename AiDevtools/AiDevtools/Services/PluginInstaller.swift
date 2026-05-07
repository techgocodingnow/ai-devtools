import Foundation

public protocol FileDownloading: Sendable {
    nonisolated func download(from url: URL) async throws -> URL
}

extension URLSession: FileDownloading {
    nonisolated public func download(from url: URL) async throws -> URL {
        let (tempURL, _) = try await self.download(from: url, delegate: nil)
        // Move to a stable location so caller controls lifetime.
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }
}

public protocol Unzipping: Sendable {
    nonisolated func unzip(_ archive: URL, into destination: URL) throws
}

/// Default unzipper: shells out to `/usr/bin/unzip` (always present on macOS).
public nonisolated struct ProcessUnzipper: Unzipping {
    public init() {}
    public func unzip(_ archive: URL, into destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", archive.path, "-d", destination.path]
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "unzip failed"
            throw PluginInstaller.InstallError.unzipFailed(msg)
        }
    }
}

public nonisolated struct InstallResult: Sendable {
    public let plugin: Plugin
    public let skills: [Skill]
    public let mcpServers: [MCPServer]
    public let installedRoot: URL
}

/// Downloads a GitHub repo as ZIP, unpacks it under Application Support, and constructs
/// `Plugin` + `Skill` + `MCPServer` entities by reading `.claude-plugin/plugin.json`.
public actor PluginInstaller {
    public enum InstallError: Error, LocalizedError {
        case invalidRepoURL
        case manifestNotFound
        case unzipFailed(String)
        case manifestDecode(String)

        public var errorDescription: String? {
            switch self {
            case .invalidRepoURL: return "Repository URL is not a valid GitHub URL."
            case .manifestNotFound: return "No `.claude-plugin/plugin.json` found in the downloaded archive."
            case .unzipFailed(let msg): return "Unzip failed: \(msg)"
            case .manifestDecode(let msg): return "Could not decode plugin manifest: \(msg)"
            }
        }
    }

    private let downloader: FileDownloading
    private let unzipper: Unzipping
    private let fileManager: FileManager
    public let packagesDirectory: URL

    public init(
        downloader: FileDownloading = URLSession.shared,
        unzipper: Unzipping = ProcessUnzipper(),
        fileManager: FileManager = .default,
        packagesDirectory: URL? = nil
    ) {
        self.downloader = downloader
        self.unzipper = unzipper
        self.fileManager = fileManager
        if let packagesDirectory {
            self.packagesDirectory = packagesDirectory
        } else {
            let base = (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fileManager.temporaryDirectory
            self.packagesDirectory = base
                .appendingPathComponent("AgentCapabilityManager", isDirectory: true)
                .appendingPathComponent("Packages", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.packagesDirectory, withIntermediateDirectories: true)
    }

    /// Compute the GitHub `archive/refs/heads/<branch>.zip` URL from a repo URL.
    public static func zipURL(forRepo repoURL: URL, branch: String = "main") -> URL? {
        // Accept https://github.com/owner/repo or .../repo.git
        guard repoURL.host?.contains("github.com") == true else { return nil }
        var components = repoURL.pathComponents.filter { $0 != "/" }
        guard components.count >= 2 else { return nil }
        if components[1].hasSuffix(".git") {
            components[1] = String(components[1].dropLast(4))
        }
        let owner = components[0]
        let repo = components[1]
        return URL(string: "https://github.com/\(owner)/\(repo)/archive/refs/heads/\(branch).zip")
    }

    public func install(fromGitHubRepo repoURL: URL, branch: String = "main") async throws -> InstallResult {
        guard let zip = Self.zipURL(forRepo: repoURL, branch: branch) else {
            throw InstallError.invalidRepoURL
        }

        let archive = try await downloader.download(from: zip)
        defer { try? fileManager.removeItem(at: archive) }

        let installRoot = packagesDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try unzipper.unzip(archive, into: installRoot)

        guard let manifestURL = Self.findManifest(under: installRoot, fileManager: fileManager) else {
            throw InstallError.manifestNotFound
        }

        let manifest: PluginManifest
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
        } catch {
            throw InstallError.manifestDecode(error.localizedDescription)
        }

        let pluginRoot = manifestURL
            .deletingLastPathComponent() // .claude-plugin
            .deletingLastPathComponent() // plugin root
        let plugin = Plugin(
            name: manifest.name,
            summary: manifest.description ?? "",
            version: manifest.version,
            tags: manifest.tags ?? [],
            rootDirectory: pluginRoot
        )

        var skills: [Skill] = []
        for entry in manifest.skills ?? [] {
            let dir = pluginRoot.appendingPathComponent(entry.path, isDirectory: true)
            let file = dir.appendingPathComponent("SKILL.md")
            skills.append(Skill(
                name: entry.name,
                location: dir,
                skillFile: file,
                pluginID: plugin.id
            ))
        }

        var mcps: [MCPServer] = []
        for entry in manifest.mcpServers ?? [] {
            guard let url = URL(string: entry.url) else { continue }
            mcps.append(MCPServer(
                label: entry.label,
                serverURL: url,
                description: entry.description ?? "",
                authType: entry.authType,
                isGlobal: true
            ))
        }

        let pluginWithChildren = Plugin(
            id: plugin.id,
            name: plugin.name,
            summary: plugin.summary,
            version: plugin.version,
            tags: plugin.tags,
            rootDirectory: plugin.rootDirectory,
            skillIDs: skills.map(\.id),
            mcpServerIDs: mcps.map(\.id)
        )

        return InstallResult(
            plugin: pluginWithChildren,
            skills: skills,
            mcpServers: mcps,
            installedRoot: installRoot
        )
    }

    /// Recursively search for `.claude-plugin/plugin.json` under `root`.
    public static func findManifest(under root: URL, fileManager: FileManager = .default) -> URL? {
        // Note: do NOT pass `.skipsHiddenFiles` — `.claude-plugin` starts with a dot.
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return nil }

        for case let url as URL in enumerator {
            if url.lastPathComponent == "plugin.json"
                && url.deletingLastPathComponent().lastPathComponent == ".claude-plugin" {
                return url
            }
        }
        return nil
    }
}
