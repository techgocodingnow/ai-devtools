import Foundation

/// Performs a real, on-disk uninstall of a Claude plugin: removes its entry from
/// `~/.claude/plugins/installed_plugins.json`, drops it from `settings.json`'s
/// `enabledPlugins`, and deletes the plugin's install directory.
///
/// Backup-first and bounded: every JSON mutation is preceded by a timestamped backup
/// under `~/.claude/backups/`, and the directory delete is refused unless the path lives
/// inside `~/.claude/` (so a malformed manifest can never point us at an arbitrary path).
@MainActor
public struct PluginUninstaller {
    public let homeURL: URL
    public let backupDir: URL
    private let fileManager: FileManager

    public init(homeURL: URL? = nil, backupDir: URL? = nil, fileManager: FileManager = .default) {
        let home = homeURL ?? ClaudeHomeImporter.realHomeDirectory().appendingPathComponent(".claude", isDirectory: true)
        self.homeURL = home
        self.backupDir = backupDir ?? home.appendingPathComponent("backups", isDirectory: true)
        self.fileManager = fileManager
    }

    public enum UninstallError: Error, Equatable {
        /// The plugin's install directory resolved outside `~/.claude/` — refused for safety.
        case pathOutsideHome(String)
    }

    /// Result of an uninstall, for the toast / logging.
    public struct Result: Sendable {
        public var directoryDeleted: Bool
        public var listEntryRemoved: Bool
        public var enabledPluginRemoved: Bool
    }

    /// Uninstall a plugin by its install directory and qualified name (`name@marketplace`).
    ///
    /// - Parameters:
    ///   - rootDirectory: the plugin's on-disk root (`Plugin.rootDirectory`).
    ///   - qualifiedName: the `name@marketplace` key as it appears in settings.json, if known.
    @discardableResult
    public func uninstall(rootDirectory: URL, qualifiedName: String?) throws -> Result {
        let listEntryRemoved = try removeFromInstalledList(rootDirectory: rootDirectory)
        var enabledRemoved = false
        if let qualifiedName {
            enabledRemoved = (try? removeFromEnabledPlugins(qualified: qualifiedName)) ?? false
        }
        let deleted = try deleteDirectory(rootDirectory)
        return Result(directoryDeleted: deleted, listEntryRemoved: listEntryRemoved, enabledPluginRemoved: enabledRemoved)
    }

    // MARK: - installed_plugins.json

    private var installedListURL: URL {
        homeURL.appendingPathComponent("plugins").appendingPathComponent("installed_plugins.json")
    }

    /// Remove every entry whose `installPath` matches `rootDirectory` from each plugin list,
    /// dropping any qualified-name key whose list becomes empty. Returns true if anything changed.
    @discardableResult
    private func removeFromInstalledList(rootDirectory: URL) throws -> Bool {
        let url = installedListURL
        guard let data = try? Data(contentsOf: url),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var plugins = root["plugins"] as? [String: Any] else { return false }

        let target = rootDirectory.standardizedFileURL.path
        var changed = false

        for (qualified, value) in plugins {
            guard let entries = value as? [[String: Any]] else { continue }
            let kept = entries.filter { entry in
                guard let installPath = entry["installPath"] as? String else { return true }
                return URL(fileURLWithPath: installPath).standardizedFileURL.path != target
            }
            if kept.count != entries.count {
                changed = true
                if kept.isEmpty { plugins.removeValue(forKey: qualified) } else { plugins[qualified] = kept }
            }
        }

        guard changed else { return false }
        root["plugins"] = plugins
        try backup(url)
        try write(root, to: url)
        return true
    }

    // MARK: - settings.json enabledPlugins

    @discardableResult
    private func removeFromEnabledPlugins(qualified: String) throws -> Bool {
        let url = homeURL.appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: url),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var enabled = root["enabledPlugins"] as? [String: Any],
              enabled[qualified] != nil else { return false }
        enabled.removeValue(forKey: qualified)
        root["enabledPlugins"] = enabled
        try backup(url)
        try write(root, to: url)
        return true
    }

    // MARK: - Directory delete (bounded to ~/.claude/)

    @discardableResult
    private func deleteDirectory(_ url: URL) throws -> Bool {
        let resolved = url.standardizedFileURL.path
        let home = homeURL.standardizedFileURL.path
        let homePrefix = home.hasSuffix("/") ? home : home + "/"
        guard resolved.hasPrefix(homePrefix) else {
            throw UninstallError.pathOutsideHome(resolved)
        }
        guard fileManager.fileExists(atPath: resolved) else { return false }
        try fileManager.removeItem(at: url)
        return true
    }

    // MARK: - Internals

    private func write(_ root: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: [.atomic])
    }

    private func backup(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = backupDir.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(stamp).\(url.pathExtension)")
        if !fileManager.fileExists(atPath: dest.path) {
            try fileManager.copyItem(at: url, to: dest)
        }
    }
}
