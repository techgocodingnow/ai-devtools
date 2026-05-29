import Foundation

/// Detects which AI coding agents are installed on this machine.
///
/// Detection is file-system based (works under the App Sandbox via the real home
/// directory). A version probe is attempted but is best-effort — absence is fine.
public nonisolated struct AgentDetectionService: Sendable {

    /// Result of probing one known agent.
    public struct DetectedAgent: Sendable {
        public var id: String
        public var name: String
        public var vendor: String
        public var binaryPath: String      // resolved path, or the first candidate if not found
        public var detected: Bool
        public var version: String?
    }

    /// Static catalog of agents we know how to look for.
    private struct Candidate {
        let id: String
        let name: String
        let vendor: String
        let binaries: [String]   // candidate absolute paths (relative to home are prefixed)
        let configDirs: [String] // candidate config dirs under home
        let versionArgs: [String]?
    }

    nonisolated(unsafe) private let fileManager: FileManager
    private let home: URL

    public init(fileManager: FileManager = .default, home: URL? = nil) {
        self.fileManager = fileManager
        self.home = home ?? ClaudeHomeImporter.realHomeDirectory()
    }

    private var candidates: [Candidate] {
        [
            Candidate(id: "claude-code", name: "Claude Code", vendor: "Anthropic",
                      binaries: ["/usr/local/bin/claude", "/opt/homebrew/bin/claude", ".local/bin/claude", ".claude/local/claude"],
                      configDirs: [".claude"],
                      versionArgs: ["--version"]),
            Candidate(id: "codex", name: "Codex CLI", vendor: "OpenAI",
                      binaries: ["/usr/local/bin/codex", "/opt/homebrew/bin/codex", ".local/bin/codex"],
                      configDirs: [".codex"],
                      versionArgs: ["--version"]),
            Candidate(id: "cursor", name: "Cursor", vendor: "Anysphere",
                      binaries: ["/Applications/Cursor.app", "/usr/local/bin/cursor"],
                      configDirs: [".cursor"],
                      versionArgs: nil),
            Candidate(id: "gemini", name: "Gemini CLI", vendor: "Google",
                      binaries: ["/usr/local/bin/gemini", "/opt/homebrew/bin/gemini", ".local/bin/gemini"],
                      configDirs: [".gemini"],
                      versionArgs: ["--version"]),
        ]
    }

    /// Number of agent candidates probed — surfaced by the scan UI.
    public var candidateCount: Int { candidates.count }

    /// Runs detection off the main actor.
    public func detect() async -> [DetectedAgent] {
        await Task.detached(priority: .utility) { [self] in
            candidates.map { resolve($0) }
        }.value
    }

    private func resolve(_ c: Candidate) -> DetectedAgent {
        // Resolve the first existing binary or config dir.
        let resolvedBinary = c.binaries.first { exists(absolutizing: $0) }
        let hasConfig = c.configDirs.contains { exists(absolutizing: $0) }
        let detected = resolvedBinary != nil || hasConfig
        let path = resolvedBinary.map(absolutePath) ?? c.binaries.first ?? ""

        var version: String?
        if detected, let args = c.versionArgs, let bin = resolvedBinary, bin.hasPrefix("/") {
            version = probeVersion(binary: bin, args: args)
        }

        return DetectedAgent(
            id: c.id, name: c.name, vendor: c.vendor,
            binaryPath: path, detected: detected, version: version
        )
    }

    private func absolutePath(_ candidate: String) -> String {
        candidate.hasPrefix("/") ? candidate : home.appendingPathComponent(candidate).path
    }

    private func exists(absolutizing candidate: String) -> Bool {
        fileManager.fileExists(atPath: absolutePath(candidate))
    }

    /// Best-effort `--version`. Returns nil under sandbox or on any failure.
    private func probeVersion(binary: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let raw = String(data: data, encoding: .utf8) else { return nil }
            // Pull the first version-like token (e.g. "1.2.3" or "v0.18.4").
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = trimmed.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) {
                return String(trimmed[match])
            }
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }
}
