import Foundation

/// Builds skill-quality telemetry from the real session transcripts Claude Code already
/// writes to `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl`. Read-only — never
/// modifies any transcript. This is our own native implementation (no dependency on the
/// skill-evolver plugin); it parses the raw JSONL and derives the same kind of metrics.
///
/// Caveats (surfaced honestly in the UI):
/// - A skill "run" is detected from a `Skill` tool_use block or a `/slash` command invocation.
///   Skills triggered another way, or outside this transcript corpus, are not captured.
/// - Token attribution is turn-level (invocation through the next user message) and counts
///   input+output tokens — approximate, not a billing figure.
/// - The user's next message is classified into a reaction heuristically (regex).
nonisolated struct SkillTelemetryService: Sendable {

    enum Reaction: String, Sendable {
        case satisfied, correction, follow_up, retry, cancel, neutral
    }

    /// One observed skill invocation and its outcome.
    struct Run: Sendable {
        var skill: String
        var startedAt: Date
        var endedAt: Date
        var tokens: Int
        var toolCalls: Int
        var model: String?
        var reaction: Reaction
        var interrupted: Bool
        var durationMs: Double { max(0, endedAt.timeIntervalSince(startedAt) * 1000) }
    }

    private let projectsDir: URL

    /// Slash commands that are Claude Code built-ins, not user skills — excluded from the board.
    private static let builtinCommands: Set<String> = [
        "clear", "compact", "help", "config", "model", "login", "logout", "resume",
        "init", "cost", "doctor", "status", "exit", "quit", "vim", "terminal-setup",
        "bug", "release-notes", "pr-comments", "add-dir", "memory", "agents", "mcp",
        "fast", "ide", "permissions", "hooks", "export", "rewind", "context",
    ]

    /// Tags marking a user line as command scaffolding (not a genuine typed reaction).
    private static let scaffoldTags: [String] = [
        "<command-name>", "<command-message>", "<command-args>", "<command-contents>",
        "<local-command-stdout>", "<command-stdout>", "<bash-input>", "<bash-stdout>",
        "<user-prompt-submit-hook>",
    ]
    private static func isScaffold(_ text: String) -> Bool {
        scaffoldTags.contains { text.contains($0) }
    }

    init(projectsDir: URL? = nil) {
        self.projectsDir = projectsDir
            ?? ClaudeHomeImporter.realHomeDirectory()
                .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    // MARK: - Public entry point

    /// Parse every transcript and aggregate into per-skill scorecards (off the main actor).
    func metrics() async -> [SkillMetric] {
        let runs = await loadRuns()
        return Self.aggregate(runs, now: Date())
    }

    // MARK: - Parsing

    /// Flat list of every detected skill run across all sessions.
    func loadRuns() async -> [Run] {
        await Task.detached(priority: .utility) { [projectsDir] in
            let fm = FileManager.default
            guard let walker = fm.enumerator(
                at: projectsDir, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { return [] }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoPlain = ISO8601DateFormatter()

            var runs: [Run] = []
            for case let url as URL in walker where url.pathExtension == "jsonl" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let events = Self.parseEvents(text, iso: iso, isoPlain: isoPlain)
                runs.append(contentsOf: Self.runs(from: events))
            }
            return runs
        }.value
    }

    /// One parsed transcript line we care about.
    private struct Ev {
        var date: Date
        var role: String            // "assistant" | "user" | "other"
        var skill: String?          // skill/command name if this line invokes one
        var tokens: Int
        var toolCalls: Int
        var model: String?
        var stopReason: String?
        var userText: String?
        var toolResultOnly: Bool    // user line that is purely a tool_result echo
    }

    private static func parseEvents(_ text: String, iso: ISO8601DateFormatter, isoPlain: ISO8601DateFormatter) -> [Ev] {
        var evs: [Ev] = []
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            guard let tsStr = obj["timestamp"] as? String,
                  let date = iso.date(from: tsStr) ?? isoPlain.date(from: tsStr)
            else { continue }
            if obj["isMeta"] as? Bool == true { continue }   // sidechain / meta line, never a real turn

            let topType = obj["type"] as? String ?? ""
            let msg = obj["message"] as? [String: Any]
            let role = (msg?["role"] as? String) ?? topType

            var skill: String?
            var tokens = 0
            var toolCalls = 0
            var model = msg?["model"] as? String
            let stopReason = msg?["stop_reason"] as? String
            var userText: String?
            var toolResultOnly = false

            if let usage = msg?["usage"] as? [String: Any] {
                tokens = (usage["input_tokens"] as? Int ?? 0) + (usage["output_tokens"] as? Int ?? 0)
            }

            let content = msg?["content"]
            if let blocks = content as? [[String: Any]] {
                var sawText = false
                var sawToolResult = false
                var textParts: [String] = []
                for block in blocks {
                    let type = block["type"] as? String
                    switch type {
                    case "tool_use":
                        toolCalls += 1
                        if (block["name"] as? String) == "Skill",
                           let input = block["input"] as? [String: Any] {
                            let raw = (input["skill"] as? String) ?? (input["command"] as? String)
                            if let s = Self.normalize(raw) { skill = s }
                        }
                    case "text":
                        sawText = true
                        if let t = block["text"] as? String { textParts.append(t) }
                    case "tool_result":
                        sawToolResult = true
                    default:
                        break
                    }
                }
                if role == "user" {
                    userText = textParts.joined(separator: "\n")
                    toolResultOnly = sawToolResult && !sawText
                }
            } else if let str = content as? String {
                if role == "user" { userText = str }
            }

            // Slash-command invocation: `<command-name>foo</command-name>` in a user line.
            if role == "user", skill == nil, let t = userText,
               let cmd = Self.commandName(in: t), !Self.builtinCommands.contains(cmd) {
                skill = cmd
            }

            if model == nil { model = obj["model"] as? String }

            evs.append(Ev(date: date, role: role, skill: skill, tokens: tokens,
                          toolCalls: toolCalls, model: model, stopReason: stopReason,
                          userText: userText, toolResultOnly: toolResultOnly))
        }
        return evs.sorted { $0.date < $1.date }
    }

    /// Walk one session's ordered events, pairing each invocation with the user's reaction.
    private static func runs(from events: [Ev]) -> [Run] {
        var out: [Run] = []
        var pending: Run?

        func finalize(_ run: Run) -> Run {
            var r = run
            if r.reaction == .neutral && (r.interrupted || (r.tokens < 50 && r.durationMs < 3000)) {
                r.reaction = .cancel
            }
            return r
        }

        for ev in events {
            if let skill = ev.skill {
                if var prev = pending {
                    if prev.reaction == .neutral && prev.skill == skill { prev.reaction = .retry }
                    out.append(finalize(prev))
                }
                pending = Run(skill: skill, startedAt: ev.date, endedAt: ev.date,
                              tokens: ev.tokens, toolCalls: ev.toolCalls, model: ev.model,
                              reaction: .neutral, interrupted: ev.stopReason == "interrupted")
                continue
            }
            guard var p = pending else { continue }
            if ev.role == "assistant" {
                p.tokens += ev.tokens
                p.toolCalls += ev.toolCalls
                if p.model == nil { p.model = ev.model }
                if ev.date > p.endedAt { p.endedAt = ev.date }
                if ev.stopReason == "interrupted" { p.interrupted = true }
                pending = p
            } else if ev.role == "user", !ev.toolResultOnly,
                      let txt = ev.userText, !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Command scaffolding (the expanded /slash payload, hook stdout, etc.) is not a
                // typed reaction — keep waiting for the user's actual next message.
                if isScaffold(txt) { pending = p; continue }
                p.reaction = classify(txt)
                out.append(finalize(p))
                pending = nil
            }
        }
        if let p = pending { out.append(finalize(p)) }
        return out
    }

    // MARK: - Helpers

    private static func normalize(_ raw: String?) -> String? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("/") { s.removeFirst() }
        // Drop any arguments after the first whitespace.
        if let sp = s.firstIndex(where: { $0 == " " || $0 == "\n" }) { s = String(s[..<sp]) }
        return s.isEmpty ? nil : s
    }

    private static func commandName(in text: String) -> String? {
        guard let r = text.range(of: "<command-name>[^<]+</command-name>", options: .regularExpression)
        else { return nil }
        let inner = text[r]
            .replacingOccurrences(of: "<command-name>", with: "")
            .replacingOccurrences(of: "</command-name>", with: "")
        return normalize(inner)
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Heuristic reaction classifier (priority: correction → follow-up → satisfied → neutral).
    /// High-precision by design: anchored to the start of the message and capped by length, so a
    /// long new task prompt counts as `neutral` (no quality signal) rather than a false correction.
    private static func classify(_ raw: String) -> Reaction {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 220 { return .neutral }   // a long message is a new task, not a reaction
        if matches(text, #"^(no|nope|wrong|incorrect|not quite|not right|actually|instead|stop|revert|undo|that'?s not|don'?t|why did you|hmm|wait)\b"#)
            || matches(text, #"\b(revert that|undo that|that'?s wrong|not what i|should(n'?t| not) have)\b"#) {
            return .correction
        }
        if matches(text, #"^(also|additionally|and also|what about|how about|can you also|one more|another|next|and then|plus)\b"#) {
            return .follow_up
        }
        if matches(text, #"^(thanks|thank you|ty|ok|okay|k|good|great|perfect|nice|awesome|excellent|cool|got it|lgtm|ship it|love it|beautiful|yes|yep|yay|works|nice work)\b"#)
            || matches(text, #"(💯|🙏|👍|🎉)"#) {
            return .satisfied
        }
        return .neutral
    }

    // MARK: - Aggregation

    static func aggregate(_ runs: [Run], now: Date) -> [SkillMetric] {
        let d14 = now.addingTimeInterval(-14 * 86_400)
        let d28 = now.addingTimeInterval(-28 * 86_400)

        let grouped = Dictionary(grouping: runs, by: { $0.skill })
        var metrics: [SkillMetric] = []

        for (skill, list) in grouped {
            let count = list.count
            let avgTokens = count > 0 ? list.map(\.tokens).reduce(0, +) / count : 0
            let costPerRun = estCost(avgTokens)

            let nonNeutral = list.filter { $0.reaction != .neutral }
            let rc = nonNeutral.count
            func pct(_ r: Reaction, in set: [Run]) -> Double {
                guard !set.isEmpty else { return 0 }
                let n = set.filter { $0.reaction == r }.count
                return Double(n) / Double(set.count) * 100
            }
            let satisfaction: Double? = rc > 0 ? pct(.satisfied, in: nonNeutral) : nil

            // 14d vs prior-14d windows.
            let curr = list.filter { $0.startedAt >= d14 }
            let prev = list.filter { $0.startedAt >= d28 && $0.startedAt < d14 }
            let currReac = curr.filter { $0.reaction != .neutral }
            let prevReac = prev.filter { $0.reaction != .neutral }

            var satTrend: Double?
            if !currReac.isEmpty && !prevReac.isEmpty {
                satTrend = pct(.satisfied, in: currReac) - pct(.satisfied, in: prevReac)
            }
            var tokenTrend: Double?
            if !prev.isEmpty, !curr.isEmpty {
                let prevAvg = Double(prev.map(\.tokens).reduce(0, +)) / Double(prev.count)
                let currAvg = Double(curr.map(\.tokens).reduce(0, +)) / Double(curr.count)
                if prevAvg > 0 { tokenTrend = (currAvg - prevAvg) / prevAvg * 100 }
            }

            let correctionPct = pct(.correction, in: nonNeutral)
            let cancelPct = pct(.cancel, in: nonNeutral)

            // Alerts mirror skill-evolver's thresholds.
            var alerts: [String] = []
            if let st = satTrend, st < -15 { alerts.append("Satisfaction dropped \(Int(abs(st).rounded())) pts") }
            if correctionPct > 25 { alerts.append("High correction rate \(Int(correctionPct.rounded()))%") }
            if cancelPct > 10 { alerts.append("High cancel rate \(Int(cancelPct.rounded()))%") }
            if let tt = tokenTrend, tt > 30 { alerts.append("Token creep +\(Int(tt.rounded()))%") }

            let verdict: SkillMetric.Verdict
            if correctionPct > 40 || cancelPct > 30 || (satisfaction.map { $0 < 30 } ?? false && rc >= 3) {
                verdict = .drop
            } else if !alerts.isEmpty || (satisfaction.map { $0 < 60 } ?? false && rc >= 2) {
                verdict = .review
            } else {
                verdict = .keep
            }

            metrics.append(SkillMetric(
                id: skill,
                runs: count,
                avgTokens: avgTokens,
                estCostPerRun: costPerRun,
                estTotalCost: costPerRun * Double(count),
                lastUsed: list.map(\.startedAt).max(),
                reactionCount: rc,
                satisfactionPct: satisfaction,
                correctionPct: correctionPct,
                cancelPct: cancelPct,
                followUpPct: pct(.follow_up, in: nonNeutral),
                retryPct: pct(.retry, in: nonNeutral),
                satisfactionTrend: satTrend,
                tokenTrendPct: tokenTrend,
                alerts: alerts,
                verdict: verdict
            ))
        }

        return metrics.sorted { $0.runs > $1.runs }
    }

    /// USD estimate: assume a 70/30 input/output token blend at $3 / $15 per 1M tokens.
    private static func estCost(_ tokens: Int) -> Double {
        let t = Double(tokens)
        return (t * 0.7 * 3 + t * 0.3 * 15) / 1_000_000
    }
}
