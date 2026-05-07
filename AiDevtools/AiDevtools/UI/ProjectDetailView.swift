import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore
    @EnvironmentObject private var projectsStore: ProjectsStore

    let projectID: UUID
    @State private var tab: CapabilityKind = .skill
    @State private var showingExport = false
    @State private var batchMode: Bool = false
    @State private var batchSelection: Set<CapabilityRef> = []
    @State private var grouping: GroupKey = .none

    var body: some View {
        if let project = projectsStore.projects[projectID] {
            VStack(alignment: .leading, spacing: 0) {
                header(for: project)
                Divider()

                HStack {
                    Picker("", selection: $tab) {
                        Text("Skills").tag(CapabilityKind.skill)
                        Text("Plugins").tag(CapabilityKind.plugin)
                        Text("Connectors").tag(CapabilityKind.connector)
                        Text("MCP").tag(CapabilityKind.mcpServer)
                    }
                    .pickerStyle(.segmented)

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
                        .onChange(of: tab) { _, _ in
                            batchSelection.removeAll()
                        }
                }
                .padding(8)

                if batchMode {
                    BatchActionsBar(
                        selection: $batchSelection,
                        visibleRefs: refs(for: tab),
                        mode: .project,
                        onApply: applyBatch
                    )
                }

                List {
                    let all = refs(for: tab)
                    if all.isEmpty {
                        Text("No \(label(for: tab)) registered yet.")
                            .foregroundStyle(.secondary)
                    } else if grouping == .none {
                        ForEach(all, id: \.self) { ref in
                            CapabilityRow(
                                ref: ref,
                                projectID: project.id,
                                batchSelection: batchMode ? $batchSelection : nil
                            )
                        }
                    } else {
                        ForEach(groupedRefs(all, by: grouping, registry: registry), id: \.label) { group in
                            Section {
                                ForEach(group.refs, id: \.self) { ref in
                                    CapabilityRow(
                                        ref: ref,
                                        projectID: project.id,
                                        batchSelection: batchMode ? $batchSelection : nil
                                    )
                                }
                            } header: {
                                groupHeader(label: group.label, refs: group.refs, project: project)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExport) {
                AgentExportSheet(projectID: project.id)
            }
        } else {
            ContentUnavailableView("Project not found", systemImage: "questionmark.folder")
        }
    }

    private func applyBatch(_ action: BatchAction) {
        if case .override(let value) = action {
            for ref in batchSelection {
                projectsStore.setOverride(projectID: projectID, ref: ref, value: value)
            }
            env.saveSoon()
        }
        batchSelection.removeAll()
    }

    private func applyGroup(_ value: CapabilityScopeOverride, refs: [CapabilityRef]) {
        for ref in refs {
            projectsStore.setOverride(projectID: projectID, ref: ref, value: value)
        }
        env.saveSoon()
    }

    private func groupHeader(label: String, refs: [CapabilityRef], project: Project) -> some View {
        HStack {
            Text(label).font(.subheadline).bold()
            Text("(\(refs.count))").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu("Apply to group") {
                Button("Inherit") { applyGroup(.inherit, refs: refs) }
                Button("Enabled") { applyGroup(.enabled, refs: refs) }
                Button("Disabled") { applyGroup(.disabled, refs: refs) }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func header(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name).font(.title2).bold()
                    Text(project.rootPath.path)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                Button("Export Agent Config") { showingExport = true }
                Button(role: .destructive) {
                    projectsStore.remove(project.id)
                    env.contentSelection = nil
                    env.saveSoon()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
            if !project.detectedMarkers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(project.detectedMarkers, id: \.self) { marker in
                        Text(marker)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
    }

    private func refs(for kind: CapabilityKind) -> [CapabilityRef] {
        registry.allRefs
            .filter { $0.kind == kind }
            .sorted {
                registry.displayName(for: $0)
                    .localizedCaseInsensitiveCompare(registry.displayName(for: $1)) == .orderedAscending
            }
    }

    private func label(for kind: CapabilityKind) -> String {
        switch kind {
        case .skill: return "skills"
        case .plugin: return "plugins"
        case .connector: return "connectors"
        case .mcpServer: return "MCP servers"
        }
    }
}

struct DiscoveredProjectDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var projectsStore: ProjectsStore
    let rootPath: URL

    var body: some View {
        if let candidate = projectsStore.discovered.first(where: { $0.rootPath == rootPath }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(candidate.name).font(.title2).bold()
                Text(candidate.rootPath.path).foregroundStyle(.secondary).textSelection(.enabled)
                if !candidate.detectedMarkers.isEmpty {
                    Text("Markers detected:")
                    ForEach(candidate.detectedMarkers, id: \.self) { Text("• \($0)").font(.callout) }
                }
                Button("Add as Managed Project") {
                    projectsStore.promoteDiscovered(candidate)
                    env.contentSelection = .project(candidate.id)
                    env.saveSoon()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
        } else {
            ContentUnavailableView("Candidate no longer available", systemImage: "questionmark.folder")
        }
    }
}

private struct AgentExportSheet: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID

    @State private var preview: String = "Loading…"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent Session Config").font(.title3).bold()
            ScrollView {
                Text(preview)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 480)
        .onAppear {
            let exporter = AgentConfigExporter(registry: env.registry, projects: env.projects)
            preview = (try? exporter.makeJSONPreview(agent: env.defaultAgent, projectID: projectID))
                ?? "Failed to render."
        }
    }
}
