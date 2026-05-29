import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(LinearGradient(colors: [t.accent, Color.oklch(0.66, 0.16, 320)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(Text("⌘").font(.system(size: 20, weight: .bold)).foregroundStyle(.white))
                .shadow(color: Color.oklch(0.66, 0.16, 282, 0.4), radius: 12, y: 8)
                .padding(.bottom, 16)

            (Text("Welcome to AgentToolKit").font(.system(size: 22, weight: .semibold))
             + Text("  \(Self.appVersion)").font(.system(size: 16)).foregroundColor(t.fg4))
                .foregroundColor(t.fg)
                .padding(.bottom, 6)

            Text("A single place to manage every skill, plugin and MCP server across all your AI coding agents — globally, or per-project.")
                .font(.system(size: 13)).foregroundStyle(t.fg2).lineSpacing(3).padding(.bottom, 18)

            Subtitle("Detected on this machine").padding(.bottom, 8)
            VStack(spacing: 6) {
                ForEach(store.agents) { a in AgentPick(agent: a) }
            }

            Card(padding: 12) {
                HStack(spacing: 10) {
                    Sym(Icons.info, size: 14).foregroundStyle(t.accent)
                    Text("AgentToolKit will read configurations from each agent's standard install directory. We never upload your local config or secrets.")
                        .font(.system(size: 11.5)).foregroundStyle(t.fg2).lineSpacing(2)
                }
            }
            .padding(.top, 14)

            HStack(spacing: 8) {
                Spacer()
                Btn("Skip", .ghost, sm: true) { store.showOnboarding = false }
                Btn(.primary, action: { store.showOnboarding = false }) { Text("Get started"); Sym(Icons.chev, size: 12) }
            }
            .padding(.top, 18)
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: Radius.xl).fill(t.bgElev))
        .overlay(RoundedRectangle(cornerRadius: Radius.xl).strokeBorder(t.line, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 32, y: 12)
    }

    /// Real app version from the bundle.
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).map { "v\($0)" } ?? ""
    }
}

private struct AgentPick: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let agent: AgentInfo
    var body: some View {
        let t = theme.tokens
        HStack(spacing: 10) {
            Glyph(label: agent.initials, color: agent.color, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                (Text(agent.name).font(.system(size: 12.5, weight: .semibold))
                 + Text("  v\(agent.version)").font(.system(size: 12)).foregroundColor(t.fg3))
                    .foregroundColor(t.fg)
                Text(agent.binary).font(.system(size: 11, design: .monospaced)).foregroundStyle(t.fg3)
            }
            Spacer()
            if agent.detected {
                Pill { Dot(color: t.ok, ring: true); Text("detected") }
            } else {
                Pill { Dot(color: t.fg4); Text("not found") }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(hover ? t.bgHover : t.bgPanel))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.line, lineWidth: 0.5))
        .onHover { hover = $0 }
    }
}
