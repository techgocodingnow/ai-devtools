import SwiftUI

struct CapabilityDetailView: View {
    @EnvironmentObject private var registry: RegistryStore
    let ref: CapabilityRef

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch ref.kind {
                case .skill:
                    if let skill = registry.skill(for: ref) { skillView(skill) }
                    else { ContentUnavailableView("Skill missing", systemImage: "lightbulb.slash") }
                case .plugin:
                    if let plugin = registry.plugin(for: ref) { pluginView(plugin) }
                    else { ContentUnavailableView("Plugin missing", systemImage: "puzzlepiece.extension") }
                case .connector:
                    if let connector = registry.connector(for: ref) { connectorView(connector) }
                    else { ContentUnavailableView("Connector missing", systemImage: "link") }
                case .mcpServer:
                    if let mcp = registry.mcpServer(for: ref) { mcpView(mcp) }
                    else { ContentUnavailableView("MCP server missing", systemImage: "server.rack") }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func skillView(_ skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(skill.name).font(.title2).bold()
            if !skill.summary.isEmpty { Text(skill.summary).foregroundStyle(.secondary) }
            LabeledContent("Location") { Text(skill.location.path).textSelection(.enabled) }
            LabeledContent("SKILL.md") { Text(skill.skillFile.path).textSelection(.enabled) }
            if let pluginID = skill.pluginID, let plugin = registry.plugins[pluginID] {
                LabeledContent("Owner plugin") { Text(plugin.name) }
            }
            if let body = try? String(contentsOf: skill.skillFile, encoding: .utf8), !body.isEmpty {
                Divider()
                Text("Contents").font(.headline)
                Text(body)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func pluginView(_ plugin: Plugin) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plugin.name).font(.title2).bold()
            if !plugin.summary.isEmpty { Text(plugin.summary).foregroundStyle(.secondary) }
            if let v = plugin.version { LabeledContent("Version") { Text(v) } }
            LabeledContent("Root") { Text(plugin.rootDirectory.path).textSelection(.enabled) }
            if !plugin.skillIDs.isEmpty {
                Divider()
                Text("Skills").font(.headline)
                ForEach(plugin.skillIDs, id: \.self) { sid in
                    if let skill = registry.skills[sid] { Text("• \(skill.name)") }
                }
            }
            if !plugin.mcpServerIDs.isEmpty {
                Divider()
                Text("MCP Servers").font(.headline)
                ForEach(plugin.mcpServerIDs, id: \.self) { mid in
                    if let m = registry.mcpServers[mid] { Text("• \(m.label) — \(m.transportSummary)") }
                }
            }
        }
    }

    private func connectorView(_ connector: Connector) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(connector.name).font(.title2).bold()
            LabeledContent("Service") { Text(connector.serviceType) }
            if let mid = connector.backingMCPServerID, let m = registry.mcpServers[mid] {
                LabeledContent("Backing MCP") { Text(m.label) }
            }
            LabeledContent("Global default") { Text(connector.isGlobal ? "Enabled" : "Disabled") }
        }
    }

    private func mcpView(_ mcp: MCPServer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mcp.label).font(.title2).bold()
            LabeledContent("Transport") { Text(mcp.isStdio ? "stdio" : "http") }
            LabeledContent(mcp.isStdio ? "Command" : "URL") {
                Text(mcp.transportSummary).textSelection(.enabled)
            }
            if !mcp.description.isEmpty { Text(mcp.description) }
            LabeledContent("Auth") { Text(mcp.authType ?? "—") }
            LabeledContent("Origin") { Text(mcp.origin.rawValue) }
        }
    }
}
