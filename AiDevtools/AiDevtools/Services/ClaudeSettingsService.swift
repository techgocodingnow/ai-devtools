import Foundation

/// Reads `~/.claude/settings.json` (and per-project `<root>/.claude/settings.json`).
///
/// Read-only by design: this service never rewrites the user's live settings file.
/// It surfaces the pieces the UI needs — hooks, known marketplaces, enabled plugins.
@MainActor
public struct ClaudeSettingsService {
    public let homeURL: URL
    private let fileManager: FileManager

    public init(homeURL: URL? = nil, fileManager: FileManager = .default) {
        self.homeURL = homeURL ?? ClaudeHomeImporter.realHomeDirectory().appendingPathComponent(".claude", isDirectory: true)
        self.fileManager = fileManager
    }

    public var settingsURL: URL { homeURL.appendingPathComponent("settings.json") }

    // MARK: - Parsed shapes

    /// One hook command parsed from a `hooks.<Event>[].hooks[]` entry.
    public struct ParsedHook: Sendable {
        public var event: String          // raw event name, e.g. "PreToolUse"
        public var matcher: String         // tool matcher regex or "*"
        public var type: String            // command | http | prompt | agent
        public var command: String
        public var timeoutSeconds: Double
        public var async: Bool
        public var source: String          // "user" or "plugin:<name>"
        public var statusMessage: String?
    }

    public struct KnownMarketplace: Sendable {
        public var id: String
        public var url: String
        public var kind: String            // git | github | local | other
    }

    // MARK: - Reads

    /// All hooks from the given settings file (defaults to the global one).
    public func loadHooks(from url: URL? = nil, source: String = "user") -> [ParsedHook] {
        let target = url ?? settingsURL
        guard let root = jsonObject(at: target),
              let hooksBlob = root["hooks"] as? [String: Any] else { return [] }

        var result: [ParsedHook] = []
        for (event, value) in hooksBlob {
            guard let matcherGroups = value as? [[String: Any]] else { continue }
            for group in matcherGroups {
                let matcher = (group["matcher"] as? String) ?? "*"
                guard let entries = group["hooks"] as? [[String: Any]] else { continue }
                for entry in entries {
                    let type = (entry["type"] as? String) ?? "command"
                    let command = (entry["command"] as? String)
                        ?? (entry["url"] as? String)
                        ?? (entry["prompt"] as? String) ?? ""
                    let timeout = (entry["timeout"] as? Double)
                        ?? (entry["timeout"] as? NSNumber).map { $0.doubleValue }
                        ?? 0
                    let async = (entry["async"] as? Bool) ?? false
                    result.append(ParsedHook(
                        event: event,
                        matcher: matcher,
                        type: type,
                        command: command,
                        timeoutSeconds: timeout,
                        async: async,
                        source: source,
                        statusMessage: entry["statusMessage"] as? String
                    ))
                }
            }
        }
        return result
    }

    /// `extraKnownMarketplaces` from the global settings file.
    public func loadKnownMarketplaces() -> [KnownMarketplace] {
        guard let root = jsonObject(at: settingsURL),
              let blob = root["extraKnownMarketplaces"] as? [String: Any] else { return [] }

        var result: [KnownMarketplace] = []
        for (id, value) in blob {
            guard let entry = value as? [String: Any],
                  let source = entry["source"] as? [String: Any] else { continue }
            let kind = (source["source"] as? String) ?? "other"
            let url: String
            if let u = source["url"] as? String {
                url = u
            } else if let repo = source["repo"] as? String {
                url = "https://github.com/\(repo)"
            } else {
                url = ""
            }
            result.append(KnownMarketplace(id: id, url: url, kind: kind))
        }
        return result.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    /// `enabledPlugins` map (`"name@marketplace": true`). Keys are the plugin's qualified name.
    public func loadEnabledPlugins() -> [String: Bool] {
        guard let root = jsonObject(at: settingsURL),
              let blob = root["enabledPlugins"] as? [String: Bool] else { return [:] }
        return blob
    }

    // MARK: - Helpers

    private func jsonObject(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
