import SwiftUI

struct GlobalCapabilitiesListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore
    @State private var kindFilter: CapabilityKind? = nil
    @State private var originFilter: CapabilityOrigin? = nil
    @State private var query: String = ""
    @State private var batchMode: Bool = false
    @State private var batchSelection: Set<CapabilityRef> = []
    @State private var grouping: GroupKey = .none

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Filter…", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("Kind", selection: $kindFilter) {
                    Text("All").tag(CapabilityKind?.none)
                    ForEach(CapabilityKind.allCases, id: \.self) { kind in
                        Text(label(for: kind)).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                Picker("Group", selection: $grouping) {
                    ForEach(GroupKey.allCases, id: \.self) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 110)
                Toggle(isOn: $batchMode) { Text("Select") }
                    .toggleStyle(.button)
                    .onChange(of: batchMode) { _, newValue in
                        if !newValue { batchSelection.removeAll() }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            OriginFilterBar(selected: $originFilter, availableOrigins: availableOrigins)

            if batchMode {
                BatchActionsBar(
                    selection: $batchSelection,
                    visibleRefs: filteredRefs,
                    mode: .global,
                    onApply: applyBatch
                )
            }

            List(selection: bindingSelection()) {
                if grouping == .none {
                    ForEach(filteredRefs, id: \.self) { ref in
                        CapabilityRow(
                            ref: ref,
                            projectID: nil,
                            batchSelection: batchMode ? $batchSelection : nil
                        )
                        .tag(ref)
                    }
                } else {
                    ForEach(groupedRefs(filteredRefs, by: grouping, registry: registry), id: \.label) { group in
                        Section {
                            ForEach(group.refs, id: \.self) { ref in
                                CapabilityRow(
                                    ref: ref,
                                    projectID: nil,
                                    batchSelection: batchMode ? $batchSelection : nil
                                )
                                .tag(ref)
                            }
                        } header: {
                            globalGroupHeader(label: group.label, refs: group.refs)
                        }
                    }
                }
            }
        }
        .navigationTitle("Global Capabilities")
    }

    private func globalGroupHeader(label: String, refs: [CapabilityRef]) -> some View {
        HStack {
            Text(label).font(.subheadline).bold()
            Text("(\(refs.count))").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu("Apply to group") {
                Button("Enable all") { applyGroup(refs, enabled: true) }
                Button("Disable all") { applyGroup(refs, enabled: false) }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func applyGroup(_ refs: [CapabilityRef], enabled: Bool) {
        for ref in refs { registry.setGlobal(ref, enabled: enabled) }
        env.saveSoon()
    }

    private func applyBatch(_ action: BatchAction) {
        for ref in batchSelection {
            switch action {
            case .globalEnable: registry.setGlobal(ref, enabled: true)
            case .globalDisable: registry.setGlobal(ref, enabled: false)
            case .override(let value):
                _ = value // not used in global
            }
        }
        env.saveSoon()
        batchSelection.removeAll()
    }

    private var availableOrigins: [CapabilityOrigin] {
        let used = Set(registry.allRefs.compactMap { registry.origin(for: $0) })
        return CapabilityOrigin.allCases.filter { used.contains($0) }
    }

    private func bindingSelection() -> Binding<CapabilityRef?> {
        Binding(
            get: {
                if case .capability(let ref) = env.contentSelection { return ref }
                return nil
            },
            set: { newValue in
                env.contentSelection = newValue.map(ContentSelection.capability)
            }
        )
    }

    private var filteredRefs: [CapabilityRef] {
        registry.allRefs
            .filter { kindFilter == nil || $0.kind == kindFilter }
            .filter { originFilter == nil || registry.origin(for: $0) == originFilter }
            .filter {
                guard !query.isEmpty else { return true }
                return registry.displayName(for: $0).localizedCaseInsensitiveContains(query)
            }
            .sorted { registry.displayName(for: $0)
                .localizedCaseInsensitiveCompare(registry.displayName(for: $1)) == .orderedAscending
            }
    }

    private func label(for kind: CapabilityKind) -> String {
        switch kind {
        case .skill: return "Skills"
        case .plugin: return "Plugins"
        case .connector: return "Connectors"
        case .mcpServer: return "MCP Servers"
        }
    }
}

/// Reusable row used for both global and per-project lists.
struct CapabilityRow: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore
    @EnvironmentObject private var projectsStore: ProjectsStore

    let ref: CapabilityRef
    let projectID: UUID?
    var batchSelection: Binding<Set<CapabilityRef>>? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let batchSelection {
                Toggle("", isOn: Binding(
                    get: { batchSelection.wrappedValue.contains(ref) },
                    set: { isOn in
                        if isOn { batchSelection.wrappedValue.insert(ref) }
                        else { batchSelection.wrappedValue.remove(ref) }
                    }
                ))
                .labelsHidden()
            }
            Image(systemName: icon(for: ref.kind))
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(registry.displayName(for: ref))
                        .font(.body)
                    if let origin = registry.origin(for: ref) {
                        OriginBadge(origin: origin)
                    }
                }
                Text(secondary(for: ref))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let projectID {
                projectControls(projectID: projectID)
            } else {
                Toggle("", isOn: globalBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
        .contentShape(Rectangle())
    }

    private var globalBinding: Binding<Bool> {
        Binding(
            get: { registry.isGloballyEnabled(ref) },
            set: { newValue in
                registry.setGlobal(ref, enabled: newValue)
                env.saveSoon()
            }
        )
    }

    private func projectControls(projectID: UUID) -> some View {
        let override = projectsStore.override(projectID: projectID, ref: ref)
        let global = registry.isGloballyEnabled(ref)
        let effective = projectsStore.effectiveState(projectID: projectID, ref: ref, global: global)

        return HStack(spacing: 8) {
            Text(override == .inherit ? "Inherited" : "Overridden")
                .font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(override == .inherit ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(0.2))
                .clipShape(Capsule())

            Picker("", selection: Binding(
                get: { override },
                set: { newValue in
                    projectsStore.setOverride(projectID: projectID, ref: ref, value: newValue)
                    env.saveSoon()
                }
            )) {
                Text("Inherit").tag(CapabilityScopeOverride.inherit)
                Text("Enabled").tag(CapabilityScopeOverride.enabled)
                Text("Disabled").tag(CapabilityScopeOverride.disabled)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 110)

            Image(systemName: effective ? "checkmark.circle.fill" : "circle.slash")
                .foregroundStyle(effective ? .green : .secondary)
        }
    }

    private func icon(for kind: CapabilityKind) -> String {
        switch kind {
        case .skill: return "lightbulb"
        case .plugin: return "puzzlepiece.extension"
        case .connector: return "link"
        case .mcpServer: return "server.rack"
        }
    }

    private func secondary(for ref: CapabilityRef) -> String {
        switch ref.kind {
        case .skill:
            return registry.skill(for: ref)?.summary ?? ""
        case .plugin:
            let p = registry.plugin(for: ref)
            return p?.summary ?? p?.rootDirectory.path ?? ""
        case .connector:
            return registry.connector(for: ref)?.serviceType ?? ""
        case .mcpServer:
            return registry.mcpServer(for: ref)?.transportSummary ?? ""
        }
    }
}

enum GroupKey: String, CaseIterable, Hashable {
    case none
    case source
    case domain

    var label: String {
        switch self {
        case .none: return "Flat"
        case .source: return "Source"
        case .domain: return "Domain"
        }
    }
}

@MainActor
func groupedRefs(
    _ refs: [CapabilityRef],
    by key: GroupKey,
    registry: RegistryStore
) -> [(label: String, refs: [CapabilityRef])] {
    switch key {
    case .none:
        return [("All", refs)]
    case .source:
        let dict = Dictionary(grouping: refs) { ref in
            registry.origin(for: ref)?.displayLabel ?? "Other"
        }
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    case .domain:
        let dict = Dictionary(grouping: refs) { registry.domain(for: $0) }
        return dict.keys.sorted().map { ($0, dict[$0] ?? []) }
    }
}

enum BatchAction: Hashable {
    case globalEnable
    case globalDisable
    case override(CapabilityScopeOverride)
}

enum BatchBarMode {
    case global
    case project
}

struct BatchActionsBar: View {
    @Binding var selection: Set<CapabilityRef>
    let visibleRefs: [CapabilityRef]
    let mode: BatchBarMode
    let onApply: (BatchAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(selection.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Select All") {
                selection.formUnion(visibleRefs)
            }
            .disabled(visibleRefs.isEmpty)

            Button("Clear") { selection.removeAll() }
                .disabled(selection.isEmpty)

            Spacer()

            switch mode {
            case .global:
                Menu("Apply") {
                    Button("Enable") { onApply(.globalEnable) }
                    Button("Disable") { onApply(.globalDisable) }
                }
                .disabled(selection.isEmpty)
                .frame(width: 100)
            case .project:
                Menu("Apply") {
                    Button("Inherit") { onApply(.override(.inherit)) }
                    Button("Enabled") { onApply(.override(.enabled)) }
                    Button("Disabled") { onApply(.override(.disabled)) }
                }
                .disabled(selection.isEmpty)
                .frame(width: 100)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
    }
}
