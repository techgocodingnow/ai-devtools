import SwiftUI

/// Skill-quality dashboard. Shows which skills are worth keeping vs reviewing/dropping,
/// derived from real session transcripts via `SkillTelemetryService` (read-only). Spans
/// every project under `~/.claude/projects`, so it is global rather than workspace-scoped.
struct PerformanceScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    enum VerdictFilter: String, CaseIterable { case all, keep, review, drop }
    @State private var verdictFilter: VerdictFilter = .all
    @State private var selected: String?
    @State private var refreshing = false

    private var filtered: [SkillMetric] {
        store.skillMetrics.filter { m in
            switch verdictFilter {
            case .all: break
            case .keep where m.verdict != .keep: return false
            case .review where m.verdict != .review: return false
            case .drop where m.verdict != .drop: return false
            default: break
            }
            if !store.search.isEmpty, !m.name.lowercased().contains(store.search.lowercased()) { return false }
            return true
        }
        .sorted { a, b in
            if a.verdict != b.verdict { return rank(a.verdict) < rank(b.verdict) }
            return a.runs > b.runs
        }
    }
    private func rank(_ v: SkillMetric.Verdict) -> Int { v == .drop ? 0 : (v == .review ? 1 : 2) }

    private func count(_ v: SkillMetric.Verdict) -> Int { store.skillMetrics.filter { $0.verdict == v }.count }

    func color(_ s: ItemStatus) -> Color {
        let t = theme.tokens
        switch s { case .ok: return t.ok; case .warn: return t.warn; case .err: return t.err; case .off: return t.fg3 }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if store.skillMetrics.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            columnHeader
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, m in
                                PerfRow(metric: m, last: idx == filtered.count - 1,
                                        selected: selected == m.id, color: color(m.verdict.status)) {
                                    selected = (selected == m.id) ? nil : m.id
                                }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(theme.tokens.bgPanel))
                        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(theme.tokens.line, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
                        caveat.padding(.horizontal, 18).padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    if let m = store.skillMetrics.first(where: { $0.id == selected }) {
                        PerfDetailPanel(metric: m, color: color(m.verdict.status)) { selected = nil }
                            .frame(width: 340)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        let t = theme.tokens
        return ScreenToolbar {
            ScreenHeader("Performance") {
                HStack(spacing: 0) {
                    Text("\(store.skillMetrics.count) skills tracked across all sessions · ")
                    Text("\(count(.keep)) keep").foregroundColor(t.ok)
                    Text(" · ")
                    Text("\(count(.review)) review").foregroundColor(t.warn)
                    Text(" · ")
                    Text("\(count(.drop)) drop").foregroundColor(t.err)
                }
            }
            Spacer()
            SearchField(text: $store.search, placeholder: "Search skills…").frame(width: 200)
            verdictSeg
            Btn(.normal, sm: true, action: {
                refreshing = true
                Task { await store.rebuildSkillMetrics(); refreshing = false }
            }) {
                Sym(Icons.refresh, size: 12).rotationEffect(.degrees(refreshing ? 360 : 0))
                    .animation(refreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: refreshing)
                Text("Refresh")
            }
        }
    }

    private var verdictSeg: some View {
        Seg {
            SegButton("All", on: verdictFilter == .all) { verdictFilter = .all }
            SegButton("Keep", on: verdictFilter == .keep) { verdictFilter = .keep }
            SegButton("Review", on: verdictFilter == .review) { verdictFilter = .review }
            SegButton("Drop", on: verdictFilter == .drop) { verdictFilter = .drop }
        }
    }

    // MARK: - Column header

    private var columnHeader: some View {
        let t = theme.tokens
        return HStack(spacing: 10) {
            Text("VERDICT").frame(width: 64, alignment: .leading)
            Text("SKILL").frame(maxWidth: .infinity, alignment: .leading)
            Text("RUNS").frame(width: 48, alignment: .trailing)
            Text("SATISFACTION").frame(width: 96, alignment: .trailing)
            Text("CORRECTION").frame(width: 80, alignment: .trailing)
            Text("CANCEL").frame(width: 60, alignment: .trailing)
            Text("AVG TOKENS").frame(width: 80, alignment: .trailing)
            Text("EST COST").frame(width: 72, alignment: .trailing)
            Text("TREND").frame(width: 56, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .semibold)).tracking(0.4).foregroundStyle(t.fg4)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .overlay(alignment: .bottom) { t.lineSoft.frame(height: 0.5) }
    }

    private var caveat: some View {
        Text("Derived from ~/.claude/projects transcripts. A run = a Skill-tool or /slash invocation; tokens are turn-level (approximate) and reactions are inferred from your next message. Cost is an estimate.")
            .font(.system(size: 10)).foregroundStyle(theme.tokens.fg4).lineSpacing(2)
    }

    private var emptyState: some View {
        let t = theme.tokens
        return VStack(spacing: 6) {
            Sym(Icons.gauge, size: 30).foregroundStyle(t.fg3.opacity(0.5))
            Text(store.loaded ? "No skill usage found yet." : "Reading sessions…")
                .font(.system(size: 13)).foregroundStyle(t.fg3).padding(.top, 8)
            Text("Skill runs appear here once you've used skills (via the Skill tool or /commands) in Claude Code sessions stored under ~/.claude/projects.")
                .font(.system(size: 11.5)).foregroundStyle(t.fg4).multilineTextAlignment(.center).frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}

// MARK: - Row

private struct PerfRow: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let metric: SkillMetric
    let last: Bool
    let selected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        let t = theme.tokens
        Button(action: onTap) { rowContent }
            .buttonStyle(.plain)
            .background(selected ? t.accentSoft : (hover ? t.bgHover : .clear))
            .overlay(alignment: .bottom) { if !last { t.lineSoft.frame(height: 0.5) } }
            .onHover { hover = $0 }
    }

    private var rowContent: some View {
        let t = theme.tokens
        return HStack(spacing: 10) {
            verdictPill.frame(width: 64, alignment: .leading)
            Text(metric.name).mono(12).foregroundStyle(t.fg).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(metric.runs)").font(.system(size: 11.5).monospacedDigit()).foregroundStyle(t.fg2)
                .frame(width: 48, alignment: .trailing)
            satisfactionCell.frame(width: 96, alignment: .trailing)
            Text(metric.reactionCount > 0 ? "\(Int(metric.correctionPct.rounded()))%" : "—")
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(metric.correctionPct > 25 ? t.err : t.fg3).frame(width: 80, alignment: .trailing)
            Text(metric.reactionCount > 0 ? "\(Int(metric.cancelPct.rounded()))%" : "—")
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(metric.cancelPct > 10 ? t.err : t.fg3).frame(width: 60, alignment: .trailing)
            Text(formatTokens(metric.avgTokens)).font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(t.fg3).frame(width: 80, alignment: .trailing)
            Text(String(format: "$%.3f", metric.estCostPerRun)).font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(t.fg3).frame(width: 72, alignment: .trailing)
            trend.frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var verdictPill: some View {
        Text(metric.verdict.label.uppercased())
            .font(.system(size: 9, weight: .bold)).tracking(0.4).foregroundStyle(color)
            .padding(.horizontal, 6).frame(height: 17)
            .background(Capsule().fill(color.opacity(0.13)))
    }

    @ViewBuilder private var satisfactionCell: some View {
        let t = theme.tokens
        if let s = metric.satisfactionPct {
            Text("\(Int(s.rounded()))%")
                .foregroundStyle(s >= 70 ? t.ok : (s >= 40 ? t.warn : t.err))
                .font(.system(size: 11.5).monospacedDigit())
        } else {
            Text("—").foregroundStyle(t.fg4).font(.system(size: 11.5).monospacedDigit())
        }
    }

    @ViewBuilder private var trend: some View {
        let t = theme.tokens
        if let st = metric.satisfactionTrend, abs(st) >= 1 {
            let up = st >= 0
            HStack(spacing: 2) {
                Sym(up ? Icons.trendUp : Icons.trendDown, size: 10)
                Text("\(Int(abs(st).rounded()))").font(.system(size: 10).monospacedDigit())
            }.foregroundStyle(up ? t.ok : t.err)
        } else if let tt = metric.tokenTrendPct, abs(tt) >= 5 {
            // No satisfaction signal — fall back to token trend (rising tokens = worse).
            let worse = tt > 0
            HStack(spacing: 2) {
                Sym(worse ? Icons.trendUp : Icons.trendDown, size: 10)
                Text("\(Int(abs(tt).rounded()))%").font(.system(size: 10).monospacedDigit())
            }.foregroundStyle(worse ? t.warn : t.ok)
        } else {
            Text("—").font(.system(size: 11)).foregroundStyle(t.fg4)
        }
    }
}

private func formatTokens(_ n: Int) -> String {
    if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
    return "\(n)"
}

// MARK: - Detail panel

private struct PerfDetailPanel: View {
    @EnvironmentObject private var theme: ThemeManager
    let metric: SkillMetric
    let color: Color
    let onClose: () -> Void

    var body: some View {
        let t = theme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Sym(Icons.gauge, size: 14).foregroundStyle(color)
                    Text(metric.name).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(t.fg)
                    Spacer()
                    Btn(.ghost, sm: true, iconOnly: true, action: onClose) { Sym(Icons.x, size: 12) }
                }

                HStack(spacing: 8) {
                    Text(metric.verdict.label.uppercased())
                        .font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(color)
                        .padding(.horizontal, 9).frame(height: 20)
                        .background(Capsule().fill(color.opacity(0.14)))
                    Text(verdictReason).font(.system(size: 11.5)).foregroundStyle(t.fg3)
                }

                if !metric.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(metric.alerts, id: \.self) { a in
                            HStack(alignment: .top, spacing: 8) {
                                Sym(Icons.alert, size: 12).foregroundStyle(t.warn)
                                Text(a).font(.system(size: 11.5)).foregroundStyle(t.fg2)
                            }
                        }
                    }
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.oklch(0.78, 0.14, 78, 0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.oklch(0.78, 0.14, 78, 0.35), lineWidth: 0.5))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Usage")
                    MetaList(rows: usageRows)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Reactions (\(metric.reactionCount) classified)")
                    if metric.reactionCount == 0 {
                        Text("No clear reactions detected after this skill's runs.")
                            .font(.system(size: 11.5)).foregroundStyle(t.fg3)
                    } else {
                        MetaList(rows: reactionRows)
                    }
                }
                Text("Reactions are inferred heuristically from your next message within ~30s. Neutral reactions (no clear signal) are excluded from these rates.")
                    .font(.system(size: 10)).foregroundStyle(t.fg4).lineSpacing(2)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .background(t.bgSidebar)
        .overlay(alignment: .leading) { t.line.frame(width: 0.5) }
    }

    private var verdictReason: String {
        switch metric.verdict {
        case .keep: return "Healthy — keep using it."
        case .review: return "Worth a look — quality is slipping."
        case .drop: return "High friction — consider revising or retiring."
        }
    }

    private var usageRows: [(String, String)] {
        var rows: [(String, String)] = [
            ("Runs", "\(metric.runs)"),
            ("Avg tokens", "\(metric.avgTokens)"),
            ("Cost/run", String(format: "$%.4f", metric.estCostPerRun)),
            ("Total cost", String(format: "$%.3f", metric.estTotalCost)),
        ]
        if let last = metric.lastUsed {
            let f = RelativeDateTimeFormatter(); f.unitsStyle = .full
            rows.append(("Last used", f.localizedString(for: last, relativeTo: Date())))
        }
        if let tt = metric.tokenTrendPct {
            rows.append(("Token trend", String(format: "%+.0f%% vs prior 14d", tt)))
        }
        return rows
    }

    private var reactionRows: [(String, String)] {
        func pct(_ v: Double) -> String { "\(Int(v.rounded()))%" }
        var rows: [(String, String)] = []
        if let s = metric.satisfactionPct { rows.append(("Satisfied", pct(s))) }
        rows.append(("Corrections", pct(metric.correctionPct)))
        rows.append(("Cancels", pct(metric.cancelPct)))
        rows.append(("Follow-ups", pct(metric.followUpPct)))
        rows.append(("Retries", pct(metric.retryPct)))
        if let st = metric.satisfactionTrend {
            rows.append(("Satisf. trend", String(format: "%+.0f pts vs prior 14d", st)))
        }
        return rows
    }
}
