import SwiftUI

struct AgentsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            ScreenToolbar {
                ScreenHeader("Agents") {
                    (Text("Auto-detected from ") + Text("PATH").font(.system(size: 11, design: .monospaced))
                     + Text(", common install locations, and config files"))
                }
                Spacer()
                Btn(.ghost, sm: true, action: { store.rescan() }) {
                    Sym(Icons.scan, size: 12); Text(store.scanning ? "Scanning…" : "Rescan")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if store.scanning { scanCard }
                    ForEach(store.agents) { a in AgentCard(agent: a) }
                    addAgentCard
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
    }

    private var scanCard: some View {
        let t = theme.tokens
        return Card(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Sym(Icons.scan, size: 12).foregroundStyle(t.accent)
                    Text("Scanning system for installed agents…").font(.system(size: 12, weight: .medium)).foregroundStyle(t.fg)
                    Spacer()
                    Text("checking \(store.agentCandidateCount) candidates").mono(11).foregroundStyle(t.fg3)
                }
                ScanBar()
            }
        }
    }

    private var addAgentCard: some View {
        let t = theme.tokens
        return Button(action: { store.pickAndAddCustomAgent() }) {
            VStack(spacing: 6) {
                Sym(Icons.plus, size: 16).foregroundStyle(t.fg3)
                Text("Add a custom agent").font(.system(size: 12.5, weight: .medium)).foregroundStyle(t.fg)
                Text("Point at any binary or config dir to register a new agent.").font(.system(size: 11)).foregroundStyle(t.fg3)
            }
            .frame(maxWidth: .infinity).padding(16)
            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(t.bgPanel.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(t.line))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let agent: AgentInfo
    private var supported: [Item] { store.items.filter { $0.agents.contains(agent.id) } }
    var body: some View {
        let t = theme.tokens
        Card(padding: 16) {
            HStack(alignment: .top, spacing: 14) {
                Glyph(label: agent.initials, color: agent.color, size: 44, radius: 10)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(agent.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(t.fg)
                        Pill { Dot(color: agent.detected ? t.ok : t.fg4, ring: agent.detected); Text(agent.detected ? "detected" : "not found") }
                        Text("v\(agent.version)").mono(11).foregroundStyle(t.fg3)
                    }
                    Text(agent.binary).mono(11).foregroundStyle(t.fg3).padding(.top, 4)
                    HStack(spacing: 18) {
                        (Text("\(supported.count)").fontWeight(.bold) + Text(" compatible items"))
                        (Text("\(agent.supports.count)").fontWeight(.bold) + Text(" kinds supported: \(agent.supports.map(\.rawValue).joined(separator: ", "))"))
                        (Text("config: ") + Text("~/.config/\(agent.id)/").font(.system(size: 11.5, design: .monospaced)))
                    }
                    .font(.system(size: 11.5)).foregroundStyle(t.fg2).padding(.top, 10)
                    HStack(spacing: 4) {
                        ForEach(supported.prefix(8)) { ItemGlyph($0, size: 20) }
                        if supported.count > 8 { Pill("+\(supported.count - 8) more") }
                    }
                    .padding(.top, 10)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Btn(.normal, sm: true, action: { store.openAgentShell(agent.id) }) { Sym(Icons.terminal, size: 12); Text("Open shell") }
                    Btn(.ghost, sm: true, action: { store.openAgentConfig(agent.id) }) { Sym(Icons.cog, size: 12); Text("Configure") }
                    if agent.vendor == "Custom" {
                        Btn(.danger, sm: true, action: { store.removeCustomAgent(agent.id) }) { Sym(Icons.trash, size: 12); Text("Remove") }
                    }
                }
            }
        }
    }
}

/// Indeterminate scan progress bar (ports the @keyframes scan animation).
struct ScanBar: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var phase: CGFloat = -0.35
    var body: some View {
        let t = theme.tokens
        GeometryReader { geo in
            Capsule().fill(t.bgElev2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, t.accent, .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.35)
                        .offset(x: geo.size.width * phase)
                }
                .clipShape(Capsule())
        }
        .frame(height: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { phase = 1.0 }
        }
    }
}
