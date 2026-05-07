import SwiftUI
import AppKit

struct ProjectsListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var projectsStore: ProjectsStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    env.discoverInBackground()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                Spacer()
                Button {
                    pickFolderAndAdd()
                } label: {
                    Label("Add Folder…", systemImage: "plus")
                }
            }
            .padding(8)

            List(selection: bindingSelection()) {
                Section("Managed") {
                    ForEach(projectsStore.orderedProjects, id: \.id) { project in
                        ProjectRow(project: project)
                            .tag(ContentSelection.project(project.id))
                    }
                }

                if !projectsStore.discovered.isEmpty {
                    Section("Discovered") {
                        ForEach(projectsStore.discovered, id: \.rootPath) { candidate in
                            DiscoveredRow(candidate: candidate)
                                .tag(ContentSelection.discoveredProject(candidate.rootPath))
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
    }

    private func bindingSelection() -> Binding<ContentSelection?> {
        Binding(
            get: { env.contentSelection },
            set: { newValue in
                DispatchQueue.main.async { env.contentSelection = newValue }
            }
        )
    }

    private func pickFolderAndAdd() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                if let candidate = await env.discovery.inspect(folder: url) {
                    projectsStore.addOrUpdate(candidate)
                    env.contentSelection = .project(candidate.id)
                    env.saveSoon()
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(project.name).font(.body)
            Text(project.rootPath.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct DiscoveredRow: View {
    let candidate: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(candidate.name).font(.body)
            Text(candidate.detectedMarkers.joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
