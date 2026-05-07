import SwiftUI

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $env.sidebar)
                .frame(minWidth: 220)
        } content: {
            ContentColumn()
                .frame(minWidth: 320)
        } detail: {
            DetailColumn()
                .frame(minWidth: 460)
        }
        .navigationTitle("Agent Capability Manager")
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection

    var body: some View {
        List(selection: $selection) {
            Section("Workspace") {
                row(.projects)
                row(.global)
            }
            Section("Sources") {
                row(.claudeCode)
                row(.claudeDesktop)
            }
            Section("Capabilities") {
                row(.mcpServers)
                row(.marketplace)
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ section: SidebarSection) -> some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.systemImage)
                .foregroundStyle(tint(section))
        }
    }

    private func tint(_ section: SidebarSection) -> Color {
        switch section {
        case .claudeCode: return CapabilityOrigin.claudeHome.tint
        case .claudeDesktop: return CapabilityOrigin.claudeDesktop.tint
        default: return .primary
        }
    }
}

struct ContentColumn: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        switch env.sidebar {
        case .projects: ProjectsListView()
        case .global: GlobalCapabilitiesListView()
        case .claudeCode: SourceScopedCapabilitiesView(origin: .claudeHome)
        case .claudeDesktop: ClaudeDesktopSourceView()
        case .marketplace: MarketplaceView()
        case .mcpServers: MCPServersListView()
        }
    }
}

struct DetailColumn: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        switch env.contentSelection {
        case .capability(let ref):
            CapabilityDetailView(ref: ref)
        case .project(let id):
            ProjectDetailView(projectID: id)
        case .discoveredProject(let path):
            DiscoveredProjectDetailView(rootPath: path)
        case .marketplaceItem(let id):
            MarketplaceDetailView(itemID: id)
        case .mcpServer(let id):
            MCPServerDetailView(serverID: id)
        case .none:
            ContentUnavailableView("Select an item",
                systemImage: "sidebar.right",
                description: Text("Pick a section in the sidebar, then choose an item to inspect.")
            )
        }
    }
}
