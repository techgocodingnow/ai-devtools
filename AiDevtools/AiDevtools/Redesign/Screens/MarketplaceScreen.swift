import SwiftUI

struct MarketplaceScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var enabledSources: [MarketplaceSource] { store.marketplaces.filter { $0.enabled } }
    private var totalItems: Int { enabledSources.reduce(0) { $0 + $1.items } }

    private var filtered: [FeedItem] {
        store.feed.filter { m in
            if let k = store.marketKindFilter, m.kind != k { return false }
            if store.marketSource != "all", m.market != store.marketSource { return false }
            if !store.search.isEmpty {
                let s = store.search.lowercased()
                if !m.name.lowercased().contains(s) && !m.vendor.lowercased().contains(s) && !m.description.lowercased().contains(s) {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenToolbar {
                ScreenHeader("Marketplace") {
                    Text("\(totalItems.formatted()) items across \(enabledSources.count) sources")
                }
                Spacer()
                SearchField(text: $store.search, placeholder: "Search the marketplace…").frame(width: 260)
                Btn(.ghost, sm: true, action: { Task { await store.loadFeed() } }) {
                    Sym(Icons.refresh, size: 12); Text("Sync now")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let f = featured { hero(f) }
                    filterRow
                    grid
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
            }
        }
    }

    /// Pick a real headline item: prefer a verified one, else the first in the feed.
    private var featured: FeedItem? {
        store.feed.first { $0.verified } ?? store.feed.first
    }

    private func hero(_ item: FeedItem) -> some View {
        let t = theme.tokens
        let sourceName = store.marketplaces.first { $0.id == item.market }?.name ?? item.market
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Pill("Featured", style: .accent)
                HStack(spacing: 6) {
                    Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(t.fg)
                    if item.verified { Sym(Icons.shieldOk, size: 13).foregroundStyle(t.accent) }
                }
                .padding(.top, 8).padding(.bottom, 4)
                Text(item.description.isEmpty ? "\(item.vendor) · available from \(sourceName)." : item.description)
                    .font(.system(size: 12)).foregroundStyle(t.fg2).lineSpacing(2)
                    .frame(maxWidth: 460, alignment: .leading).lineLimit(3)
                HStack(spacing: 14) {
                    Label2(Icons.shop, sourceName, t.fg3)
                    Text(item.vendor).mono(11)
                    if item.verified { HStack(spacing: 4) { Sym(Icons.shieldOk, size: 11).foregroundStyle(t.ok); Text("verified") } }
                }
                .font(.system(size: 11.5)).foregroundStyle(t.fg3).padding(.top, 12)
            }
            Spacer()
            Btn(.primary) {} label: { Sym(Icons.download, size: 12); Text("Install") }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Radius.lg)
            .fill(LinearGradient(colors: [Color.oklch(0.22, 0.04, 282, 0.7), t.bgElev], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.oklch(0.66, 0.16, 282, 0.3), lineWidth: 0.5))
    }

    private var filterRow: some View {
        FlowRow(spacing: 8) {
            Seg {
                SegButton("All kinds", on: store.marketKindFilter == nil) { store.marketKindFilter = nil }
                SegButton("Skills", on: store.marketKindFilter == .skill) { store.marketKindFilter = .skill }
                SegButton("Plugins", on: store.marketKindFilter == .plugin) { store.marketKindFilter = .plugin }
                SegButton("MCP servers", on: store.marketKindFilter == .mcp) { store.marketKindFilter = .mcp }
            }
            Seg {
                SegButton("All sources", on: store.marketSource == "all") { store.marketSource = "all" }
                ForEach(enabledSources) { m in
                    SegButton(on: store.marketSource == m.id, action: { store.marketSource = m.id }) {
                        HStack(spacing: 5) { Dot(color: sourceColor(m)); Text(m.name) }
                    }
                }
            }
        }
    }

    private func sourceColor(_ m: MarketplaceSource) -> Color {
        switch m.kind {
        case .official: return theme.tokens.accent
        case .community: return Color.oklch(0.74, 0.13, 152)
        case .github: return Color.oklch(0.66, 0.005, 270)
        case .private: return Color.oklch(0.66, 0.16, 320)
        }
    }

    @ViewBuilder private var grid: some View {
        if store.feed.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(filtered) { m in FeedCard(item: m, sourceName: store.marketplaces.first { $0.id == m.market }?.name ?? m.market) }
            }
        }
    }

    private var emptyState: some View {
        let t = theme.tokens
        return VStack(spacing: 6) {
            Sym(Icons.shop, size: 30).foregroundStyle(t.fg3.opacity(0.5))
            Text(store.marketplaces.isEmpty ? "No marketplace sources configured." : "Loading catalogs from your sources…")
                .font(.system(size: 13)).foregroundStyle(t.fg3).padding(.top, 10)
            Text(store.marketplaces.isEmpty
                 ? "Add a source under Sources to browse installable plugins."
                 : "Hit Sync now if nothing appears.")
                .font(.system(size: 11.5)).foregroundStyle(t.fg3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

private struct FeedCard: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let item: FeedItem
    let sourceName: String
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ItemGlyph(kind: item.kind, name: item.name, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
                        if item.verified { Sym(Icons.shieldOk, size: 12).foregroundStyle(t.accent) }
                    }
                    Text(item.vendor).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(t.fg3)
                }
                Spacer(minLength: 0)
                Pill(item.kind.pill, style: .kind(item.kind))
            }
            Text(item.description).font(.system(size: 11.5)).foregroundStyle(t.fg2).lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                HStack(spacing: 10) {
                    Label2(Icons.download, item.installs, t.fg3, size: 10)
                    HStack(spacing: 4) { Sym(Icons.starFill, size: 10).foregroundStyle(Color.oklch(0.78, 0.13, 78)); Text(String(item.stars)) }
                    Label2(Icons.globe, sourceName, t.fg3, size: 10)
                }
                .font(.system(size: 10.5)).foregroundStyle(t.fg3)
                Spacer()
                Btn(.normal, sm: true) {} label: { Sym(Icons.download, size: 11); Text("Install") }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(hover ? t.bgElev : t.bgPanel))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(t.line, lineWidth: 0.5))
        .onHover { hover = $0 }
    }
}

/// Icon + text label used in stat rows.
struct Label2: View {
    let icon: String; let text: String; let color: Color; var size: CGFloat
    init(_ icon: String, _ text: String, _ color: Color, size: CGFloat = 11) {
        self.icon = icon; self.text = text; self.color = color; self.size = size
    }
    var body: some View {
        HStack(spacing: 4) { Sym(icon, size: size); Text(text) }.foregroundStyle(color)
    }
}

// MARK: - Sources (marketplace settings)

struct SourcesScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        VStack(spacing: 0) {
            ScreenToolbar {
                ScreenHeader("Sources") { Text("Manage marketplace providers and repositories") }
                Spacer()
                Btn(.normal, sm: true) {} label: { Sym(Icons.plus, size: 12); Text("Add source…") }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(store.marketplaces.enumerated()), id: \.element.id) { idx, m in
                                SourceRow(source: m, last: idx == store.marketplaces.count - 1)
                            }
                        }
                    }
                    AddSourceForm()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
    }
}

private struct SourceRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let source: MarketplaceSource
    let last: Bool
    var body: some View {
        let t = theme.tokens
        HStack(spacing: 14) {
            Glyph(label: glyphLabel, color: glyphColor, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(source.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
                    Pill(source.kind.rawValue)
                    trustPill
                }
                HStack(spacing: 14) {
                    Text(source.url).mono(11).foregroundStyle(t.fg3)
                    Text("\(source.items.formatted()) items").font(.system(size: 11)).foregroundStyle(t.fg3)
                    Text("last sync: \(source.lastSync)").font(.system(size: 11)).foregroundStyle(t.fg3)
                }
            }
            Spacer()
            Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.refresh, size: 12) }
            Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.edit, size: 12) }
            ATToggle(isOn: source.enabled) { store.toggleMarketplace(source.id, $0) }
            Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.more, size: 14) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) { if !last { t.lineSoft.frame(height: 0.5) } }
    }
    private var glyphLabel: String {
        switch source.kind { case .official: return "A"; case .community: return "C"; case .github: return "GH"; case .private: return "I" }
    }
    private var glyphColor: Color {
        switch source.kind {
        case .official: return theme.tokens.accent
        case .community: return Color.oklch(0.62, 0.16, 152)
        case .github: return Color.oklch(0.30, 0.005, 270)
        case .private: return Color.oklch(0.62, 0.16, 320)
        }
    }
    @ViewBuilder private var trustPill: some View {
        switch source.trust {
        case .verified: Pill(.accent) { Sym(Icons.shieldOk, size: 10); Text("verified") }
        case .community: Pill("community")
        case .pinned: Pill { Sym(Icons.shield, size: 10); Text("pinned commit") }
        case .private: Pill { Sym(Icons.shield, size: 10); Text("private") }
        }
    }
}

private struct AddSourceForm: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var repo = "anthropic-tools/awesome-skills"
    @State private var branch = "main"
    @State private var displayName = "Awesome Skills (community)"
    @State private var autoSync = true
    var body: some View {
        let t = theme.tokens
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Subtitle("Add a new source")
                HStack(spacing: 8) {
                    ForEach(Array(["Marketplace URL", "GitHub repo", "Local folder", "Internal registry"].enumerated()), id: \.element) { i, label in
                        Btn(label, i == 1 ? .primary : .normal, sm: true)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    field("Repository", text: $repo)
                    field("Branch / tag", text: $branch).frame(width: 160)
                }
                HStack(alignment: .top, spacing: 12) {
                    field("Display name", text: $displayName)
                    VStack(alignment: .leading, spacing: 4) {
                        Subtitle("Trust level", size: 10)
                        FormInput(text: .constant("Pinned commit only"))
                    }.frame(width: 160)
                }
                HStack(spacing: 8) {
                    ATToggle(isOn: autoSync) { autoSync = $0 }
                    Text("Auto-sync every 24h").font(.system(size: 11.5)).foregroundStyle(t.fg2)
                    Spacer()
                    Btn("Cancel", .ghost, sm: true)
                    Btn(.primary, sm: true) {} label: { Sym(Icons.plus, size: 12); Text("Add source") }
                }
                .padding(.top, 4)
            }
        }
    }
    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Subtitle(label, size: 10)
            FormInput(text: text)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Plain text input styled like the design's `.input`.
struct FormInput: View {
    @EnvironmentObject private var theme: ThemeManager
    @Binding var text: String
    var mono: Bool = false
    @FocusState private var focused: Bool
    var body: some View {
        let t = theme.tokens
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: mono ? .monospaced : .default))
            .foregroundStyle(t.fg)
            .focused($focused)
            .padding(.horizontal, 9).frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgInput))
            .overlay(RoundedRectangle(cornerRadius: Radius.r).strokeBorder(focused ? t.accent : t.line, lineWidth: focused ? 1 : 0.5))
    }
}
