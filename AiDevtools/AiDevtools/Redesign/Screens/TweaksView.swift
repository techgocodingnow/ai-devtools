import SwiftUI

/// Settings pane (⌘,) exposing the design's Tweaks panel: theme, density, accent, sidebar width.
struct TweaksView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let t = theme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Subtitle("Appearance")

                radio("Theme", ThemeMode.allCases, theme.mode, \.label) { theme.mode = $0 }
                radio("Density", DensityName.allCases, theme.density, \.label) { theme.density = $0 }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Accent").font(.system(size: 12, weight: .medium)).foregroundStyle(t.fg)
                    HStack(spacing: 8) {
                        ForEach(AccentName.allCases) { a in
                            Button { theme.accent = a } label: {
                                Circle().fill(a.primary).frame(width: 22, height: 22)
                                    .overlay(Circle().strokeBorder(theme.accent == a ? t.fg : .clear, lineWidth: 2))
                                    .padding(2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                radio("Sidebar", SidebarLayout.allCases, theme.sidebarLayout, \.label) { theme.sidebarLayout = $0 }

                Divider().background(t.lineSoft).padding(.vertical, 4)
                Subtitle("Demo")
                HStack(spacing: 8) {
                    Btn("Replay onboarding", .normal, sm: true) { store.showOnboarding = true }
                    Btn(.primary, sm: true, action: { store.rescan() }) { Text("Trigger rescan") }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 360, height: 380)
        .background(t.bgWindow)
    }

    private func radio<T: Identifiable & Equatable>(_ title: String, _ options: [T], _ selected: T,
                                                     _ label: KeyPath<T, String>, _ onChange: @escaping (T) -> Void) -> some View {
        let t = theme.tokens
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(t.fg)
            Seg {
                ForEach(options) { opt in
                    SegButton(opt[keyPath: label], on: opt == selected) { onChange(opt) }
                }
            }
        }
    }
}
