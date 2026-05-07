import SwiftUI

struct MCPServersListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore
    @State private var showAdd = false
    @State private var addOriginIsClaudeDesktop = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    env.importClaudeDesktopMCP()
                    env.saveSoon()
                } label: {
                    Label("Sync Claude Desktop", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Reload \(env.claudeDesktop.configURL.path)")
                Spacer()
                Button {
                    addOriginIsClaudeDesktop = false
                    showAdd = true
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                Menu {
                    Button("Add to Claude Desktop config") {
                        addOriginIsClaudeDesktop = true
                        showAdd = true
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 26)
            }
            .padding(8)

            if let importError {
                Text(importError).font(.caption).foregroundStyle(.red).padding(.horizontal, 8)
            }

            List(selection: bindingSelection()) {
                ForEach(MCPOrigin.allOriginsInUse(in: registry.mcpServers), id: \.self) { origin in
                    Section(originHeader(origin)) {
                        ForEach(serversFor(origin)) { server in
                            row(for: server)
                                .tag(ContentSelection.mcpServer(server.id))
                        }
                    }
                }
                if registry.mcpServers.isEmpty {
                    Text("No MCP servers configured.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("MCP / Connectors")
        .sheet(isPresented: $showAdd) {
            EditMCPServerSheet(
                server: nil,
                forceOrigin: addOriginIsClaudeDesktop ? .claudeDesktop : nil
            ) { newServer in
                registry.upsert(newServer)
                registry.setGlobal(newServer.ref, enabled: newServer.isGlobal)
                env.saveSoon()
                if newServer.origin == .claudeDesktop {
                    do { try env.saveClaudeDesktopMCP() }
                    catch { importError = "Save failed: \(error.localizedDescription)" }
                }
            }
        }
    }

    private func row(for server: MCPServer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.label).font(.body)
                    if server.isStdio {
                        badge("stdio", color: .orange)
                    } else {
                        badge("http", color: .blue)
                    }
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

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(color.opacity(0.18))
            .clipShape(Capsule())
    }

    private func originHeader(_ origin: MCPOrigin) -> String {
        switch origin {
        case .manual: return "Manual"
        case .claudeHome: return "Claude Code (~/.claude)"
        case .claudeDesktop: return "Claude Desktop"
        case .plugin: return "Plugins"
        }
    }

    private func serversFor(_ origin: MCPOrigin) -> [MCPServer] {
        registry.mcpServers.values
            .filter { $0.origin == origin }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func bindingSelection() -> Binding<ContentSelection?> {
        Binding(
            get: { env.contentSelection },
            set: { newValue in
                Task { @MainActor in
                    env.contentSelection = newValue
                }
            }
        )
    }
}

private extension MCPOrigin {
    static func allOriginsInUse(in servers: [UUID: MCPServer]) -> [MCPOrigin] {
        let used = Set(servers.values.map(\.origin))
        return [.claudeDesktop, .claudeHome, .plugin, .manual].filter { used.contains($0) }
    }
}

struct MCPServerDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @EnvironmentObject private var registry: RegistryStore
    let serverID: UUID

    @State private var showEdit = false
    @State private var testStatus: String = ""
    @State private var testing = false
    @State private var saveError: String?

    var body: some View {
        if let server = registry.mcpServers[serverID] {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(server.label).font(.title2).bold()
                        Text(server.transportSummary)
                            .font(.callout).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button("Edit") { showEdit = true }
                    Button(role: .destructive) {
                        let wasClaudeDesktop = server.origin == .claudeDesktop
                        registry.mcpServers.removeValue(forKey: server.id)
                        env.contentSelection = nil
                        env.saveSoon()
                        if wasClaudeDesktop {
                            do { try env.saveClaudeDesktopMCP() }
                            catch { saveError = error.localizedDescription }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                LabeledContent("Origin") { Text(originLabel(server.origin)) }
                LabeledContent("Transport") { Text(server.isStdio ? "stdio" : "http") }
                if !server.description.isEmpty {
                    LabeledContent("Description") { Text(server.description) }
                }
                LabeledContent("Auth") { Text(server.authType ?? "—") }
                if !server.env.isEmpty {
                    Divider()
                    Text("Environment").font(.headline)
                    ForEach(server.env.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                        HStack {
                            Text(entry.key).font(.system(.caption, design: .monospaced))
                            Spacer()
                            Text(entry.value)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                }

                if let url = server.serverURL {
                    HStack {
                        Button {
                            Task { await testConnection(url: url) }
                        } label: {
                            if testing { ProgressView().controlSize(.small) }
                            else { Label("Test connection", systemImage: "wifi") }
                        }
                        Text(testStatus).font(.callout).foregroundStyle(.secondary)
                    }
                }

                if let saveError {
                    Text(saveError).font(.caption).foregroundStyle(.red)
                }
                Spacer()
            }
            .padding()
            .sheet(isPresented: $showEdit) {
                EditMCPServerSheet(server: server, forceOrigin: nil) { updated in
                    registry.upsert(updated)
                    env.saveSoon()
                    if updated.origin == .claudeDesktop {
                        do { try env.saveClaudeDesktopMCP() }
                        catch { saveError = error.localizedDescription }
                    }
                }
            }
        } else {
            ContentUnavailableView("Server removed", systemImage: "questionmark")
        }
    }

    private func testConnection(url: URL) async {
        testing = true
        defer { testing = false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                testStatus = "HTTP \(http.statusCode)"
            } else {
                testStatus = "Reachable"
            }
        } catch {
            testStatus = "Failed: \(error.localizedDescription)"
        }
    }

    private func originLabel(_ origin: MCPOrigin) -> String {
        switch origin {
        case .manual: return "Manual"
        case .claudeHome: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        case .plugin: return "Plugin-bundled"
        }
    }
}

private struct EditMCPServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let server: MCPServer?
    let forceOrigin: MCPOrigin?
    let onSave: (MCPServer) -> Void

    @State private var label: String = ""
    @State private var transport: TransportKind = .http
    @State private var urlString: String = ""
    @State private var command: String = ""
    @State private var argsString: String = ""
    @State private var envEntries: [EnvEntry] = []
    @State private var description: String = ""
    @State private var authType: String = ""
    @State private var isGlobal: Bool = true
    @State private var origin: MCPOrigin = .manual
    @State private var error: String?
    @FocusState private var focusedEnvField: EnvFieldFocus?

    private enum TransportKind: String, CaseIterable, Identifiable {
        case http, stdio
        var id: String { rawValue }
    }

    private struct EnvEntry: Identifiable, Equatable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }

    private struct EnvFieldFocus: Hashable {
        let id: UUID
        let isKey: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(server == nil ? "Add MCP Server" : "Edit MCP Server")
                .font(.title3).bold()
                .padding(.horizontal, 16).padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field(label: "Label") {
                        TextField("e.g. perplexity", text: $label).textFieldStyle(.roundedBorder)
                    }

                    field(label: "Transport") {
                        Picker("", selection: $transport) {
                            Text("HTTP").tag(TransportKind.http)
                            Text("Stdio (command)").tag(TransportKind.stdio)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    if transport == .http {
                        field(label: "URL") {
                            TextField("https://…", text: $urlString).textFieldStyle(.roundedBorder)
                        }
                        field(label: "Auth type") {
                            TextField("bearer / oauth / none", text: $authType).textFieldStyle(.roundedBorder)
                        }
                    } else {
                        field(label: "Command") {
                            TextField("e.g. npx, node", text: $command).textFieldStyle(.roundedBorder)
                        }
                        field(label: "Args") {
                            TextField("space-separated", text: $argsString).textFieldStyle(.roundedBorder)
                        }
                    }

                    field(label: "Description") {
                        TextField("optional", text: $description).textFieldStyle(.roundedBorder)
                    }

                    envSection

                    field(label: "Origin") {
                        Picker("", selection: $origin) {
                            Text("Manual").tag(MCPOrigin.manual)
                            Text("Claude Desktop").tag(MCPOrigin.claudeDesktop)
                            Text("Claude Code (~/.claude)").tag(MCPOrigin.claudeHome)
                        }
                        .labelsHidden()
                        .disabled(forceOrigin != nil)
                    }

                    Toggle("Enabled globally by default", isOn: $isGlobal)
                        .padding(.top, 4)

                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }
                .padding(16)
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(minWidth: 580, minHeight: 520)
        .onAppear { populate() }
    }

    private func field<V: View>(label: String, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private var envSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Environment").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    addEnvRow()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Add environment variable")
            }

            if envEntries.isEmpty {
                Text("No environment variables.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach($envEntries) { $entry in
                        HStack(spacing: 6) {
                            TextField("KEY", text: $entry.key)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: 200)
                                .focused($focusedEnvField, equals: EnvFieldFocus(id: entry.id, isKey: true))
                                .onSubmit {
                                    focusedEnvField = EnvFieldFocus(id: entry.id, isKey: false)
                                }
                            Text("=").foregroundStyle(.secondary)
                            TextField("value", text: $entry.value)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .focused($focusedEnvField, equals: EnvFieldFocus(id: entry.id, isKey: false))
                                .onSubmit { addEnvRow() }
                            Button {
                                envEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove")
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func addEnvRow() {
        let entry = EnvEntry()
        envEntries.append(entry)
        DispatchQueue.main.async {
            focusedEnvField = EnvFieldFocus(id: entry.id, isKey: true)
        }
    }

    private func populate() {
        if let server {
            label = server.label
            transport = server.isStdio ? .stdio : .http
            urlString = server.serverURL?.absoluteString ?? ""
            command = server.command ?? ""
            argsString = server.args.joined(separator: " ")
            envEntries = server.env
                .sorted(by: { $0.key < $1.key })
                .map { EnvEntry(key: $0.key, value: $0.value) }
            description = server.description
            authType = server.authType ?? ""
            isGlobal = server.isGlobal
            origin = server.origin
        }
        if let forceOrigin {
            origin = forceOrigin
        }
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            error = "Label is required"
            return
        }

        var url: URL? = nil
        var cmd: String? = nil
        var args: [String] = []

        switch transport {
        case .http:
            guard let parsed = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
                  parsed.scheme != nil
            else {
                error = "Invalid URL"
                return
            }
            url = parsed
        case .stdio:
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                error = "Command is required for stdio transport"
                return
            }
            cmd = trimmed
            args = argsString
                .split(separator: " ")
                .map { String($0) }
        }

        var env: [String: String] = [:]
        for entry in envEntries {
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            env[key] = entry.value
        }

        let normalizedAuth = authType.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = MCPServer(
            id: server?.id ?? UUID(),
            label: trimmedLabel,
            serverURL: url,
            command: cmd,
            args: args,
            env: env,
            description: description,
            authType: normalizedAuth.isEmpty ? nil : normalizedAuth,
            isGlobal: isGlobal,
            origin: origin
        )
        onSave(updated)
        dismiss()
    }
}
