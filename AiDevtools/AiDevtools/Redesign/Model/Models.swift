import SwiftUI

/// A color expressed as OKLCH so we can derive gradients (mirrors the design's inline `oklch()` usage).
struct LCH: Hashable {
    let l: Double, c: Double, h: Double
    var color: Color { .oklch(l, c, h) }
}

// MARK: - Item

enum ItemKind: String, CaseIterable, Identifiable, Hashable {
    case skill, plugin, mcp
    var id: String { rawValue }
    /// Label used in the sidebar / section headers.
    var plural: String {
        switch self {
        case .skill: return "Skills"
        case .plugin: return "Plugins"
        case .mcp: return "MCP servers"
        }
    }
    /// Lowercase pill label.
    var pill: String { self == .mcp ? "mcp" : rawValue }
}

enum ItemStatus: String, Hashable {
    case ok, warn, err, off
    var label: String {
        switch self {
        case .ok: return "Enabled"
        case .warn: return "Warning"
        case .err: return "Error"
        case .off: return "Off"
        }
    }
}

struct Item: Identifiable, Hashable {
    let id: String
    let kind: ItemKind
    let name: String
    let vendor: String
    let version: String
    var group: String?
    var status: ItemStatus
    let agents: [String]
    var scopes: [String: Bool]
    var enabled: [String: Bool]
    let updated: String
    let size: String
    var description: String?
    var warning: String?
    var auth: String?

    /// Two-letter initials from the name, used by the kind-colored glyph.
    var initials: String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" })
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

// MARK: - Workspace

enum WorkspaceScope: String, Hashable { case global, project }

struct Workspace: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let scope: WorkspaceScope
    let initials: String
    let colorLCH: LCH?
    let agents: [String]

    /// Gradient for the workspace glyph — ports `linear-gradient(135deg, color, oklch(0.45 0.06 …))`.
    var gradient: LinearGradient {
        if let lch = colorLCH {
            let end = Color.oklch(0.45, 0.06, Double(100 + id.count * 30))
            return LinearGradient(colors: [lch.color, end], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if scope == .global {
            return LinearGradient(colors: [.oklch(0.55, 0.005, 270), .oklch(0.42, 0.005, 270)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.oklch(0.66, 0.16, 282), .oklch(0.66, 0.16, 320)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Agent

struct AgentInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let vendor: String
    let version: String
    let binary: String
    let colorLCH: LCH
    let initials: String
    let detected: Bool
    let supports: [ItemKind]
    var color: Color { colorLCH.color }
    var firstName: String { String(name.split(separator: " ").first ?? "") }
}

// MARK: - Group

struct Group: Identifiable, Hashable {
    let id: String
    let name: String
    let colorLCH: LCH
    let items: Int
    let description: String
    /// True for user-created groups (editable); false for derived/structural groups.
    var custom: Bool = false
    /// Explicit member item ids — used only by custom groups (derived groups match on item.group).
    var memberIDs: [String] = []
    var color: Color { colorLCH.color }
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Marketplace

enum MarketSourceKind: String, Hashable { case official, community, github, `private` }
enum MarketTrust: String, Hashable { case verified, community, pinned, `private` }

struct MarketplaceSource: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String
    let kind: MarketSourceKind
    var items: Int
    var lastSync: String
    var enabled: Bool
    let trust: MarketTrust
}

struct FeedItem: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: ItemKind
    let vendor: String
    let installs: String
    let stars: Double
    let market: String
    let description: String
    var verified: Bool = false
}

// MARK: - Hooks

enum HookCadence: String, Hashable {
    case session, turn, tool, async
    var color: Color {
        switch self {
        case .session: return .oklch(0.66, 0.13, 282)
        case .turn: return .oklch(0.70, 0.13, 232)
        case .tool: return .oklch(0.72, 0.13, 152)
        case .async: return .oklch(0.74, 0.13, 78)
        }
    }
}

enum HookType: String, Hashable {
    case command, http, prompt, agent
    var color: Color {
        switch self {
        case .command: return .oklch(0.72, 0.13, 152)
        case .http: return .oklch(0.70, 0.13, 232)
        case .prompt: return .oklch(0.66, 0.16, 282)
        case .agent: return .oklch(0.74, 0.13, 78)
        }
    }
}

struct HookEvent: Identifiable, Hashable {
    let id: String
    let label: String
    let cadence: HookCadence
    let agents: [String]
    let desc: String
}

struct Hook: Identifiable, Hashable {
    let id: String
    let event: String
    let type: HookType
    let matcher: String
    let command: String
    let timeout: Int
    let async: Bool
    let agents: [String]
    var scopes: [String: Bool]
    var enabled: [String: Bool]
    var status: ItemStatus
    let lastFired: String
    let firesPerHour: Int
    let source: String
    let trusted: Bool
    let description: String
    var warning: String?
}

// MARK: - Activity

struct RecentActivity: Identifiable, Hashable {
    var id: String { t + who }
    let t: String
    let what: String
    let who: String
    let ctx: String
}
