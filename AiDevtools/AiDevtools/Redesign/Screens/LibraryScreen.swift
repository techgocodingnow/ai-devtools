import SwiftUI

// MARK: - Shared screen header (title + subtitle on the left of a toolbar row)

struct ScreenHeader: View {
    @EnvironmentObject private var theme: ThemeManager
    let title: String
    let subtitle: AnyView
    init(_ title: String, @ViewBuilder subtitle: () -> some View) {
        self.title = title; self.subtitle = AnyView(subtitle())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.tokens.fg)
            subtitle.font(.system(size: 11)).foregroundStyle(theme.tokens.fg3)
        }
    }
}

/// Standard toolbar container — 44px, bottom hairline optional.
struct ScreenToolbar<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    var border: Bool = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 8) { content() }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(theme.tokens.bgWindow)
            .overlay(alignment: .bottom) { if border { theme.tokens.line.frame(height: 0.5) } }
    }
}

// MARK: - Library

struct LibraryScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var filtered: [Item] {
        store.items.filter { it in
            guard it.scopes[store.workspace] == true else { return false }
            if let k = store.kindFilter, it.kind != k { return false }
            if let g = store.groupFilter, it.group != g { return false }
            switch store.statusFilter {
            case .enabled where it.enabled[store.workspace] != true: return false
            case .disabled where it.enabled[store.workspace] == true: return false
            case .issues where it.status != .warn && it.status != .err: return false
            default: break
            }
            if !store.search.isEmpty {
                let s = store.search.lowercased()
                if !it.name.lowercased().contains(s) && !it.vendor.lowercased().contains(s) && !it.id.contains(s) {
                    return false
                }
            }
            return true
        }
    }

    private var issueCount: Int { filtered.filter { $0.status == .warn || $0.status == .err }.count }

    private var headerTitle: String {
        if let k = store.kindFilter { return k.plural }
        if let g = store.groupFilter { return store.groups.first { $0.id == g }?.name ?? "All items" }
        return "All items"
    }

    var body: some View {
        let t = theme.tokens
        VStack(spacing: 0) {
            ScreenToolbar {
                ScreenHeader(headerTitle) {
                    HStack(spacing: 0) {
                        Text("\(filtered.count) \(filtered.count == 1 ? "item" : "items") · ")
                        Text(store.currentWorkspace.name).foregroundStyle(t.accent)
                        if issueCount > 0 {
                            Text(" · ") + Text("\(issueCount) need attention").foregroundColor(t.warn)
                        }
                    }
                }
                Spacer()
                SearchField(text: $store.search, placeholder: "Search items…").frame(width: 220)
                statusSeg
                viewSeg
                Btn(.normal, sm: true, action: { store.nav(.marketplace) }) { Sym(Icons.download, size: 12); Text("Install…") }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if store.viewMode == .list && store.kindFilter == nil && store.groupFilter == nil {
                        ForEach(ItemKind.allCases) { kind in
                            let group = filtered.filter { $0.kind == kind }
                            if !group.isEmpty {
                                LibrarySection(kind: kind, items: group)
                            }
                        }
                    } else if store.viewMode == .list {
                        LibraryTable(items: filtered)
                    } else {
                        LibraryGrid(items: filtered)
                    }

                    if filtered.isEmpty { emptyState }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var statusSeg: some View {
        Seg {
            SegButton("All", on: store.statusFilter == .all) { store.statusFilter = .all }
            SegButton("On", on: store.statusFilter == .enabled) { store.statusFilter = .enabled }
            SegButton("Off", on: store.statusFilter == .disabled) { store.statusFilter = .disabled }
            SegButton(on: store.statusFilter == .issues, action: { store.statusFilter = .issues }) {
                HStack(spacing: 4) {
                    Text("Issues")
                    if issueCount > 0 {
                        Text("\(issueCount)").font(.system(size: 10))
                            .foregroundStyle(.white).padding(.horizontal, 5)
                            .background(Capsule().fill(theme.tokens.err))
                    }
                }
            }
        }
    }

    private var viewSeg: some View {
        Seg {
            SegButton(on: store.viewMode == .list, action: { store.viewMode = .list }) { Sym(Icons.list, size: 12) }
            SegButton(on: store.viewMode == .grid, action: { store.viewMode = .grid }) { Sym(Icons.grid, size: 12) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Sym(Icons.search, size: 32).foregroundStyle(theme.tokens.fg3.opacity(0.5))
            Text("No items match your filters.").font(.system(size: 13)).foregroundStyle(theme.tokens.fg3).padding(.top, 10)
            Text("Try clearing the search or changing scope to Global.")
                .font(.system(size: 11.5)).foregroundStyle(theme.tokens.fg3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

// MARK: - Section (kind header + table)

private struct LibrarySection: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let kind: ItemKind
    let items: [Item]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Dot(color: theme.tokens.categoryColor(kind))
                Text(kind.plural).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.tokens.fg)
                Text("\(items.count)").font(.system(size: 11).monospacedDigit()).foregroundStyle(theme.tokens.fg3)
                Spacer()
                Btn(.ghost, sm: true, action: { store.nav(.library, kind: kind) }) {
                    Text("View all"); Sym(Icons.chev, size: 11)
                }
            }
            LibraryTable(items: items)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

// MARK: - Table

struct LibraryColumns {
    static let toggle: CGFloat = 34
    static let kind: CGFloat = 70
    static let vendor: CGFloat = 130
    static let version: CGFloat = 60
    static let agents: CGFloat = 90
    static let updated: CGFloat = 100
    static let status: CGFloat = 96
    static let more: CGFloat = 36
}

struct LibraryTable: View {
    @EnvironmentObject private var theme: ThemeManager
    let items: [Item]
    var body: some View {
        let t = theme.tokens
        VStack(spacing: 0) {
            header
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                LibraryRow(item: item, last: idx == items.count - 1)
            }
        }
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(t.bgPanel))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(t.line, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    private var header: some View {
        let t = theme.tokens
        return HStack(spacing: 8) {
            Color.clear.frame(width: LibraryColumns.toggle)
            cell("NAME").frame(maxWidth: .infinity, alignment: .leading)
            cell("KIND").frame(width: LibraryColumns.kind, alignment: .leading)
            cell("VENDOR").frame(width: LibraryColumns.vendor, alignment: .leading)
            cell("VERSION").frame(width: LibraryColumns.version, alignment: .leading)
            cell("AGENTS").frame(width: LibraryColumns.agents, alignment: .leading)
            cell("UPDATED").frame(width: LibraryColumns.updated, alignment: .leading)
            cell("STATUS").frame(width: LibraryColumns.status, alignment: .leading)
            Color.clear.frame(width: LibraryColumns.more)
        }
        .padding(.horizontal, theme.metrics.padX)
        .padding(.vertical, theme.metrics.padY)
        .background(t.bgSidebar)
        .overlay(alignment: .bottom) { t.lineSoft.frame(height: 0.5) }
    }
    private func cell(_ s: String) -> some View {
        Text(s).font(.system(size: 10.5, weight: .semibold)).tracking(0.4).foregroundStyle(theme.tokens.fg3)
    }
}

struct LibraryRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let item: Item
    let last: Bool

    var body: some View {
        let t = theme.tokens
        let enabled = item.enabled[store.workspace] == true
        Button { store.openItem(item.id) } label: {
            HStack(spacing: 8) {
                ATToggle(isOn: enabled, sm: true) { store.toggleEnabled(item.id, $0) }
                    .frame(width: LibraryColumns.toggle, alignment: .leading)

                HStack(spacing: 9) {
                    ItemGlyph(item, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(enabled ? t.fg : t.fg3).lineLimit(1)
                        Text(item.id).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(t.fg3).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Pill(item.kind.pill, style: .kind(item.kind)).frame(width: LibraryColumns.kind, alignment: .leading)
                Text(item.vendor).font(.system(size: 11.5)).foregroundStyle(t.fg3).lineLimit(1)
                    .frame(width: LibraryColumns.vendor, alignment: .leading)
                Text(item.version).mono(11).foregroundStyle(t.fg2).frame(width: LibraryColumns.version, alignment: .leading)
                AgentRow(ids: item.agents, store: store).frame(width: LibraryColumns.agents, alignment: .leading)
                Text(item.updated).font(.system(size: 11.5)).foregroundStyle(t.fg3).lineLimit(1)
                    .frame(width: LibraryColumns.updated, alignment: .leading)
                statusCell(enabled, t).frame(width: LibraryColumns.status, alignment: .leading)
                Menu {
                    Button("Open") { store.openItem(item.id) }
                    Button("Reveal in Finder") { store.revealItemInFinder(item.id) }
                    Divider()
                    Button("Remove…", role: .destructive) { store.requestRemove(item.id) }
                } label: { Sym(Icons.more, size: 14) }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .frame(width: LibraryColumns.more)
            }
            .padding(.horizontal, theme.metrics.padX)
            .padding(.vertical, theme.metrics.padY + 1)
            .background(hover ? t.bgHover : .clear)
            .overlay(alignment: .bottom) { if !last { t.lineSoft.frame(height: 0.5) } }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private func statusCell(_ enabled: Bool, _ t: Tokens) -> some View {
        HStack(spacing: 6) {
            Dot(status: item.status, theme: t)
            Text(item.status == .ok ? (enabled ? "Enabled" : "Disabled") : item.status.label)
                .font(.system(size: 11.5))
                .foregroundStyle(item.status == .err ? t.err : item.status == .warn ? t.warn : t.fg2)
        }
    }
}

/// Horizontal stack of small agent badges.
struct AgentRow: View {
    let ids: [String]
    let store: AppStore
    var size: CGFloat = 18
    var body: some View {
        HStack(spacing: 2) {
            ForEach(ids, id: \.self) { id in
                if let a = store.agent(id) { AgentBadge(agent: a, size: size) }
            }
        }
    }
}

// MARK: - Grid

struct LibraryGrid: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let items: [Item]
    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 260), spacing: theme.metrics.gap)] }
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: theme.metrics.gap) {
            ForEach(items) { item in LibraryGridCard(item: item) }
        }
        .padding(.top, 8)
    }
}

private struct LibraryGridCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let item: Item
    var body: some View {
        let t = theme.tokens
        let enabled = item.enabled[store.workspace] == true
        Button { store.openItem(item.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ItemGlyph(item, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
                            if item.status == .warn { Sym(Icons.alert, size: 12).foregroundStyle(t.warn) }
                            if item.status == .err { Sym(Icons.alert, size: 12).foregroundStyle(t.err) }
                        }
                        Text("\(item.vendor) · v\(item.version)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(t.fg3)
                    }
                    Spacer(minLength: 0)
                    ATToggle(isOn: enabled, sm: true) { store.toggleEnabled(item.id, $0) }
                }
                HStack {
                    Pill(item.kind.pill, style: .kind(item.kind))
                    Spacer()
                    AgentRow(ids: item.agents, store: store, size: 16)
                }
            }
            .padding(theme.metrics.tilePad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(hover ? t.bgElev : t.bgPanel))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(t.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
