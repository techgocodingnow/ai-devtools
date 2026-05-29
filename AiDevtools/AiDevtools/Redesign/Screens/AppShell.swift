import SwiftUI

struct AppShell: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let t = theme.tokens
        ZStack {
            VStack(spacing: 0) {
                TitleBar()
                HStack(spacing: 0) {
                    Sidebar()
                        .frame(width: theme.sidebarWidth)
                    VStack(spacing: 0) {
                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        StatusBar()
                    }
                }
            }
            .background(t.bgWindow)

            if store.showOnboarding {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { store.showOnboarding = false }
                OnboardingView()
                    .frame(maxWidth: 520)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if let toast = store.toast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Sym(Icons.copy, size: 12).foregroundStyle(t.accent)
                        Text(toast).font(.system(size: 11.5)).foregroundStyle(t.fg)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(t.bgElev))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(t.line, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: store.showOnboarding)
        .animation(.easeInOut(duration: 0.2), value: store.toast)
        .environment(\.colorScheme, theme.colorScheme)
    }

    @ViewBuilder private var content: some View {
        switch store.screen {
        case .library: LibraryScreen()
        case .itemDetail: ItemDetailScreen()
        case .marketplace: MarketplaceScreen()
        case .sources: SourcesScreen()
        case .groups: GroupsScreen()
        case .agents: AgentsScreen()
        case .hooks: HooksScreen()
        }
    }
}

// MARK: - Title bar (custom breadcrumb; OS traffic lights overlay top-left)

struct TitleBar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let t = theme.tokens
        let ws = store.currentWorkspace
        HStack(spacing: 10) {
            // reserve room for the real macOS traffic lights
            Color.clear.frame(width: 68, height: 1)

            crumb("AgentToolKit", head: true)
            sep
            crumb(ws.name)
            sep
            crumb(store.screen.label)
            if store.screen == .itemDetail, let item = store.openItem {
                sep
                crumb(item.name)
            }

            Spacer(minLength: 8)

            Btn(.ghost, sm: true, iconOnly: true, action: { store.showOnboarding = true }) {
                Sym(Icons.info, size: 12)
            }
            Btn(.ghost, sm: true, iconOnly: true, action: { store.nav(.agents) }) {
                Sym(Icons.cube, size: 12)
            }
            scopeChip(ws)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(t.bgSidebar)
        .overlay(alignment: .bottom) { t.line.frame(height: 0.5) }
    }

    private var sep: some View { Text("/").font(.system(size: 12)).foregroundStyle(theme.tokens.fg4) }

    private func crumb(_ text: String, head: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12, weight: head ? .semibold : .regular))
            .foregroundStyle(head ? theme.tokens.fg : theme.tokens.fg2)
            .lineLimit(1)
    }

    private func scopeChip(_ ws: Workspace) -> some View {
        let t = theme.tokens
        let global = ws.scope == .global
        return HStack(spacing: 6) {
            Dot(color: global ? t.ok : t.catMCP, ring: global)
            Text(global ? "global scope" : "project scope")
                .font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(t.accent)
        .padding(.leading, 6).padding(.trailing, 8)
        .frame(height: 24)
        .background(Capsule().fill(t.accentSoft))
    }
}

// MARK: - Status bar

struct StatusBar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let t = theme.tokens
        let ws = store.currentWorkspace
        let inScope = store.items.filter { $0.scopes[store.workspace] == true }
        let total = inScope.count
        let enabled = inScope.filter { $0.enabled[store.workspace] == true }.count
        let issues = inScope.filter { $0.status == .warn || $0.status == .err }.count

        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Dot(color: ws.scope == .global ? t.ok : t.catMCP, ring: ws.scope == .global)
                Text(ws.path)
            }
            Text("·")
            Text("\(enabled)/\(total) enabled")
            if issues > 0 {
                Text("·")
                Text("\(issues) issue\(issues > 1 ? "s" : "")").foregroundStyle(t.warn)
            }
            Spacer()
            let detected = store.agents.filter { $0.detected }.count
            Text("\(detected) agent\(detected == 1 ? "" : "s") detected")
            Text("·")
            HStack(spacing: 6) { Dot(color: t.ok, ring: true); Text("online") }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(t.fg3)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(t.bgSidebar)
        .overlay(alignment: .top) { t.line.frame(height: 0.5) }
    }
}
