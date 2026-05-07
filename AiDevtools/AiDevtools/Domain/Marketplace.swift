import Foundation

/// One row in a marketplace catalog feed.
public nonisolated struct MarketplaceItem: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var tags: [String]
    public var kind: CapabilityKind
    public var repoURL: URL
    public var branch: String?

    public init(
        id: String,
        name: String,
        summary: String = "",
        tags: [String] = [],
        kind: CapabilityKind = .plugin,
        repoURL: URL,
        branch: String? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.tags = tags
        self.kind = kind
        self.repoURL = repoURL
        self.branch = branch
    }
}

/// Outbound config given to a downstream Claude client.
public nonisolated struct AgentSessionConfig: Codable, Sendable {
    public var agentID: UUID
    public var projectID: UUID
    public var skills: [SkillConfig]
    public var tools: [ToolConfig]
    public var systemPrompt: String

    public struct SkillConfig: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var instructions: String
        public init(id: UUID, name: String, instructions: String) {
            self.id = id
            self.name = name
            self.instructions = instructions
        }
    }

    public struct ToolConfig: Codable, Sendable {
        public var id: UUID
        public var kind: CapabilityKind
        public var label: String
        public var endpoint: URL?
        public var authType: String?
        public init(id: UUID, kind: CapabilityKind, label: String, endpoint: URL? = nil, authType: String? = nil) {
            self.id = id
            self.kind = kind
            self.label = label
            self.endpoint = endpoint
            self.authType = authType
        }
    }

    public init(
        agentID: UUID,
        projectID: UUID,
        skills: [SkillConfig],
        tools: [ToolConfig],
        systemPrompt: String
    ) {
        self.agentID = agentID
        self.projectID = projectID
        self.skills = skills
        self.tools = tools
        self.systemPrompt = systemPrompt
    }
}
