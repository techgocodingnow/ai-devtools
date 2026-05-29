import Foundation

/// Reads real hook-execution telemetry that Claude Code already writes to
/// `~/.claude/telemetry/*.json` (`tengu_run_hook` events). Read-only — this never
/// modifies how the user's hooks run; it only surfaces fires that already happened.
///
/// Caveat: telemetry retains a sparse sample (chiefly failed-upload events), and a
/// record identifies a hook only by `event:matcher` + command count — not the exact
/// command — so fires are attributed at the event+matcher level, not per command.
public nonisolated struct HookTelemetryService: Sendable {

    public struct Fire: Sendable {
        public var event: String      // raw event name, e.g. "SessionEnd"
        public var matcher: String?   // matcher segment, e.g. "Bash" / "other" / nil
        public var date: Date
    }

    /// Aggregated stats for one event(+matcher) group.
    public struct Stat: Sendable {
        public var count: Int
        public var last: Date
    }

    private let telemetryDir: URL

    public init(telemetryDir: URL? = nil) {
        self.telemetryDir = telemetryDir
            ?? ClaudeHomeImporter.realHomeDirectory()
                .appendingPathComponent(".claude/telemetry", isDirectory: true)
    }

    /// Parse all `tengu_run_hook` fires off the main actor.
    public func loadFires() async -> [Fire] {
        await Task.detached(priority: .utility) { [telemetryDir] in
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(
                at: telemetryDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { return [] }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoPlain = ISO8601DateFormatter()

            var fires: [Fire] = []
            for file in files where file.pathExtension == "json" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                for line in text.split(separator: "\n") {
                    guard let data = line.data(using: .utf8),
                          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let ed = obj["event_data"] as? [String: Any],
                          ed["event_name"] as? String == "tengu_run_hook" else { continue }

                    guard let ts = ed["client_timestamp"] as? String,
                          let date = iso.date(from: ts) ?? isoPlain.date(from: ts) else { continue }

                    var event = "unknown"
                    var matcher: String?
                    if let b64 = ed["additional_metadata"] as? String,
                       let metaData = Data(base64Encoded: b64),
                       let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                       let hookName = meta["hookName"] as? String {
                        let parts = hookName.split(separator: ":", maxSplits: 1).map(String.init)
                        event = parts.first ?? hookName
                        matcher = parts.count > 1 ? parts[1] : nil
                    }
                    fires.append(Fire(event: event, matcher: matcher, date: date))
                }
            }
            return fires.sorted { $0.date > $1.date }
        }.value
    }
}
