import SwiftUI

// MARK: - Text helpers

extension View {
    /// JetBrains-Mono-style monospaced run (SF Mono on macOS).
    func mono(_ size: CGFloat = 11) -> some View {
        font(.system(size: size, design: .monospaced))
    }
}

struct Subtitle: View {
    @EnvironmentObject private var theme: ThemeManager
    let text: String
    var size: CGFloat = 11
    init(_ text: String, size: CGFloat = 11) { self.text = text; self.size = size }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(theme.tokens.fg3)
    }
}

struct Kbd: View {
    @EnvironmentObject private var theme: ThemeManager
    let text: String
    var body: some View {
        let t = theme.tokens
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(t.fg2)
            .frame(minWidth: 16, minHeight: 16)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(t.bgElev2))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(t.line, lineWidth: 0.5))
    }
}

// MARK: - Button

enum BtnStyle { case normal, primary, ghost, danger }

struct Btn<Label: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false

    var style: BtnStyle
    var sm: Bool
    var iconOnly: Bool
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    init(_ style: BtnStyle = .normal, sm: Bool = false, iconOnly: Bool = false,
         action: @escaping () -> Void = {}, @ViewBuilder label: @escaping () -> Label) {
        self.style = style; self.sm = sm; self.iconOnly = iconOnly
        self.action = action; self.label = label
    }

    var body: some View {
        let t = theme.tokens
        let h: CGFloat = sm ? 22 : 26
        Button(action: action) {
            HStack(spacing: 6) { label() }
                .font(.system(size: sm ? 11.5 : 12, weight: .medium))
                .foregroundStyle(fg(t))
                .frame(height: h)
                .frame(minWidth: iconOnly ? h : nil)
                .padding(.horizontal, iconOnly ? 0 : (sm ? 8 : 10))
                .background(RoundedRectangle(cornerRadius: sm ? Radius.sm : Radius.r).fill(bg(t)))
                .overlay(RoundedRectangle(cornerRadius: sm ? Radius.sm : Radius.r)
                    .strokeBorder(border(t), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    private func fg(_ t: Tokens) -> Color {
        switch style {
        case .primary: return .white
        case .danger: return t.err
        case .ghost: return hover ? t.fg : t.fg2
        case .normal: return t.fg
        }
    }
    private func bg(_ t: Tokens) -> Color {
        switch style {
        case .primary: return t.accent.opacity(hover ? 0.88 : 1)
        case .danger: return .oklch(0.66, 0.20, 25, 0.15)
        case .ghost: return hover ? t.bgHover : .clear
        case .normal: return hover ? t.bgHover : t.bgElev
        }
    }
    private func border(_ t: Tokens) -> Color {
        switch style {
        case .primary, .danger, .ghost: return .clear
        case .normal: return t.line
        }
    }
}

extension Btn where Label == Text {
    init(_ title: String, _ style: BtnStyle = .normal, sm: Bool = false, action: @escaping () -> Void = {}) {
        self.init(style, sm: sm, action: action) { Text(title) }
    }
}

// MARK: - Pill

enum PillStyle { case normal, accent, kind(ItemKind), custom(bg: Color, fg: Color) }

struct Pill<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    var style: PillStyle
    @ViewBuilder var content: () -> Content
    init(_ style: PillStyle = .normal, @ViewBuilder content: @escaping () -> Content) {
        self.style = style; self.content = content
    }
    var body: some View {
        let t = theme.tokens
        let c = colors(t)
        HStack(spacing: 4) { content() }
            .font(.system(size: 10.5))
            .foregroundStyle(c.fg)
            .frame(height: 18)
            .padding(.horizontal, 7)
            .background(Capsule().fill(c.bg))
            .overlay(Capsule().strokeBorder(c.border, lineWidth: 0.5))
    }
    private func colors(_ t: Tokens) -> (bg: Color, fg: Color, border: Color) {
        switch style {
        case .normal: return (t.bgElev, t.fg2, t.line)
        case .accent: return (t.accentSoft, t.accent, .clear)
        case .kind(let k): let p = t.pill(for: k); return (p.bg, p.fg, .clear)
        case .custom(let bg, let fg): return (bg, fg, .clear)
        }
    }
}

extension Pill where Content == Text {
    init(_ text: String, style: PillStyle = .normal) {
        self.init(style) { Text(text) }
    }
}

// MARK: - Toggle switch

struct ATToggle: View {
    @EnvironmentObject private var theme: ThemeManager
    var isOn: Bool
    var sm: Bool = false
    var onChange: (Bool) -> Void

    var body: some View {
        let t = theme.tokens
        let w: CGFloat = sm ? 22 : 28
        let h: CGFloat = sm ? 13 : 16
        let knob: CGFloat = sm ? 9 : 11
        let travel: CGFloat = sm ? 9 : 12
        Capsule()
            .fill(isOn ? t.accent : t.bgElev2)
            .frame(width: w, height: h)
            .overlay(Capsule().strokeBorder(isOn ? .clear : t.line, lineWidth: 0.5))
            .overlay(alignment: .leading) {
                Circle()
                    .fill(isOn ? Color.white : t.fg2)
                    .frame(width: knob, height: knob)
                    .padding(.leading, 1.5)
                    .offset(x: isOn ? travel : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { onChange(!isOn) }
            .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

// MARK: - Dots

struct Dot: View {
    @EnvironmentObject private var theme: ThemeManager
    var color: Color
    var ring: Bool = false
    var size: CGFloat = 6
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay {
                if ring { Circle().strokeBorder(color.opacity(0.18), lineWidth: 2).frame(width: size + 4, height: size + 4) }
            }
    }
}

extension Dot {
    init(status: ItemStatus, theme t: Tokens) {
        self.init(color: t.statusColor(status), ring: status == .ok)
    }
}

// MARK: - Glyphs

struct Glyph: View {
    let label: String
    var color: Color
    var size: CGFloat = 28
    var radius: CGFloat = 7
    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(label)
                    .font(.system(size: max(10, size * 0.42), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}

struct GradientGlyph: View {
    let label: String
    var gradient: LinearGradient
    var size: CGFloat = 28
    var radius: CGFloat = 7
    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay(
                Text(label)
                    .font(.system(size: max(10, size * 0.42), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

struct ItemGlyph: View {
    let kind: ItemKind
    let name: String
    var size: CGFloat = 28
    init(_ item: Item, size: CGFloat = 28) { self.kind = item.kind; self.name = item.name; self.size = size }
    init(kind: ItemKind, name: String, size: CGFloat = 28) { self.kind = kind; self.name = name; self.size = size }

    private var palette: [Color] {
        switch kind {
        case .skill: return [.oklch(0.74, 0.16, 152), .oklch(0.55, 0.18, 152)]
        case .plugin: return [.oklch(0.78, 0.14, 78), .oklch(0.60, 0.17, 78)]
        case .mcp: return [.oklch(0.74, 0.14, 232), .oklch(0.55, 0.17, 232)]
        }
    }
    private var initials: String {
        let words = name.split(whereSeparator: { $0 == " " || $0 == "-" })
        return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: max(10, size * 0.36), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

/// Small agent identity badge — colored rounded square with mono initials.
struct AgentBadge: View {
    let agent: AgentInfo
    var size: CGFloat = 18
    var body: some View {
        RoundedRectangle(cornerRadius: size <= 14 ? 3 : 4)
            .fill(agent.color)
            .frame(width: size, height: size)
            .overlay(
                Text(agent.initials)
                    .font(.system(size: max(7, size * 0.46), weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    var padding: CGFloat?
    var elev: Bool = false
    @ViewBuilder var content: () -> Content
    init(padding: CGFloat? = nil, elev: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding; self.elev = elev; self.content = content
    }
    var body: some View {
        let t = theme.tokens
        content()
            .padding(padding ?? theme.metrics.tilePad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Radius.lg).fill(elev ? t.bgElev : t.bgPanel))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(t.line, lineWidth: 0.5))
            .shadow(color: elev ? .black.opacity(0.35) : .clear, radius: elev ? 2 : 0, y: elev ? 1 : 0)
    }
}

// MARK: - Segmented control

struct Seg<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    @ViewBuilder var content: () -> Content
    var body: some View {
        let t = theme.tokens
        HStack(spacing: 1) { content() }
            .padding(1.5)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgElev))
            .overlay(RoundedRectangle(cornerRadius: Radius.r).strokeBorder(t.line, lineWidth: 0.5))
    }
}

struct SegButton<Label: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var hover = false
    var on: Bool
    var action: () -> Void
    @ViewBuilder var label: () -> Label
    init(on: Bool, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.on = on; self.action = action; self.label = label
    }
    var body: some View {
        let t = theme.tokens
        Button(action: action) {
            HStack(spacing: 5) { label() }
                .font(.system(size: 11.5))
                .foregroundStyle(on ? t.fg : (hover ? t.fg : t.fg2))
                .frame(height: 22)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: Radius.sm).fill(on ? t.bgWindow : .clear))
                .shadow(color: on ? .black.opacity(0.3) : .clear, radius: on ? 1 : 0, y: on ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

extension SegButton where Label == Text {
    init(_ title: String, on: Bool, action: @escaping () -> Void) {
        self.init(on: on, action: action) { Text(title) }
    }
}

// MARK: - Search field

struct SearchField: View {
    @EnvironmentObject private var theme: ThemeManager
    @Binding var text: String
    var placeholder: String
    @FocusState private var focused: Bool
    var body: some View {
        let t = theme.tokens
        HStack(spacing: 6) {
            Sym(Icons.search, size: 12).foregroundStyle(t.fg3)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(t.fg)
                .focused($focused)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgInput))
        .overlay(RoundedRectangle(cornerRadius: Radius.r)
            .strokeBorder(focused ? t.accent : t.line, lineWidth: focused ? 1 : 0.5))
    }
}

// MARK: - Code block

struct CodeBlock<Content: View>: View {
    @EnvironmentObject private var theme: ThemeManager
    var padding: CGFloat = 12
    @ViewBuilder var content: () -> Content
    init(padding: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding; self.content = content
    }
    var body: some View {
        let t = theme.tokens
        ScrollView(.horizontal, showsIndicators: false) {
            content()
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(t.fg2)
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: Radius.r).fill(t.bgSidebar))
        .overlay(RoundedRectangle(cornerRadius: Radius.r).strokeBorder(t.lineSoft, lineWidth: 0.5))
    }
}

/// Syntax-highlight palette for JSON code previews (ports pre.code .k/.s/.c/.n).
enum CodeColor {
    static let key = Color.oklch(0.74, 0.13, 290)
    static let string = Color.oklch(0.78, 0.12, 152)
    static let comment = Color.oklch(0.42, 0.006, 270)
    static let number = Color.oklch(0.78, 0.13, 78)
}
