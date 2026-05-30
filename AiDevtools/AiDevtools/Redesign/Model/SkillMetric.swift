import Foundation

/// One skill's quality scorecard, derived entirely from real Claude Code session
/// transcripts (`~/.claude/projects/**/*.jsonl`). See `SkillTelemetryService`.
///
/// Honesty notes (the app shows no fabricated data):
/// - Token attribution is turn-level and includes cache tokens, so it is approximate.
/// - Reactions are heuristically classified from the user's next message.
/// - Only skills invoked via the `Skill` tool or a `/slash` command appear here.
/// - Cost is an estimate using a fixed input/output blend.
struct SkillMetric: Identifiable, Hashable {
    enum Verdict: String, Hashable {
        case keep, review, drop
        var label: String {
            switch self {
            case .keep: return "Keep"
            case .review: return "Review"
            case .drop: return "Drop"
            }
        }
        /// Reuse the shared status palette for coloring (ok = green, warn = amber, err = red).
        var status: ItemStatus {
            switch self {
            case .keep: return .ok
            case .review: return .warn
            case .drop: return .err
            }
        }
    }

    let id: String              // = skill name (e.g. "commit", "graphify")
    var name: String { id }

    var runs: Int               // total runs across all sessions
    var avgTokens: Int          // mean tokens/run (approx, turn-level)
    var estCostPerRun: Double   // USD estimate
    var estTotalCost: Double    // estCostPerRun * runs (over the observed corpus)
    var lastUsed: Date?

    var reactionCount: Int      // non-neutral reactions observed
    var satisfactionPct: Double?    // satisfied / reactionCount (nil = no signal)
    var correctionPct: Double
    var cancelPct: Double
    var followUpPct: Double
    var retryPct: Double

    /// Trend = last-14-days window vs the prior 14-day window.
    var satisfactionTrend: Double?  // percentage-point delta (nil = insufficient data)
    var tokenTrendPct: Double?      // percent change in avg tokens (nil = insufficient data)

    var alerts: [String]
    var verdict: Verdict

    /// Composite quality score (0–100) used only for default sort ordering.
    /// Higher = healthier. Penalizes corrections/cancels and negative trends.
    var score: Double {
        var s = satisfactionPct ?? 60   // neutral baseline when no reaction signal
        s -= correctionPct * 0.5
        s -= cancelPct * 0.6
        if let t = satisfactionTrend { s += max(-20, min(20, t)) * 0.5 }
        return max(0, min(100, s))
    }
}
