import SwiftUI

struct ItemDetailScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var detail = ItemDetailData()

    var body: some View {
        let t = theme.tokens
        guard let item = store.openItem else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                toolbar(item, t)
                HStack(spacing: 0) {
                    detailMain(item)
                    ItemDetailSide(item: item)
                        .frame(width: 320)
                }
            }
            .task(id: store.openItemId) { detail = store.loadDetail(item.id) }
        )
    }

    private func toolbar(_ item: Item, _ t: Tokens) -> some View {
        ScreenToolbar(border: true) {
            Btn(.ghost, sm: true, action: { store.nav(.library) }) {
                Sym(Icons.chev, size: 12).rotationEffect(.degrees(180)); Text("Library")
            }
            Rectangle().fill(t.line).frame(width: 0.5, height: 16)
            ItemGlyph(item, size: 22)
            Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
            Text("v\(item.version)").mono(11).foregroundStyle(t.fg3)
            Pill(item.kind.pill, style: .kind(item.kind))
            if item.status != .ok {
                Pill(.custom(bg: item.status == .err ? Color.oklch(0.66, 0.20, 25, 0.18) : Color.oklch(0.78, 0.14, 78, 0.18),
                             fg: item.status == .err ? t.err : t.warn)) {
                    Sym(Icons.alert, size: 10); Text(item.warning ?? "Needs attention")
                }
            }
            Spacer()
            Btn(.ghost, sm: true) {} label: { Sym(Icons.refresh, size: 12); Text("Check for updates") }
            Btn(.normal, sm: true) {} label: { Sym(Icons.edit, size: 12); Text("Edit") }
            Btn(.danger, sm: true, action: { store.copyRemoveCommand(item.id) }) { Sym(Icons.trash, size: 12); Text("Remove…") }
        }
    }

    private func detailMain(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TabBar(tabs: DetailTab.allCases, selection: store.detailTab) { store.detailTab = $0 } label: { $0.label }
                .padding(.horizontal, 24)
            ScrollView {
                SwiftUI.Group {
                    switch store.detailTab {
                    case .overview: OverviewTab(item: item, detail: detail)
                    case .config: ConfigTab(item: item, detail: detail)
                    case .permissions: PermissionsTab(item: item)
                    case .logs: LogsTab(item: item)
                    case .source: SourceTab(item: item, detail: detail)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Tab bar

struct TabBar<T: Hashable>: View {
    @EnvironmentObject private var theme: ThemeManager
    let tabs: [T]
    let selection: T
    let onSelect: (T) -> Void
    let label: (T) -> String

    var body: some View {
        let t = theme.tokens
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let active = tab == selection
                Button { onSelect(tab) } label: {
                    Text(label(tab))
                        .font(.system(size: 12))
                        .foregroundStyle(active ? t.fg : t.fg3)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(active ? t.accent : .clear).frame(height: 1.5)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { t.line.frame(height: 0.5) }
        .padding(.bottom, 14)
    }
}

// MARK: - Shared

/// Honest placeholder for tabs whose data source isn't wired yet (see docs/PENDING.md).
private struct NotWiredCard: View {
    @EnvironmentObject private var theme: ThemeManager
    let title: String
    let plan: String
    var body: some View {
        let t = theme.tokens
        Card(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Sym(Icons.info, size: 13).foregroundStyle(t.fg3)
                    Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(t.fg)
                    Pill("not yet wired")
                }
                Text(plan).font(.system(size: 12)).foregroundStyle(t.fg3).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Overview

private struct OverviewTab: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    let detail: ItemDetailData

    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 14) {
            if let d = item.description, !d.isEmpty {
                Text(d).font(.system(size: 13)).lineSpacing(3).foregroundStyle(t.fg2)
            }

            FlowRow(spacing: 8) {
                if let g = store.group(item.group) {
                    Pill { Dot(color: g.color); Text(g.name) }
                }
                Pill { Sym(Icons.box, size: 10); Text(detail.origin) }
                if item.updated != "—" { Pill("Updated \(item.updated)") }
                if item.size != "—" { Pill(item.size) }
            }

            if !detail.capabilities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Metadata")
                    ForEach(detail.capabilities) { cap in
                        HStack(alignment: .top, spacing: 8) {
                            Sym(Icons.check, size: 12).foregroundStyle(t.ok)
                            Text(cap.label).mono(11).foregroundStyle(t.fg2).frame(width: 110, alignment: .leading)
                            Text(cap.detail).font(.system(size: 12)).foregroundStyle(t.fg3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Subtitle("Files")
                if detail.files.isEmpty {
                    Text("No files on disk for this item.").font(.system(size: 12)).foregroundStyle(t.fg3)
                } else {
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(detail.files.enumerated()), id: \.element.id) { idx, f in
                                HStack(spacing: 8) {
                                    Sym(Icons.box, size: 11).foregroundStyle(t.fg3)
                                    Text(f.name).mono(11).foregroundStyle(t.fg2)
                                    Spacer()
                                    Text(f.size).font(.system(size: 11.5)).foregroundStyle(t.fg3)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .overlay(alignment: .bottom) { if idx < detail.files.count - 1 { t.lineSoft.frame(height: 0.5) } }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Configuration (real file body)

private struct ConfigTab: View {
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    let detail: ItemDetailData
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 14) {
            if let text = detail.configText, !text.isEmpty {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Sym(Icons.cog, size: 12).foregroundStyle(t.fg3)
                            Text(detail.configFileName ?? "config").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.fg)
                            Spacer()
                            if let path = detail.locationPath {
                                Text(path).mono(10.5).foregroundStyle(t.fg3).lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .overlay(alignment: .bottom) { t.lineSoft.frame(height: 0.5) }
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            Text(text)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(t.fg2)
                                .textSelection(.enabled)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 460)
                        .background(t.bgSidebar)
                    }
                }
            } else {
                Text("No configuration file found for this item.")
                    .font(.system(size: 12)).foregroundStyle(t.fg3)
            }
        }
    }
}

// MARK: - Permissions (not yet wired — see docs/PENDING.md #1)

private struct PermissionsTab: View {
    let item: Item
    var body: some View {
        NotWiredCard(
            title: "Permissions",
            plan: "Per-item permissions aren't stored on disk. Planned: read permissions.allow / deny / ask from ~/.claude/settings.json and surface the global rules that apply to this item (its MCP tool names or plugin commands)."
        )
    }
}

// MARK: - Activity (not yet wired — see docs/PENDING.md #1)

private struct LogsTab: View {
    let item: Item
    var body: some View {
        NotWiredCard(
            title: "Activity",
            plan: "No per-item activity feed exists yet. Planned: mine local logs (history.jsonl, projects/*/ session transcripts, telemetry/) for events referencing this item. Requires a log-indexing pass; deferred."
        )
    }
}

// MARK: - Source (real path + origin)

private struct SourceTab: View {
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    let detail: ItemDetailData
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 14) {
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Origin")
                    HStack {
                        Sym(Icons.box, size: 14).foregroundStyle(t.fg3)
                        Text(detail.origin).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(t.fg)
                    }
                    if let src = detail.sourcePath {
                        Text(src).mono(11).foregroundStyle(t.fg3).textSelection(.enabled)
                    }
                }
            }
            if let path = detail.locationPath {
                Card(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Subtitle("Local path")
                        Text(path).mono(11.5).foregroundStyle(t.fg).textSelection(.enabled)
                    }
                }
            }
        }
    }
}

// MARK: - Side panel

struct ItemDetailSide: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    var body: some View {
        let t = theme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Scopes")
                    VStack(spacing: 1) {
                        ForEach(store.workspaces) { w in
                            ScopeRow(workspace: w,
                                     installed: item.scopes[w.id] == true,
                                     enabled: item.enabled[w.id] == true,
                                     onToggle: { store.setScopeEnabled(item.id, ws: w.id, $0) },
                                     onInstall: { store.installScope(item.id, ws: w.id) })
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Supported agents")
                    ForEach(store.agents) { a in
                        let on = item.agents.contains(a.id)
                        HStack {
                            AgentBadge(agent: a, size: 16)
                            Text(a.name).font(.system(size: 11.5)).foregroundStyle(t.fg)
                            Spacer()
                            if on { Sym(Icons.check, size: 11).foregroundStyle(t.ok) }
                            else { Sym(Icons.x, size: 10).foregroundStyle(t.fg3) }
                        }
                        .opacity(on ? 1 : 0.4)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Metadata")
                    MetaList(rows: meta)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .background(t.bgSidebar)
        .overlay(alignment: .leading) { t.line.frame(width: 0.5) }
    }
    private var meta: [(String, String)] {
        var r: [(String, String)] = [
            ("ID", item.id), ("Vendor", item.vendor), ("Version", item.version),
            ("Group", item.group ?? "—"), ("Size", item.size), ("Updated", item.updated),
        ]
        if let a = item.auth { r.append(("Auth", a)) }
        return r
    }
}

struct ScopeRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let workspace: Workspace
    let installed: Bool
    let enabled: Bool
    let onToggle: (Bool) -> Void
    let onInstall: () -> Void
    var body: some View {
        let t = theme.tokens
        HStack(spacing: 8) {
            GradientGlyph(label: workspace.initials, gradient: workspace.gradient, size: 16, radius: 4)
            Text(workspace.name).font(.system(size: 11.5)).foregroundStyle(installed ? t.fg : t.fg3)
            Spacer()
            if installed {
                ATToggle(isOn: enabled, sm: true) { onToggle($0) }
            } else {
                Btn(.ghost, sm: true, iconOnly: true, action: onInstall) { Sym(Icons.plus, size: 11) }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 5).fill(installed ? t.bgElev : .clear))
    }
}

struct MetaList: View {
    @EnvironmentObject private var theme: ThemeManager
    let rows: [(String, String)]
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.0) { k, v in
                HStack(alignment: .top, spacing: 10) {
                    Text(k).font(.system(size: 11.5)).foregroundStyle(t.fg3).frame(width: 80, alignment: .leading)
                    Text(v).font(.system(size: 11.5, design: k == "ID" || k == "Version" ? .monospaced : .default))
                        .foregroundStyle(t.fg).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Flow layout (wrapping rows of pills)

struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
