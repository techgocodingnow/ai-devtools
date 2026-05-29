import SwiftUI

struct GroupsScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    @State private var showNewGroup = false
    @State private var newGroupName = ""
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showAddMember = false

    private var selected: Group? {
        store.groups.first { $0.id == store.selectedGroup } ?? store.groups.first
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenToolbar {
                ScreenHeader("Groups") { Text("Bundle related items to enable/disable as a unit") }
                Spacer()
                Btn(.normal, sm: true, action: { newGroupName = ""; showNewGroup = true }) {
                    Sym(Icons.plus, size: 12); Text("New group")
                }
            }
            if store.groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    HStack(alignment: .top, spacing: 14) {
                        listCard
                        if let g = selected { detailCard(g) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
        .alert("New group", isPresented: $showNewGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { store.createGroup(name: newGroupName) }
        } message: { Text("Custom groups live in this app — Claude Code doesn't see them.") }
        .alert("Rename group", isPresented: $showRename) {
            TextField("Group name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { if let g = selected { store.renameGroup(g.id, to: renameText) } }
        }
        .sheet(isPresented: $showAddMember) {
            if let g = selected { AddMemberSheet(group: g).environmentObject(store).environmentObject(theme) }
        }
    }

    private var emptyState: some View {
        let t = theme.tokens
        return VStack(spacing: 6) {
            Sym(Icons.folder, size: 28).foregroundStyle(t.fg3.opacity(0.5))
            Text("No groups yet.").font(.system(size: 13)).foregroundStyle(t.fg3).padding(.top, 10)
            Text("Groups appear from plugins/namespaces, or create your own with New group.")
                .font(.system(size: 11.5)).foregroundStyle(t.fg3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 80)
    }

    private var listCard: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(store.groups.enumerated()), id: \.element.id) { idx, g in
                    GroupRow(group: g, count: store.members(of: g).count,
                             enabled: store.groupEnabled(g), selected: store.selectedGroup == g.id,
                             last: idx == store.groups.count - 1,
                             onToggle: { store.toggleGroup(g) },
                             onSelect: { store.selectedGroup = g.id })
                }
            }
        }
        .frame(width: 320)
    }

    private func detailCard(_ g: Group) -> some View {
        let t = theme.tokens
        let inGroup = store.members(of: g)
        return Card(padding: 18) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Glyph(label: g.initials, color: g.color, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(g.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(t.fg)
                            Pill(g.custom ? "custom" : "derived")
                        }
                        Text(g.description).font(.system(size: 11.5)).foregroundStyle(t.fg3)
                    }
                    Spacer()
                    if g.custom {
                        Btn(.ghost, sm: true, action: { renameText = g.name; showRename = true }) {
                            Sym(Icons.edit, size: 12); Text("Rename")
                        }
                        Btn(.danger, sm: true, action: { store.deleteGroup(g.id) }) {
                            Sym(Icons.trash, size: 12); Text("Delete")
                        }
                    }
                }
                Subtitle("Members · \(inGroup.count)").padding(.top, 18).padding(.bottom, 8)
                if inGroup.isEmpty {
                    Text(g.custom ? "No items yet — add some below." : "No items in this group.")
                        .font(.system(size: 11.5)).foregroundStyle(t.fg3).padding(.horizontal, 10).padding(.vertical, 8)
                }
                ForEach(inGroup) { it in
                    HStack(spacing: 10) {
                        ItemGlyph(it, size: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(it.name).font(.system(size: 12, weight: .medium)).foregroundStyle(t.fg)
                            Text("\(it.vendor) · v\(it.version)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(t.fg3)
                        }
                        Spacer()
                        Pill(it.kind.pill, style: .kind(it.kind))
                        if g.custom {
                            Btn(.ghost, sm: true, iconOnly: true, action: { store.removeMember(it.id, fromGroup: g.id) }) {
                                Sym(Icons.minus, size: 12)
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                }
                if g.custom {
                    Button(action: { showAddMember = true }) {
                        HStack(spacing: 8) { Sym(Icons.plus, size: 12); Text("Add item to group…").font(.system(size: 11.5)) }
                            .foregroundStyle(t.fg3).padding(.horizontal, 10).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
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
    let enabled: Bool
    let selected: Bool
    let last: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    var body: some View {
        let t = theme.tokens
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Glyph(label: group.initials, color: group.color, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(t.fg)
                    Text("\(count) items").font(.system(size: 11)).foregroundStyle(t.fg3)
                }
                Spacer()
                ATToggle(isOn: enabled, sm: true) { _ in onToggle() }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(selected ? t.bgActive : (hover ? t.bgHover : .clear))
            .overlay(alignment: .bottom) { if !last { t.lineSoft.frame(height: 0.5) } }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Searchable picker to add items to a custom group.
private struct AddMemberSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    let group: Group
    @State private var query = ""

    private var candidates: [Item] {
        let existing = Set(group.memberIDs)
        return store.items.filter { item in
            guard !existing.contains(item.id) else { return false }
            guard !query.isEmpty else { return true }
            let q = query.lowercased()
            return item.name.lowercased().contains(q) || item.id.contains(q)
        }
    }

    var body: some View {
        let t = theme.tokens
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Sym(Icons.plus, size: 14).foregroundStyle(t.accent)
                Text("Add to “\(group.name)”").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
                Spacer()
                Btn(.ghost, sm: true, iconOnly: true, action: { dismiss() }) { Sym(Icons.x, size: 12) }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .overlay(alignment: .bottom) { t.lineSoft.frame(height: 0.5) }

            SearchField(text: $query, placeholder: "Search items…")
                .padding(.horizontal, 16).padding(.vertical, 10)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(candidates) { item in
                        Button(action: { store.addMember(item.id, toGroup: group.id) }) {
                            HStack(spacing: 10) {
                                ItemGlyph(item, size: 20)
                                Text(item.name).font(.system(size: 12)).foregroundStyle(t.fg)
                                Spacer()
                                Pill(item.kind.pill, style: .kind(item.kind))
                                Sym(Icons.plus, size: 11).foregroundStyle(t.fg3)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 460, height: 520)
        .background(t.bgElev)
    }
}
