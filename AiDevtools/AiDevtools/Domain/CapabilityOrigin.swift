import Foundation

/// Where a capability (skill/plugin/MCP server) was sourced from.
public nonisolated enum CapabilityOrigin: String, Codable, Sendable, Hashable, CaseIterable {
    case manual          // Added in-app by the user.
    case claudeHome      // Lives under `~/.claude/skills` or `~/.claude/.mcp.json`.
    case claudeDesktop   // Defined in `~/Library/Application Support/Claude/claude_desktop_config.json`.
    case plugin          // Bundled inside an installed plugin.

    public var displayLabel: String {
        switch self {
        case .manual: return "Manual"
        case .claudeHome: return "Claude Code"
        case .claudeDesktop: return "Claude Desktop"
        case .plugin: return "Plugin"
        }
    }

    public var systemImage: String {
        switch self {
        case .manual: return "person.crop.circle"
        case .claudeHome: return "terminal"
        case .claudeDesktop: return "macwindow"
        case .plugin: return "puzzlepiece.extension"
        }
    }
}

/// Compatibility alias — earlier code referenced `MCPOrigin` only.
public typealias MCPOrigin = CapabilityOrigin
