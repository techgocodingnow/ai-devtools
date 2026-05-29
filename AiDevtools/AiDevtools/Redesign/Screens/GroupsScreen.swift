import SwiftUI

struct GroupsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var selected: Group { store.groups.first { $0.id == store.selectedGroup } ?? store.groups[0] }
    private func members(_ g: Group) -> [Item] { store.items.filter { $0.group == g.id } }

    var body: some View {
        VStack(spacing: 0) {
            ScreenToolbar {
                ScreenHeader("Groups") { Text("Bundle related items to enable/disable as a unit") }
                Spacer()
                Btn(.normal, sm: true) {} label: { Sym(Icons.plus, size: 12); Text("New group") }
            }
            ScrollView {
                HStack(alignment: .top, spacing: 14) {
                    listCard
                    detailCard
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
    }

    private var listCard: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(store.groups.enumerated()), id: \.element.id) { idx, g in
                    GroupRow(group: g, count: members(g).count, selected: store.selectedGroup == g.id,
                             last: idx == store.groups.count - 1) { store.selectedGroup = g.id }
                }
            }
        }
        .frame(width: 320)
    }

    private var detailCard: some View {
        let t = theme.tokens
        let g = selected
        let inGroup = members(g)
        return Card(padding: 18) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Glyph(label: g.initials, color: g.color, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.fg)
                        Text(g.description).font(.system(size: 11.5)).foregroundStyle(t.fg3)
                    }
                    Spacer()
                    Btn(.ghost, sm: true) {} label: { Sym(Icons.edit, size: 12); Text("Rename") }
                    Btn(.ghost, sm: true) {} label: { Sym(Icons.cog, size: 12); Text("Settings") }
                }
                Subtitle("Members · \(inGroup.count)").padding(.top, 18).padding(.bottom, 8)
                ForEach(inGroup) { it in
                    HStack(spacing: 10) {
                        ItemGlyph(it, size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(it.name).font(.system(size: 12, weight: .medium)).foregroundStyle(t.fg)
                            Text("\(it.vendor) · v\(it.version)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(t.fg3)
                        }
                        Spacer()
                        Pill(it.kind.pill, style: .kind(it.kind))
                        Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.minus, size: 12) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                }
                HStack(spacing: 8) {
                    Sym(Icons.plus, size: 12); Text("Add item to group…").font(.system(size: 11.5))
                }
                .foregroundStyle(t.fg3).padding(.horizontal, 10).padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GroupRow: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let group: Group
    let count: Int
    let selected: Bool
    let last: Bool
    let action: () -> Void
    var body: some View {
        let t = theme.tokens
        Button(action: action) {
            HStack(spacing: 10) {
                Glyph(label: group.initials, color: group.color, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(t.fg)
                    Text("\(count) items").font(.system(size: 11)).foregroundStyle(t.fg3)
                }
                Spacer()
                ATToggle(isOn: true, sm: true) { _ in }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(selected ? t.bgActive : (hover ? t.bgHover : .clear))
            .overlay(alignment: .bottom) { if !last { t.lineSoft.frame(height: 0.5) } }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
