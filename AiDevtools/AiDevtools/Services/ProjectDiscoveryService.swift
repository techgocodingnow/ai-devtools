import Foundation

/// Scans configured filesystem roots for Claude-style project markers.
///
/// Detection markers (per DESIGN.md §7):
///   - `skills/<name>/SKILL.md` and `.claude/skills/<name>/SKILL.md`
///   - `.claude-plugin/plugin.json`
///   - `.mcp.json`
///   - `agents/` directory
///
/// "Directory bubbling" walks marker paths up to the nearest `.git` repo or scan root.
public nonisolated struct ProjectDiscoveryService: Sendable {
    public let scanRoots: [URL]
    public let maxDepth: Int
    nonisolated(unsafe) private let fileManager: FileManager

    public static let defaultIgnoredDirNames: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", "Pods",
        ".venv", "venv", "__pycache__", ".idea", ".vscode", "dist", "build"
    ]

    public init(
        scanRoots: [URL] = ProjectDiscoveryService.defaultRoots(),
        maxDepth: Int = 5,
        fileManager: FileManager = .default
    ) {
        self.scanRoots = scanRoots
        self.maxDepth = maxDepth
        self.fileManager = fileManager
    }

    public static func defaultRoots() -> [URL] {
        let home: URL = {
            if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
                return URL(fileURLWithPath: String(cString: dir))
            }
            return FileManager.default.homeDirectoryForCurrentUser
        }()
        return [
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer")
        ]
    }

    /// Run discovery off the main actor; returns `Project` candidates.
    public func discoverProjects() async -> [Project] {
        await Task.detached(priority: .utility) { [self] in
            var roots: [URL: Set<String>] = [:]
            for root in scanRoots {
                guard fileManager.fileExists(atPath: root.path) else { continue }
                walk(root, root: root, depth: 0, accumulator: &roots)
            }
            return roots.map { (path, markers) in
                Project(
                    name: path.lastPathComponent,
                    rootPath: path,
                    lastScannedAt: Date(),
                    detectedMarkers: Array(markers).sorted()
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }

    /// Inspect a specific folder picked manually; returns a single candidate if markers exist.
    public func inspect(folder: URL) async -> Project? {
        await Task.detached(priority: .utility) { [self] in
            var roots: [URL: Set<String>] = [:]
            walk(folder, root: folder, depth: 0, accumulator: &roots)
            // If no marker found, return a project anyway with empty markers.
            if roots.isEmpty {
                return Project(name: folder.lastPathComponent, rootPath: folder, lastScannedAt: Date())
            }
            // Merge into a single candidate at the supplied folder.
            let allMarkers = roots.values.flatMap { $0 }
            return Project(
                name: folder.lastPathComponent,
                rootPath: folder,
                lastScannedAt: Date(),
                detectedMarkers: Array(Set(allMarkers)).sorted()
            )
        }.value
    }

    // MARK: - Internals

    private func walk(
        _ url: URL,
        root: URL,
        depth: Int,
        accumulator: inout [URL: Set<String>]
    ) {
        guard depth <= maxDepth else { return }
        guard let entries = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // Detect markers at this directory.
        var detected: Set<String> = []
        let pluginManifest = url.appendingPathComponent(".claude-plugin/plugin.json")
        if fileManager.fileExists(atPath: pluginManifest.path) {
            detected.insert(".claude-plugin/plugin.json")
        }
        let mcpJson = url.appendingPathComponent(".mcp.json")
        if fileManager.fileExists(atPath: mcpJson.path) {
            detected.insert(".mcp.json")
        }
        if hasSkillFiles(under: url.appendingPathComponent("skills")) {
            detected.insert("skills/*/SKILL.md")
        }
        if hasSkillFiles(under: url.appendingPathComponent(".claude/skills")) {
            detected.insert(".claude/skills/*/SKILL.md")
        }
        var agentsURL = url.appendingPathComponent("agents")
        if isDirectory(agentsURL) {
            detected.insert("agents/")
        } else {
            agentsURL = url.appendingPathComponent(".claude/agents")
            if isDirectory(agentsURL) { detected.insert(".claude/agents/") }
        }

        if !detected.isEmpty {
            let projectRoot = bubbleUp(from: url, untilOrAt: root)
            accumulator[projectRoot, default: []].formUnion(detected)
        }

        // Recurse into non-ignored subdirectories.
        for entry in entries {
            let name = entry.lastPathComponent
            if Self.defaultIgnoredDirNames.contains(name) { continue }
            if isDirectory(entry) {
                walk(entry, root: root, depth: depth + 1, accumulator: &accumulator)
            }
        }
    }

    private func bubbleUp(from start: URL, untilOrAt root: URL) -> URL {
        var cursor = start
        while cursor.path != root.path {
            let gitDir = cursor.appendingPathComponent(".git")
            if isDirectory(gitDir) || fileManager.fileExists(atPath: gitDir.path) {
                return cursor
            }
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path { break }
            cursor = parent
        }
        return start
    }

    private func hasSkillFiles(under dir: URL) -> Bool {
        guard isDirectory(dir),
              let entries = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
        else { return false }
        for entry in entries where isDirectory(entry) {
            let candidate = entry.appendingPathComponent("SKILL.md")
            if fileManager.fileExists(atPath: candidate.path) { return true }
        }
        return false
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}
