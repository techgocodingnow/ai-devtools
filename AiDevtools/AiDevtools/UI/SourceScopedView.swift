import SwiftUI
import AppKit

/// Lists every capability registered with a specific origin (e.g. all `claudeHome` items).
struct SourceScopedCapabilitiesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore
    let origin: CapabilityOrigin

    @State private var query: String = ""
    @State private var kindFilter: CapabilityKind? = nil
    @State private var batchMode: Bool = false
    @State private var batchSelection: Set<CapabilityRef> = []

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 8) {
                TextField("Filter…", text: $query).textFieldStyle(.roundedBorder)
                Picker("Kind", selection: $kindFilter) {
                    Text("All").tag(CapabilityKind?.none)
                    ForEach(CapabilityKind.allCases, id: \.self) { kind in
                        Text(label(for: kind)).tag(Optional(kind))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                Toggle(isOn: $batchMode) { Text("Select") }
                    .toggleStyle(.button)
                    .onChange(of: batchMode) { _, newValue in
                        if !newValue { batchSelection.removeAll() }
                    }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            if batchMode {
                BatchActionsBar(
                    selection: $batchSelection,
                    visibleRefs: filteredRefs,
                    mode: .global,
                    onApply: applyBatch
                )
            }

            List(selection: bindingSelection()) {
                if filteredRefs.isEmpty {
                    Text("Nothing imported from \(origin.displayLabel) yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredRefs, id: \.self) { ref in
                    CapabilityRow(
                        ref: ref,
                        projectID: nil,
                        batchSelection: batchMode ? $batchSelection : nil
                    )
                    .tag(ref)
                }
            }
        }
        .navigationTitle(origin.displayLabel)
    }

    private func applyBatch(_ action: BatchAction) {
        for ref in batchSelection {
            switch action {
            case .globalEnable: registry.setGlobal(ref, enabled: true)
            case .globalDisable: registry.setGlobal(ref, enabled: false)
            case .override: break
            }
        }
        env.saveSoon()
        batchSelection.removeAll()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: origin.systemImage)
                .font(.title2)
                .foregroundStyle(origin.tint)
                .frame(width: 36, height: 36)
                .background(origin.tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(origin.displayLabel).font(.title3).bold()
                Text(originSubtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                env.importClaudeHome()
                env.saveSoon()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
        }
        .padding(12)
        .background(origin.tint.opacity(0.06))
    }

    private var originSubtitle: String {
        switch origin {
        case .claudeHome: return "~/.claude/skills + plugins + ~/.claude/.mcp.json"
        case .claudeDesktop: return "~/Library/Application Support/Claude/claude_desktop_config.json"
        case .plugin: return "Bundled by installed plugins"
        case .manual: return "Added manually in this app"
        }
    }

    private var filteredRefs: [CapabilityRef] {
        registry.allRefs
            .filter { registry.origin(for: $0) == origin }
            .filter { kindFilter == nil || $0.kind == kindFilter }
            .filter {
                guard !query.isEmpty else { return true }
                return registry.displayName(for: $0).localizedCaseInsensitiveContains(query)
            }
            .sorted {
                registry.displayName(for: $0)
                    .localizedCaseInsensitiveCompare(registry.displayName(for: $1)) == .orderedAscending
            }
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

    private func label(for kind: CapabilityKind) -> String {
        switch kind {
        case .skill: return "Skills"
        case .plugin: return "Plugins"
        case .connector: return "Connectors"
        case .mcpServer: return "MCP"
        }
    }
}

/// Dedicated Claude Desktop view: shows the config file location, sync controls, raw JSON peek.
struct ClaudeDesktopSourceView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore

    @State private var query: String = ""
    @State private var syncMessage: String?

    private let origin: CapabilityOrigin = .claudeDesktop

    var body: some View {
        VStack(spacing: 0) {
            header

            if let syncMessage {
                Text(syncMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.bottom, 4)
            }

            HStack {
                TextField("Filter servers…", text: $query).textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            List(selection: bindingSelection()) {
                if filteredServers.isEmpty {
                    if env.claudeDesktop.fileExists {
                        Text("No MCP servers defined in `claude_desktop_config.json`.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("`claude_desktop_config.json` not found.")
                            Text(env.claudeDesktop.configURL.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                ForEach(filteredServers) { server in
                    serverRow(server)
                        .tag(ContentSelection.mcpServer(server.id))
                }
            }
        }
        .navigationTitle("Claude Desktop")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: origin.systemImage)
                    .font(.title2)
                    .foregroundStyle(origin.tint)
                    .frame(width: 36, height: 36)
                    .background(origin.tint.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude Desktop").font(.title3).bold()
                    Text(env.claudeDesktop.configURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    revealInFinder()
                } label: {
                    Label("Reveal", systemImage: "magnifyingglass")
                }
                Button {
                    sync()
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        .padding(12)
        .background(origin.tint.opacity(0.06))
    }

    private func serverRow(_ server: MCPServer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.label).font(.body)
                    transportBadge(stdio: server.isStdio)
                }
                Text(server.transportSummary)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { registry.isGloballyEnabled(server.ref) },
                set: { newValue in
                    registry.setGlobal(server.ref, enabled: newValue)
                    env.saveSoon()
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }

    private func transportBadge(stdio: Bool) -> some View {
        let label = stdio ? "stdio" : "http"
        let tint: Color = stdio ? .orange : .blue
        return Text(label)
            .font(.caption2)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(tint.opacity(0.18))
            .clipShape(Capsule())
    }

    private var filteredServers: [MCPServer] {
        registry.mcpServers.values
            .filter { $0.origin == .claudeDesktop }
            .filter {
                guard !query.isEmpty else { return true }
                return $0.label.localizedCaseInsensitiveContains(query)
                    || $0.transportSummary.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func bindingSelection() -> Binding<ContentSelection?> {
        Binding(
            get: { env.contentSelection },
            set: { newValue in
                Task { @MainActor in env.contentSelection = newValue }
            }
        )
    }

    private func sync() {
        env.importClaudeDesktopMCP()
        env.saveSoon()
        syncMessage = "Reloaded at \(Date().formatted(date: .omitted, time: .standard))"
    }

    private func revealInFinder() {
        let url = env.claudeDesktop.configURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
        }
    }
}
