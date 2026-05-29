import SwiftUI

struct HooksScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager

    private var filtered: [Hook] {
        store.hooks.filter { h in
            guard h.scopes[store.workspace] == true else { return false }
            if let e = store.hookEventFilter, h.event != e { return false }
            if let a = store.hookAgentFilter, !h.agents.contains(a) { return false }
            switch store.hookStatusFilter {
            case .enabled where h.enabled[store.workspace] != true: return false
            case .disabled where h.enabled[store.workspace] == true: return false
            case .untrusted where h.trusted: return false
            case .issues where h.status == .ok: return false
            default: break
            }
            if !store.search.isEmpty {
                let s = store.search.lowercased()
                if !h.id.contains(s) && !h.command.lowercased().contains(s) && !h.matcher.lowercased().contains(s)
                    && !h.description.lowercased().contains(s) && !h.event.contains(s) { return false }
            }
            return true
        }
    }
    private var eventsInOrder: [HookEvent] {
        let present = Set(filtered.map(\.event))
        return store.hookEvents.filter { present.contains($0.id) }
    }
    private var totalEnabled: Int { filtered.filter { $0.enabled[store.workspace] == true }.count }
    private var untrusted: Int { filtered.filter { !$0.trusted }.count }
    private var issues: Int { filtered.filter { $0.status != .ok }.count }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if untrusted > 0 { untrustedBanner }
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(eventsInOrder) { ev in
                            HookEventSection(event: ev, hooks: filtered.filter { $0.event == ev.id })
                        }
                        if filtered.isEmpty { emptyState }
                        HookLifecycleMap()
                    }
                    .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                if let hook = store.selectedHook {
                    HookDetailPanel(hook: hook).frame(width: 340)
                }
            }
        }
        .sheet(isPresented: $store.showHookForm) {
            HookForm().environmentObject(store).environmentObject(theme)
        }
    }

    private var toolbar: some View {
        let t = theme.tokens
        return ScreenToolbar {
            ScreenHeader("Hooks") {
                HStack(spacing: 0) {
                    Text("\(filtered.count) hooks across \(eventsInOrder.count) events · \(totalEnabled) active in ")
                    Text(store.currentWorkspace.name).foregroundColor(t.accent)
                    if untrusted > 0 { Text(" · ") + Text("\(untrusted) untrusted").foregroundColor(t.err) }
                    if issues > 0 { Text(" · ") + Text("\(issues) need attention").foregroundColor(t.warn) }
                }
            }
            Spacer()
            SearchField(text: $store.search, placeholder: "Search hooks…").frame(width: 200)
            statusSeg
            agentSeg
            Btn(.normal, sm: true, action: { store.showHookForm = true }) { Sym(Icons.plus, size: 12); Text("New hook") }
        }
    }

    private var statusSeg: some View {
        Seg {
            SegButton("All", on: store.hookStatusFilter == .all) { store.hookStatusFilter = .all }
            SegButton("On", on: store.hookStatusFilter == .enabled) { store.hookStatusFilter = .enabled }
            SegButton(on: store.hookStatusFilter == .untrusted, action: { store.hookStatusFilter = .untrusted }) {
                HStack(spacing: 4) {
                    Text("Untrusted")
                    if untrusted > 0 {
                        Text("\(untrusted)").font(.system(size: 10)).foregroundStyle(.white)
                            .padding(.horizontal, 5).background(Capsule().fill(theme.tokens.err))
                    }
                }
            }
            SegButton("Issues", on: store.hookStatusFilter == .issues) { store.hookStatusFilter = .issues }
        }
    }

    private var agentSeg: some View {
        Seg {
            SegButton("All agents", on: store.hookAgentFilter == nil) { store.hookAgentFilter = nil }
            ForEach(store.agents) { a in
                SegButton(on: store.hookAgentFilter == a.id, action: { store.hookAgentFilter = a.id }) {
                    HStack(spacing: 5) { AgentBadge(agent: a, size: 12); Text(a.firstName) }
                }
            }
        }
    }

    private var untrustedBanner: some View {
        let t = theme.tokens
        return HStack(spacing: 10) {
            Sym(Icons.alert, size: 14).foregroundStyle(t.err)
            (Text("\(untrusted) hook\(untrusted > 1 ? "s" : "") from new sources need review").bold().foregroundColor(t.err)
             + Text("   Untrusted hooks won't fire until you read the command and approve them.").foregroundColor(t.fg3))
                .font(.system(size: 11.5))
            Spacer()
            Btn("Review all", .ghost, sm: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.oklch(0.66, 0.20, 25, 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.oklch(0.66, 0.20, 25, 0.4), lineWidth: 0.5))
        .padding(.horizontal, 16).padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Sym(Icons.zap, size: 28).foregroundStyle(theme.tokens.fg3.opacity(0.5))
            Text("No hooks match your filters.").font(.system(size: 13)).foregroundStyle(theme.tokens.fg3).padding(.top, 10)
            Text("Try clearing the search or switch to Global scope.").font(.system(size: 11.5)).foregroundStyle(theme.tokens.fg3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

// MARK: - Event section

private struct HookEventSection: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let event: HookEvent
    let hooks: [Hook]
    private var collapsed: Bool { store.collapsedEvents.contains(event.id) }
    private var enabledCount: Int { hooks.filter { $0.enabled[store.workspace] == true }.count }

    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 6) {
            Button { store.toggleEvent(event.id) } label: {
                HStack(spacing: 8) {
                    Sym(Icons.chev, size: 10).rotationEffect(.degrees(collapsed ? 0 : 90)).foregroundStyle(t.fg3)
                    Text(event.label).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(t.fg)
                    Pill(.custom(bg: event.cadence.color.opacity(0.13), fg: event.cadence.color)) { Text(event.cadence.rawValue) }
                    Text("\(enabledCount)/\(hooks.count) active").font(.system(size: 11).monospacedDigit()).foregroundStyle(t.fg3)
                    Spacer()
                    HStack(spacing: 3) { ForEach(event.agents, id: \.self) { if let a = store.agent($0) { AgentBadge(agent: a, size: 14) } } }
                    Text(event.desc).font(.system(size: 11)).foregroundStyle(t.fg3).lineLimit(1).frame(maxWidth: 280, alignment: .trailing)
                }
            }
            .buttonStyle(.plain)
            if !collapsed {
                VStack(spacing: 0) {
                    ForEach(Array(hooks.enumerated()), id: \.element.id) { idx, h in
                        HookRow(hook: h, last: idx == hooks.count - 1)
                    }
                }
                .background(RoundedRectangle(cornerRadius: Radius.lg).fill(t.bgPanel))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(t.line, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            }
        }
        .padding(.top, 12)
    }
}

private struct HookRow: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let hook: Hook
    let last: Bool

    var body: some View {
        let t = theme.tokens
        let enabled = hook.enabled[store.workspace] == true
        let selected = store.selectedHookId == hook.id
        Button { store.selectedHookId = hook.id } label: {
            HStack(spacing: 10) {
                ATToggle(isOn: enabled, sm: true) { store.toggleHook(hook.id, $0) }.frame(width: 28)
                // matcher
                HStack(spacing: 6) {
                    Circle().fill(hook.type.color).frame(width: 4, height: 4)
                    if hook.matcher == "*" { Text("any tool").mono(11).foregroundStyle(t.fg3) }
                    else { Text(hook.matcher).mono(11).foregroundStyle(t.fg2).lineLimit(1) }
                }
                .frame(width: 140, alignment: .leading)
                // command + id
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if !hook.trusted { Sym(Icons.shield, size: 11).foregroundStyle(t.err) }
                        if hook.status == .warn { Sym(Icons.alert, size: 11).foregroundStyle(t.warn) }
                        if hook.status == .err { Sym(Icons.alert, size: 11).foregroundStyle(t.err) }
                        Text(hook.command).mono(11).foregroundStyle(enabled ? t.fg : t.fg3).lineLimit(1)
                    }
                    (Text(hook.id) + (hook.source != "user" ? Text(" · from \(hook.source)").foregroundColor(t.accent) : Text("")))
                        .font(.system(size: 10.5)).foregroundColor(t.fg3).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // type
                Text(hook.type.rawValue.uppercased() + (hook.async ? "·ASYNC" : ""))
                    .font(.system(size: 10.5, design: .monospaced)).tracking(0.4).foregroundStyle(hook.type.color)
                    .frame(width: 78, alignment: .leading)
                // agents
                HStack(spacing: 2) { ForEach(hook.agents, id: \.self) { if let a = store.agent($0) { AgentBadge(agent: a, size: 16) } } }
                    .frame(width: 90, alignment: .leading)
                // last fired
                VStack(alignment: .trailing, spacing: 1) {
                    Text(hook.lastFired).font(.system(size: 10.5)).foregroundStyle(t.fg3)
                    Text("\(hook.firesPerHour)/h").font(.system(size: 9.5, design: .monospaced)).foregroundStyle(t.fg4)
                }
                .frame(width: 76, alignment: .trailing)
                Btn(.ghost, sm: true, iconOnly: true) {} label: { Sym(Icons.more, size: 12) }.frame(width: 28)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? t.accentSoft : (hover ? t.bgHover : .clear))
            .overlay(alignment: .bottom) { if !last { t.lineSoft.frame(height: 0.5) } }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - Detail panel

private struct HookDetailPanel: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    let hook: Hook

    var body: some View {
        let t = theme.tokens
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Sym(Icons.zap, size: 14).foregroundStyle(hook.type.color)
                    Text(hook.id).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(t.fg)
                    Spacer()
                    Btn(.ghost, sm: true, iconOnly: true, action: { store.selectedHookId = nil }) { Sym(Icons.x, size: 12) }
                }
                Text(hook.description).font(.system(size: 12)).foregroundStyle(t.fg2).lineSpacing(2)

                if let warning = hook.warning {
                    HStack(alignment: .top, spacing: 8) {
                        Sym(Icons.alert, size: 12)
                        Text(warning)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(hook.trusted ? t.warn : t.err)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill((hook.trusted ? Color.oklch(0.78, 0.14, 78, 0.15) : Color.oklch(0.66, 0.20, 25, 0.15))))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(hook.trusted ? Color.oklch(0.78, 0.14, 78, 0.4) : Color.oklch(0.66, 0.20, 25, 0.4), lineWidth: 0.5))
                }

                if !hook.trusted { untrustedCard }

                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Configuration")
                    MetaList(rows: configRows)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Command")
                    CodeBlock { Text(hook.command).font(.system(size: 11, design: .monospaced)).foregroundStyle(t.fg2)
                        .fixedSize(horizontal: false, vertical: true) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Scopes")
                    VStack(spacing: 1) {
                        ForEach(store.workspaces) { w in
                            ScopeRow(workspace: w, installed: hook.scopes[w.id] == true, enabled: hook.enabled[w.id] == true,
                                     onToggle: { store.setHookScope(hook.id, ws: w.id, $0) },
                                     onInstall: { store.addHookScope(hook.id, ws: w.id) })
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Subtitle("Recent invocations")
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(invocations.enumerated()), id: \.offset) { idx, inv in
                                HStack(spacing: 8) {
                                    Dot(color: inv.2 == 0 ? t.ok : t.err)
                                    Text(inv.3).mono(11).foregroundStyle(t.fg2).frame(minWidth: 50, alignment: .leading)
                                    Spacer()
                                    Text(inv.1).font(.system(size: 11)).foregroundStyle(t.fg3)
                                    Text("·").foregroundStyle(t.fg3)
                                    Text(inv.0).font(.system(size: 11)).foregroundStyle(t.fg3)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .overlay(alignment: .bottom) { if idx < invocations.count - 1 { t.lineSoft.frame(height: 0.5) } }
                            }
                        }
                    }
                }
                HStack(spacing: 6) {
                    Btn(.ghost, sm: true) {} label: { Sym(Icons.edit, size: 12); Text("Edit") }
                    Btn(.ghost, sm: true) {} label: { Sym(Icons.copy, size: 12); Text("Duplicate") }
                    Btn(.ghost, sm: true) {} label: { Sym(Icons.terminal, size: 12); Text("Test run") }
                    Spacer()
                    Btn(.danger, sm: true, iconOnly: true) {} label: { Sym(Icons.trash, size: 12) }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
        }
        .background(t.bgSidebar)
        .overlay(alignment: .leading) { t.line.frame(width: 0.5) }
    }

    private var untrustedCard: some View {
        let t = theme.tokens
        return VStack(alignment: .leading, spacing: 8) {
            HStack { Sym(Icons.shield, size: 13).foregroundStyle(t.err); Text("Untrusted source").font(.system(size: 12, weight: .bold)).foregroundStyle(t.fg) }
            (Text("This hook was added by ") + Text(hook.source).font(.system(size: 11.5, design: .monospaced))
             + Text(" and hasn't been reviewed yet. Read the command, then trust to allow it to fire."))
                .font(.system(size: 11.5)).foregroundStyle(t.fg2).lineSpacing(2)
            HStack(spacing: 6) {
                Btn(.primary, sm: true) {} label: { Sym(Icons.shieldOk, size: 12); Text("Trust hook") }
                Btn(.danger, sm: true) {} label: { Text("Block") }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(Color.oklch(0.66, 0.20, 25, 0.06)))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Color.oklch(0.66, 0.20, 25, 0.4), lineWidth: 0.5))
    }

    private var configRows: [(String, String)] {
        [("Event", hook.event), ("Matcher", hook.matcher),
         ("Type", hook.type.rawValue + (hook.async ? " (async)" : "")),
         ("Timeout", String(format: "%.1f s", Double(hook.timeout) / 1000)),
         ("Source", hook.source), ("Last fired", hook.lastFired), ("Rate", "\(hook.firesPerHour) / hour")]
    }
    private var invocations: [(String, String, Int, String)] {
        [("14s ago", "42ms", 0, "Edit"), ("38s ago", "38ms", 0, "Edit"),
         ("1m ago", "51ms", 0, "Write"), ("3m ago", "120ms", hook.status == .err ? 2 : 0, "Edit")]
    }
}

// MARK: - Lifecycle map

private struct HookLifecycleMap: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        let t = theme.tokens
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Sym(Icons.workspace, size: 12).foregroundStyle(t.fg2)
                Text("Agent lifecycle").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
                Text("\(store.hookEvents.count) events supported").font(.system(size: 11)).foregroundStyle(t.fg3)
                Spacer()
                Text("Click any event to filter — empty events have no hooks wired up.")
                    .font(.system(size: 11)).foregroundStyle(t.fg3)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(store.hookEvents) { ev in
                    let list = store.hooks.filter { $0.event == ev.id && $0.scopes[store.workspace] == true && $0.enabled[store.workspace] == true }
                    LifecycleCard(event: ev, count: list.count)
                }
            }
        }
        .padding(.top, 24)
    }
}

private struct LifecycleCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    let event: HookEvent
    let count: Int
    var body: some View {
        let t = theme.tokens
        let empty = count == 0
        Button { store.hookEventFilter = event.id } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(event.cadence.color).frame(width: 5, height: 5)
                    Text(event.label).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(t.fg).lineLimit(1)
                    Spacer()
                    Text("\(count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(empty ? t.fg4 : t.fg)
                }
                HStack(spacing: 3) {
                    ForEach(event.agents, id: \.self) { if let a = store.agent($0) { AgentBadge(agent: a, size: 12) } }
                    Spacer()
                    Text(event.cadence.rawValue.uppercased()).font(.system(size: 9.5)).tracking(0.5).foregroundStyle(t.fg3)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(hover ? t.bgElev : t.bgPanel))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(empty ? t.lineSoft : t.line, lineWidth: 0.5))
            .opacity(empty ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

// MARK: - New hook form

private struct HookForm: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var theme: ThemeManager
    @State private var eventId = "post_tool"
    @State private var matcher = "Edit|Write"
    @State private var type: HookType = .command
    @State private var command = ""
    @State private var timeoutMs = 5000
    @State private var isAsync = false

    private var event: HookEvent? { store.hookEvents.first { $0.id == eventId } }

    var body: some View {
        let t = theme.tokens
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Sym(Icons.zap, size: 14).foregroundStyle(t.accent)
                Text("New hook").font(.system(size: 13, weight: .semibold)).foregroundStyle(t.fg)
                Spacer()
                Btn(.ghost, sm: true, iconOnly: true, action: { store.showHookForm = false }) { Sym(Icons.x, size: 12) }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .overlay(alignment: .bottom) { t.lineSoft.frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Subtitle("Event", size: 10)
                        Picker("", selection: $eventId) {
                            ForEach(store.hookEvents) { Text("\($0.label) — \($0.desc)").tag($0.id) }
                        }.labelsHidden().pickerStyle(.menu)
                        if let ev = event {
                            (Text("Supported by: \(ev.agents.compactMap { store.agent($0)?.name }.joined(separator: ", ")) · cadence: ")
                             + Text(ev.cadence.rawValue).font(.system(size: 11, design: .monospaced)))
                                .font(.system(size: 11)).foregroundStyle(t.fg3)
                        }
                    }
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Subtitle("Matcher (regex on tool name)", size: 10)
                            FormInput(text: $matcher, mono: true)
                            (Text("Common matchers: ") + Text("Bash · Edit · Write · MultiEdit · Read · WebFetch · *").font(.system(size: 11, design: .monospaced)))
                                .font(.system(size: 11)).foregroundStyle(t.fg3)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Subtitle("Type", size: 10)
                            Picker("", selection: $type) {
                                ForEach([HookType.command, .http, .prompt, .agent], id: \.self) { Text($0.rawValue).tag($0) }
                            }.labelsHidden().pickerStyle(.menu)
                        }.frame(width: 140)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Subtitle(type == .http ? "Endpoint URL" : type == .command ? "Shell command" : "Prompt", size: 10)
                        TextEditor(text: $command)
                            .font(.system(size: 12, design: .monospaced)).scrollContentBackground(.hidden)
                            .frame(minHeight: 64).padding(8)
                            .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgInput))
                            .overlay(RoundedRectangle(cornerRadius: Radius.r).strokeBorder(t.line, lineWidth: 0.5))
                        Text("JSON event payload arrives on stdin. Exit code 2 blocks the action.")
                            .font(.system(size: 11)).foregroundStyle(t.fg3)
                    }
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Subtitle("Timeout", size: 10)
                            HStack(spacing: 6) {
                                TextField("", value: $timeoutMs, format: .number).textFieldStyle(.plain)
                                    .frame(width: 70).padding(.horizontal, 9).frame(height: 26)
                                    .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgInput))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.r).strokeBorder(t.line, lineWidth: 0.5))
                                Text("ms").foregroundStyle(t.fg3)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Subtitle("Run mode", size: 10)
                            HStack(spacing: 8) {
                                ATToggle(isOn: isAsync) { isAsync = $0 }
                                Text("Run async (don't block the loop)").font(.system(size: 12)).foregroundStyle(t.fg)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    previewCard
                }
                .padding(16)
            }

            HStack(spacing: 8) {
                Spacer()
                Btn("Cancel", .ghost, sm: true) { store.showHookForm = false }
                Btn(.primary, sm: true, action: { store.showHookForm = false }) { Sym(Icons.check, size: 12); Text("Add hook") }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .overlay(alignment: .top) { t.lineSoft.frame(height: 0.5) }
        }
        .frame(width: 580, height: 640)
        .background(t.bgElev)
    }

    private var previewCard: some View {
        let t = theme.tokens
        return Card(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                (Text("PREVIEW · ").font(.system(size: 10, weight: .semibold)).foregroundColor(t.fg3)
                 + Text("~/.claude/settings.json").font(.system(size: 10, design: .monospaced)).foregroundColor(t.fg3))
                ScrollView(.horizontal, showsIndicators: false) { previewJSON.padding(10) }
                    .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgWindow))
            }
        }
    }
    private var previewJSON: Text {
        func k(_ s: String) -> Text { Text("\"\(s)\"").foregroundColor(CodeColor.key) }
        func str(_ s: String) -> Text { Text("\"\(s)\"").foregroundColor(CodeColor.string) }
        func n(_ s: String) -> Text { Text(s).foregroundColor(CodeColor.number) }
        let label = event?.label ?? eventId
        var body = Text("{\n  ") + k("hooks") + Text(": {\n    ") + k(label) + Text(": [{\n      ")
            + k("matcher") + Text(": ") + str(matcher) + Text(",\n      ") + k("hooks") + Text(": [{\n        ")
            + k("type") + Text(": ") + str(type.rawValue) + Text(",\n        ")
            + k("command") + Text(": ") + str(command.isEmpty ? "…" : command) + Text(",\n        ")
            + k("timeout") + Text(": ") + n("\(timeoutMs)")
        if isAsync { body = body + Text(",\n        ") + k("async") + Text(": ") + n("true") }
        body = body + Text("\n      }]\n    }]\n  }\n}")
        return body.font(.system(size: 11, design: .monospaced))
    }
}
