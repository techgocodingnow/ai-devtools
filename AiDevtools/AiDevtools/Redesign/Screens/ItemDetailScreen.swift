import SwiftUI

struct ItemDetailScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        let t = theme.tokens
        guard let item = store.openItem else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(spacing: 0) {
                toolbar(item, t)
                HStack(spacing: 0) {
                    detailMain(item)
                    ItemDetailSide(item: item)
                        .frame(width: 320)
                }
            }
        )
    }

    private func toolbar(_ item: Item, _ t: Tokens) -> some View {
        ScreenToolbar(border: true) {
            Btn(.ghost, sm: true, action: { store.nav(.library) }) {
                Sym(Icons.chev, size: 12).rotationEffect(.degrees(180)); Text("Library")
            }
            Rectangle().fill(t.line).frame(width: 0.5, height: 16)
            ItemGlyph(item, size: 22)
            Text(item.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
            Text("v\(item.version)").mono(11).foregroundStyle(t.fg3)
            Pill(item.kind.pill, style: .kind(item.kind))
            if item.status != .ok {
                Pill(.custom(bg: item.status == .err ? Color.oklch(0.66, 0.20, 25, 0.18) : Color.oklch(0.78, 0.14, 78, 0.18),
                             fg: item.status == .err ? t.err : t.warn)) {
                    Sym(Icons.alert, size: 10); Text(item.warning ?? "Needs attention")
                }
            }
            Spacer()
            Btn(.ghost, sm: true) {} label: { Sym(Icons.refresh, size: 12); Text("Check for updates") }
            Btn(.normal, sm: true) {} label: { Sym(Icons.edit, size: 12); Text("Edit") }
            Btn(.danger, sm: true) {} label: { Sym(Icons.trash, size: 12); Text("Remove…") }
        }
    }

    private func detailMain(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TabBar(tabs: DetailTab.allCases, selection: store.detailTab) { store.detailTab = $0 } label: { $0.label }
                .padding(.horizontal, 24)
            ScrollView {
                SwiftUI.Group {
                    switch store.detailTab {
                    case .overview: OverviewTab(item: item)
                    case .config: ConfigTab(item: item)
                    case .permissions: PermissionsTab(item: item)
                    case .logs: LogsTab(item: item)
                    case .source: SourceTab(item: item)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Tab bar

struct TabBar<T: Hashable>: View {
    @EnvironmentObject private var theme: ThemeManager
    let tabs: [T]
    let selection: T
    let onSelect: (T) -> Void
    let label: (T) -> String

    var body: some View {
        let t = theme.tokens
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let active = tab == selection
                Button { onSelect(tab) } label: {
                    Text(label(tab))
                        .font(.system(size: 12))
                        .foregroundStyle(active ? t.fg : t.fg3)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(active ? t.accent : .clear).frame(height: 1.5)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) { t.line.frame(height: 0.5) }
        .padding(.bottom, 14)
    }
}

// MARK: - Overview

private let SKILL_CAPS = [
    ("instruction.md", "core prompt loaded when skill is invoked"),
    ("tools.json", "declares helper tools the skill defines"),
    ("examples/*", "reference examples seeded into agent context"),
]
private let PLUGIN_CAPS = [
    ("manifest.json", "declares commands + hook surface area"),
    ("pre-tool-use", "hooks before tool invocations"),
    ("commands.*", "registers /commands in the agent CLI"),
]
private let CONN_CAPS = [
    ("mcp.stdio", "spawns server via stdio transport"),
    ("auth.oauth2", "requires OAuth handshake on first use"),
    ("tools", "12 callable tools exposed over MCP"),
]
private let FILES = [
    ("manifest.json", "482 B"), ("instruction.md", "4.2 KB"),
    ("tools/read.py", "1.1 KB"), ("tools/parse.py", "3.4 KB"), ("examples/sample.pdf", "128 KB"),
]

private struct OverviewTab: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let item: Item

    private var desc: String {
        if let d = item.description { return d }
        switch item.kind {
        case .skill: return "A reusable agent instruction set — prompts, tools and helpers — packaged as a folder under SKILLS/."
        case .plugin: return "A locally-installed plugin that extends the agent with custom commands, tool implementations or pre/post hooks."
        case .mcp: return "An MCP server that exposes an external service to the agent over the Model Context Protocol."
        }
    }
    private var caps: [(String, String)] { item.kind == .mcp ? CONN_CAPS : item.kind == .skill ? SKILL_CAPS : PLUGIN_CAPS }

    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 14) {
            Text(desc).font(.system(size: 13)).lineSpacing(3).foregroundStyle(t.fg2)

            FlowRow(spacing: 8) {
                if let g = store.group(item.group) {
                    Pill { Dot(color: g.color); Text(g.name) }
                }
                Pill { Sym(Icons.shieldOk, size: 10); Text("Signed by \(item.vendor)") }
                Pill("Updated \(item.updated)")
                if item.size != "—" { Pill(item.size) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Subtitle("Capabilities")
                ForEach(caps, id: \.0) { name, d in
                    HStack(spacing: 8) {
                        Sym(Icons.check, size: 12).foregroundStyle(t.ok)
                        Text(name).mono(11).foregroundStyle(t.fg2)
                        Text(d).font(.system(size: 12)).foregroundStyle(t.fg3)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Subtitle("Files")
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(FILES.enumerated()), id: \.element.0) { idx, f in
                            HStack(spacing: 8) {
                                Sym(Icons.box, size: 11).foregroundStyle(t.fg3)
                                Text(f.0).mono(11).foregroundStyle(t.fg2)
                                Spacer()
                                Text(f.1).font(.system(size: 11.5)).foregroundStyle(t.fg3)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(alignment: .bottom) { if idx < FILES.count - 1 { t.lineSoft.frame(height: 0.5) } }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Configuration

private struct ConfigTab: View {
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 14) {
            Card(padding: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Sym(Icons.cog, size: 12).foregroundStyle(t.fg3)
                        Text("config.json").font(.system(size: 12, weight: .semibold)).foregroundStyle(t.fg)
                        Spacer()
                        Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.copy, size: 12) }
                        Btn(.ghost, sm: true) {} label: { Sym(Icons.edit, size: 12); Text("Edit") }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .overlay(alignment: .bottom) { t.lineSoft.frame(height: 0.5) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        jsonText.padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .background(t.bgSidebar)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Subtitle("Environment")
                ForEach(env, id: \.0) { k, v in
                    HStack {
                        Text(k).mono(11).foregroundStyle(t.fg3).frame(width: 130, alignment: .leading)
                        Text(v).mono(11).foregroundStyle(t.fg2)
                        Spacer()
                        Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.edit, size: 11) }
                    }
                }
            }
        }
    }
    private var env: [(String, String)] {
        [("LOG_LEVEL", "info"), ("MAX_TOKENS", "8192"), ("CACHE_DIR", "~/.cache/agent/\(item.id)")]
    }
    private var jsonText: Text {
        let agents = item.agents.map { "\"\($0)\"" }.joined(separator: ", ")
        func k(_ s: String) -> Text { Text("\"\(s)\"").foregroundColor(CodeColor.key) }
        func str(_ s: String) -> Text { Text("\"\(s)\"").foregroundColor(CodeColor.string) }
        func n(_ s: String) -> Text { Text(s).foregroundColor(CodeColor.number) }
        let p = Text("  ")
        return Text("{\n") + p + k("name") + Text(": ") + str(item.name) + Text(",\n")
            + p + k("version") + Text(": ") + str(item.version) + Text(",\n")
            + p + k("agents") + Text(": [\(agents)],\n")
            + p + k("timeout_ms") + Text(": ") + n("30000") + Text(",\n")
            + p + k("max_concurrent") + Text(": ") + n("3") + Text(",\n")
            + p + Text("// Edit this file directly in the editor").foregroundColor(CodeColor.comment) + Text("\n")
            + p + k("options") + Text(": {\n")
            + Text("    ") + k("verbose") + Text(": ") + n("false") + Text(",\n")
            + Text("    ") + k("telemetry") + Text(": ") + n("true") + Text("\n")
            + p + Text("}\n}")
    }
}

// MARK: - Permissions

private struct PermissionsTab: View {
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    private var perms: [(String, String, [String])] {
        let token = "ATK_" + item.id.uppercased().replacingOccurrences(of: "-", with: "_") + "_TOKEN"
        return [
            ("Filesystem", "Read-only", ["./*", "~/.cache"]),
            ("Network", "Outbound HTTPS", ["api.\(item.id).com"]),
            ("Shell", "Denied", []),
            ("Secrets", "1 secret", [token]),
        ]
    }
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 10) {
            ForEach(perms, id: \.0) { area, scope, paths in
                Card(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Sym(Icons.shield, size: 13).foregroundStyle(scope == "Denied" ? t.fg3 : t.accent)
                            Text(area).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(t.fg)
                            Spacer()
                            Pill(scope)
                        }
                        if !paths.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(paths, id: \.self) { Text($0).mono(11).foregroundStyle(t.fg3) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Activity (logs)

private struct LogsTab: View {
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    private var logs: [(String, String, String)] {
        [("13:42:08", "info", "tool.invoke parse_pdf(input.pdf) → 12 pages"),
         ("13:42:06", "info", "tool.invoke read_pdf(input.pdf) → 482 KB"),
         ("13:39:51", "warn", "cache miss for \(item.id)/result-2a4f, refetching"),
         ("13:38:14", "info", "loaded skill \(item.id) v\(item.version) (142 KB)"),
         ("11:02:33", "error", "request timed out after 30000ms (host: api.local)"),
         ("Yest 18:22", "info", "enabled in workspace mcp-tooling")]
    }
    var body: some View {
        let t = theme.tokens
        CodeBlock(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(logs, id: \.0) { time, lvl, msg in
                    (Text("[\(time)] ").foregroundColor(CodeColor.comment)
                     + Text(lvl.padding(toLength: 5, withPad: " ", startingAt: 0) + " ")
                        .foregroundColor(lvl == "error" ? t.err : lvl == "warn" ? t.warn : Color.oklch(0.74, 0.13, 290))
                     + Text(msg).foregroundColor(t.fg2))
                        .font(.system(size: 11.5, design: .monospaced))
                }
            }
        }
    }
}

// MARK: - Source

private struct SourceTab: View {
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 14) {
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Installed from")
                    HStack {
                        Sym(Icons.shop, size: 14).foregroundStyle(t.fg3)
                        Text(item.vendor.hasPrefix("community") ? "Community Hub" : item.vendor.hasPrefix("kuro") ? "kuro/tools" : "Anthropic Official")
                            .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(t.fg)
                        Pill(item.vendor.hasPrefix("community") ? "community" : "verified", style: .accent)
                    }
                    Text("https://hub.agenttools.dev/\(item.vendor)/\(item.id)").mono(11).foregroundStyle(t.fg3)
                }
            }
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Local install path")
                    Text("~/.agent/\(item.kind == .skill ? "skills" : item.kind == .plugin ? "plugins" : "mcp")/\(item.id)/")
                        .mono(11.5).foregroundStyle(t.fg)
                }
            }
        }
    }
}

// MARK: - Side panel

struct ItemDetailSide: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let item: Item
    var body: some View {
        let t = theme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Scopes")
                    VStack(spacing: 1) {
                        ForEach(store.workspaces) { w in
                            ScopeRow(workspace: w,
                                     installed: item.scopes[w.id] == true,
                                     enabled: item.enabled[w.id] == true,
                                     onToggle: { store.setScopeEnabled(item.id, ws: w.id, $0) },
                                     onInstall: { store.installScope(item.id, ws: w.id) })
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Supported agents")
                    ForEach(store.agents) { a in
                        let on = item.agents.contains(a.id)
                        HStack {
                            AgentBadge(agent: a, size: 16)
                            Text(a.name).font(.system(size: 11.5)).foregroundStyle(t.fg)
                            Spacer()
                            if on { Sym(Icons.check, size: 11).foregroundStyle(t.ok) }
                            else { Sym(Icons.x, size: 10).foregroundStyle(t.fg3) }
                        }
                        .opacity(on ? 1 : 0.4)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Subtitle("Metadata")
                    MetaList(rows: meta)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .background(t.bgSidebar)
        .overlay(alignment: .leading) { t.line.frame(width: 0.5) }
    }
    private var meta: [(String, String)] {
        var r: [(String, String)] = [
            ("ID", item.id), ("Vendor", item.vendor), ("Version", item.version),
            ("Group", item.group ?? "—"), ("Size", item.size), ("Updated", item.updated),
        ]
        if let a = item.auth { r.append(("Auth", a)) }
        return r
    }
}

struct ScopeRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let workspace: Workspace
    let installed: Bool
    let enabled: Bool
    let onToggle: (Bool) -> Void
    let onInstall: () -> Void
    var body: some View {
        let t = theme.tokens
        HStack(spacing: 8) {
            GradientGlyph(label: workspace.initials, gradient: workspace.gradient, size: 16, radius: 4)
            Text(workspace.name).font(.system(size: 11.5)).foregroundStyle(installed ? t.fg : t.fg3)
            Spacer()
            if installed {
                ATToggle(isOn: enabled, sm: true) { onToggle($0) }
            } else {
                Btn(.ghost, sm: true, iconOnly: true, action: onInstall) { Sym(Icons.plus, size: 11) }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 5).fill(installed ? t.bgElev : .clear))
    }
}

struct MetaList: View {
    @EnvironmentObject private var theme: ThemeManager
    let rows: [(String, String)]
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.0) { k, v in
                HStack(alignment: .top, spacing: 10) {
                    Text(k).font(.system(size: 11.5)).foregroundStyle(t.fg3).frame(width: 80, alignment: .leading)
                    Text(v).font(.system(size: 11.5, design: k == "ID" || k == "Version" ? .monospaced : .default))
                        .foregroundStyle(t.fg).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Flow layout (wrapping rows of pills)

struct FlowRow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
