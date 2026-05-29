import Foundation

/// Mutates a Claude `settings.json` hooks block — backup-first, atomic, preserving all
/// other top-level keys. Used only for explicit user toggles; every write is preceded by a
/// timestamped backup under `~/.claude/backups/`, so any change is recoverable.
@MainActor
public struct ClaudeSettingsWriter {
    public let backupDir: URL
    private let fileManager: FileManager

    public init(backupDir: URL? = nil, fileManager: FileManager = .default) {
        self.backupDir = backupDir
            ?? ClaudeHomeImporter.realHomeDirectory().appendingPathComponent(".claude/backups", isDirectory: true)
        self.fileManager = fileManager
    }

    public enum WriteError: Error { case unreadable, malformed }

    /// Remove one command entry from `hooks[event]` (matched by matcher group + command).
    /// Returns true if an entry was removed. Backs up before writing.
    @discardableResult
    public func removeHookEntry(at settingsURL: URL, event: String, matcher: String, command: String) throws -> Bool {
        var root = try loadRoot(settingsURL)
        guard var hooks = root["hooks"] as? [String: Any],
              var groups = hooks[event] as? [[String: Any]] else { return false }

        var removed = false
        for gi in groups.indices {
            let groupMatcher = (groups[gi]["matcher"] as? String) ?? "*"
            guard groupMatcher == matcher, var entries = groups[gi]["hooks"] as? [[String: Any]] else { continue }
            if let idx = entries.firstIndex(where: { entryCommand($0) == command }) {
                entries.remove(at: idx)
                removed = true
            }
            if entries.isEmpty { groups.remove(at: gi) } else { groups[gi]["hooks"] = entries }
            break
        }
        guard removed else { return false }

        if groups.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = groups }
        root["hooks"] = hooks
        try backup(settingsURL)
        try writeRoot(root, to: settingsURL)
        return true
    }

    /// Re-insert a command entry into `hooks[event]` under its matcher group (creating the
    /// group/event if needed). Backs up before writing.
    public func addHookEntry(at settingsURL: URL, event: String, matcher: String, entry: [String: Any]) throws {
        var root = (try? loadRoot(settingsURL)) ?? [:]
        var hooks = (root["hooks"] as? [String: Any]) ?? [:]
        var groups = (hooks[event] as? [[String: Any]]) ?? []

        if let gi = groups.firstIndex(where: { (($0["matcher"] as? String) ?? "*") == matcher }) {
            var entries = (groups[gi]["hooks"] as? [[String: Any]]) ?? []
            entries.append(entry)
            groups[gi]["hooks"] = entries
        } else {
            var group: [String: Any] = ["hooks": [entry]]
            if matcher != "*" { group["matcher"] = matcher }
            groups.append(group)
        }
        hooks[event] = groups
        root["hooks"] = hooks
        try backup(settingsURL)
        try writeRoot(root, to: settingsURL)
    }

    /// Build a settings.json command entry from stored fields.
    public static func entry(type: String, command: String, timeoutSeconds: Double, async: Bool, statusMessage: String?) -> [String: Any] {
        var e: [String: Any] = ["type": type]
        // command / url / prompt land on the same key set the reader understands.
        e["command"] = command
        if timeoutSeconds > 0 { e["timeout"] = Int(timeoutSeconds) }
        if async { e["async"] = true }
        if let statusMessage, !statusMessage.isEmpty { e["statusMessage"] = statusMessage }
        return e
    }

    // MARK: - Internals

    private func entryCommand(_ e: [String: Any]) -> String {
        (e["command"] as? String) ?? (e["url"] as? String) ?? (e["prompt"] as? String) ?? ""
    }

    private func loadRoot(_ url: URL) throws -> [String: Any] {
        guard let data = try? Data(contentsOf: url) else { throw WriteError.unreadable }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw WriteError.malformed }
        return obj
    }

    private func writeRoot(_ root: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: [.atomic])
    }

    /// Copy the current file to `backups/settings-<epoch>.json`. Best-effort directory create.
    private func backup(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = backupDir.appendingPathComponent("settings-\(stamp).json")
        if !fileManager.fileExists(atPath: dest.path) {
            try fileManager.copyItem(at: url, to: dest)
        }
    }
}
