import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private func countFor(_ kind: ItemKind) -> Int {
        store.items.filter { $0.kind == kind && $0.scopes[store.workspace] == true }.count
    }
    private var hooksActive: Int {
        store.hooks.filter { $0.scopes[store.workspace] == true && $0.enabled[store.workspace] == true }.count
    }

    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 0) {
            WorkspacePicker()
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SidebarRow(icon: Icons.layers, label: "Library", count: countFor(.skill) + countFor(.plugin) + countFor(.mcp),
                               active: store.screen == .library && store.kindFilter == nil && store.groupFilter == nil) {
                        store.nav(.library)
                    }

                    SectionHeader("Categories")
                    kindRow(.skill)
                    kindRow(.plugin)
                    kindRow(.mcp)
                    SidebarRow(dotColor: t.catHook, label: "Hooks", count: hooksActive,
                               active: store.screen == .hooks) { store.nav(.hooks) }

                    SectionHeader("Groups", addAction: { store.nav(.groups) })
                    ForEach(store.groups.prefix(6)) { g in
                        SidebarRow(dotColor: g.color, label: g.name, count: g.items,
                                   active: store.screen == .library && store.groupFilter == g.id) {
                            store.nav(.library, group: g.id)
                        }
                    }

                    SectionHeader("Discover")
                    SidebarRow(icon: Icons.shop, label: "Marketplace", badge: "124 new",
                               active: store.screen == .marketplace) { store.nav(.marketplace) }
                    SidebarRow(icon: Icons.globe, label: "Sources",
                               active: store.screen == .sources) { store.nav(.sources) }

                    SectionHeader("System")
                    SidebarRow(icon: Icons.cube, label: "Agents",
                               active: store.screen == .agents) { store.nav(.agents) }
                    SidebarRow(icon: Icons.folder, label: "Groups", count: store.groups.count,
                               active: store.screen == .groups) { store.nav(.groups) }
                }
                .padding(.bottom, 8)
            }

            SidebarRow(icon: Icons.user, label: "kuro", trailingIcon: Icons.cog, active: false) {}
                .padding(.bottom, 6)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(t.bgSidebar)
        .overlay(alignment: .trailing) { t.line.frame(width: 0.5) }
    }

    private func kindRow(_ kind: ItemKind) -> some View {
        SidebarRow(dotColor: theme.tokens.categoryColor(kind), label: kind.plural, count: countFor(kind),
                   active: store.screen == .library && store.kindFilter == kind) {
            store.nav(.library, kind: kind)
        }
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    @EnvironmentObject private var theme: ThemeManager
    let title: String
    var addAction: (() -> Void)?
    init(_ title: String, addAction: (() -> Void)? = nil) { self.title = title; self.addAction = addAction }
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(theme.tokens.fg4)
            Spacer()
            if let addAction {
                Button(action: addAction) { Sym(Icons.plus, size: 10).foregroundStyle(theme.tokens.fg3) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.leading, 14).padding(.trailing, 6)
        .padding(.top, 10).padding(.bottom, 4)
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false

    var icon: String?
    var dotColor: Color?
    var label: String
    var count: Int?
    var badge: String?
    var trailingIcon: String?
    var active: Bool
    var action: () -> Void

    init(icon: String? = nil, dotColor: Color? = nil, label: String, count: Int? = nil,
         badge: String? = nil, trailingIcon: String? = nil, active: Bool, action: @escaping () -> Void) {
        self.icon = icon; self.dotColor = dotColor; self.label = label; self.count = count
        self.badge = badge; self.trailingIcon = trailingIcon; self.active = active; self.action = action
    }

    var body: some View {
        let t = theme.tokens
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Sym(icon, size: 13).frame(width: 14).foregroundStyle(active ? t.accent : t.fg3)
                } else if let dotColor {
                    Dot(color: dotColor).padding(.horizontal, 1)
                }
                Text(label)
                    .font(.system(size: 12.5))
                    .foregroundStyle(active ? t.fg : (hover ? t.fg : t.fg2))
                    .lineLimit(1)
                if let badge {
                    Pill(badge)
                }
                Spacer(minLength: 0)
                if let trailingIcon {
                    Sym(trailingIcon, size: 12).foregroundStyle(t.fg4)
                } else if let count {
                    Text("\(count)")
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(t.fg4)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: max(28, theme.metrics.rowH - 2))
            .background(RoundedRectangle(cornerRadius: 6).fill(active ? t.bgActive : (hover ? t.bgHover : .clear)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .onHover { hover = $0 }
    }
}

// MARK: - Workspace picker

private struct WorkspacePicker: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false

    var body: some View {
        let t = theme.tokens
        let ws = store.currentWorkspace
        Button { store.wsMenuOpen.toggle() } label: {
            HStack(spacing: 8) {
                GradientGlyph(label: ws.initials, gradient: ws.gradient, size: 28, radius: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ws.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.fg).lineLimit(1)
                    Text(ws.path).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(t.fg3).lineLimit(1)
                }
                Spacer(minLength: 0)
                Sym(Icons.swap, size: 12).foregroundStyle(t.fg3)
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 6)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 8).fill(hover ? t.bgElev2 : t.bgElev))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .popover(isPresented: $store.wsMenuOpen, arrowEdge: .bottom) {
            WorkspaceMenu().environmentObject(store).environmentObject(theme)
        }
    }
}

private struct WorkspaceMenu: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 2) {
            Text("SWITCH WORKSPACE")
                .font(.system(size: 10.5, weight: .semibold)).tracking(0.4)
                .foregroundStyle(t.fg4).padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 2)
            ForEach(store.workspaces) { w in
                MenuRow {
                    GradientGlyph(label: w.initials, gradient: w.gradient, size: 18, radius: 4)
                    Text(w.name).font(.system(size: 12.5)).foregroundStyle(t.fg)
                    Spacer(minLength: 8)
                    if w.scope == .global { Pill("global") }
                    if w.id == store.workspace { Sym(Icons.check, size: 12).foregroundStyle(t.fg2) }
                } action: { store.switchWorkspace(w.id) }
            }
            Divider().background(t.lineSoft).padding(.vertical, 4)
            MenuRow { Sym(Icons.plus, size: 12).foregroundStyle(t.fg3); Text("Open project folder…").font(.system(size: 12.5)).foregroundStyle(t.fg3) } action: {}
            MenuRow { Sym(Icons.cog, size: 12).foregroundStyle(t.fg3); Text("Workspace settings").font(.system(size: 12.5)).foregroundStyle(t.fg3) } action: {}
        }
        .padding(4)
        .frame(width: 240)
        .background(t.bgElev)
    }
}

private struct MenuRow<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    @ViewBuilder var content: () -> Content
    var action: () -> Void
    init(@ViewBuilder content: @escaping () -> Content, action: @escaping () -> Void) {
        self.content = content; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5).fill(hover ? theme.tokens.accent : .clear))
                .foregroundStyle(hover ? Color.white : theme.tokens.fg)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
