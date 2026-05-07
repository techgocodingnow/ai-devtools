import Foundation

/// Builds an `AgentSessionConfig` from the current registry + projects state.
///
/// V1 keeps the structure ready for a future Claude client integration but only
/// produces a JSON-serializable object today.
@MainActor
public struct AgentConfigExporter {
    public let registry: RegistryStore
    public let projects: ProjectsStore
    private let fileManager: FileManager

    public init(registry: RegistryStore, projects: ProjectsStore, fileManager: FileManager = .default) {
        self.registry = registry
        self.projects = projects
        self.fileManager = fileManager
    }

    public func effectiveCapabilities(forProject projectID: UUID) -> [CapabilityRef] {
        registry.allRefs.filter { ref in
            let global = registry.isGloballyEnabled(ref)
            return projects.effectiveState(projectID: projectID, ref: ref, global: global)
        }
    }

    public func makeSessionConfig(agent: Agent, projectID: UUID) -> AgentSessionConfig {
        let refs = effectiveCapabilities(forProject: projectID)

        var skillConfigs: [AgentSessionConfig.SkillConfig] = []
        var toolConfigs: [AgentSessionConfig.ToolConfig] = []
        var systemPromptParts: [String] = []

        for ref in refs {
            switch ref.kind {
            case .skill:
                guard let skill = registry.skill(for: ref) else { continue }
                let body = (try? String(contentsOf: skill.skillFile, encoding: .utf8)) ?? skill.summary
                skillConfigs.append(.init(id: skill.id, name: skill.name, instructions: body))
                systemPromptParts.append("## Skill: \(skill.name)\n\n\(body)")
            case .plugin:
                // Plugin-level skills are aggregated via their child skill IDs (already in registry).
                continue
            case .connector:
                guard let connector = registry.connector(for: ref) else { continue }
                let endpoint = connector.backingMCPServerID
                    .flatMap { registry.mcpServers[$0]?.serverURL }
                toolConfigs.append(.init(
                    id: connector.id,
                    kind: .connector,
                    label: connector.name,
                    endpoint: endpoint
                ))
            case .mcpServer:
                guard let mcp = registry.mcpServer(for: ref) else { continue }
                toolConfigs.append(.init(
                    id: mcp.id,
                    kind: .mcpServer,
                    label: mcp.label,
                    endpoint: mcp.serverURL,
                    authType: mcp.authType
                ))
            }
        }

        return AgentSessionConfig(
            agentID: agent.id,
            projectID: projectID,
            skills: skillConfigs,
            tools: toolConfigs,
            systemPrompt: systemPromptParts.joined(separator: "\n\n---\n\n")
        )
    }

    /// JSON pretty-printed string of the config — useful for the UI preview.
    public func makeJSONPreview(agent: Agent, projectID: UUID) throws -> String {
        let config = makeSessionConfig(agent: agent, projectID: projectID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
