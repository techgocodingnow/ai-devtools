import SwiftUI
import Combine

// MARK: - Enumerations (mirror the design's tweak options)

enum ThemeMode: String, CaseIterable, Identifiable {
    case dark, light
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

enum AccentName: String, CaseIterable, Identifiable {
    case violet, blue, green, amber
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// (lightness, chroma, hue) for the accent's primary color, ported from main.jsx ACCENTS.
    var lch: (Double, Double, Double) {
        switch self {
        case .violet: return (0.66, 0.16, 282)
        case .blue:   return (0.66, 0.16, 232)
        case .green:  return (0.66, 0.16, 152)
        case .amber:  return (0.72, 0.15, 78)
        }
    }
    var primary: Color { Color.oklch(lch.0, lch.1, lch.2) }
    var soft: Color { Color.oklch(lch.0, lch.1, lch.2, 0.16) }
}

enum DensityName: String, CaseIterable, Identifiable {
    case compact, regular, comfy
    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var padY: CGFloat { self == .compact ? 4 : self == .regular ? 6 : 9 }
    var padX: CGFloat { self == .compact ? 8 : self == .regular ? 10 : 12 }
    var rowH: CGFloat { self == .compact ? 28 : self == .regular ? 32 : 38 }
    var gap: CGFloat { self == .compact ? 6 : self == .regular ? 8 : 12 }
    var tilePad: CGFloat { self == .compact ? 10 : self == .regular ? 12 : 16 }
}

enum SidebarLayout: String, CaseIterable, Identifiable {
    case compact, `default`, wide
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var width: CGFloat { self == .compact ? 180 : self == .default ? 224 : 260 }
}

// MARK: - Radii

enum Radius {
    static let sm: CGFloat = 5
    static let r: CGFloat = 7
    static let lg: CGFloat = 10
    static let xl: CGFloat = 14
}

// MARK: - Tokens (semantic colors resolved per mode + accent)

struct Tokens {
    let mode: ThemeMode
    let accent: Color
    let accentSoft: Color

    // surfaces
    let bgWindow: Color
    let bgSidebar: Color
    let bgPanel: Color
    let bgElev: Color
    let bgElev2: Color
    let bgHover: Color
    let bgActive: Color
    let bgInput: Color

    // lines
    let line: Color
    let lineSoft: Color

    // foreground ramp
    let fg: Color
    let fg2: Color
    let fg3: Color
    let fg4: Color

    // semantic / status — shared across themes
    let ok = Color.oklch(0.72, 0.14, 152)
    let warn = Color.oklch(0.78, 0.14, 78)
    let err = Color.oklch(0.66, 0.20, 25)

    // category colors
    let catSkill = Color.oklch(0.72, 0.14, 152)
    let catPlugin = Color.oklch(0.78, 0.13, 78)
    let catMCP = Color.oklch(0.70, 0.13, 232)
    let catHook = Color.oklch(0.70, 0.15, 320)

    // traffic lights (used by the optional in-window chrome / about)
    let tlClose = Color(red: 1.0, green: 0.376, blue: 0.345)
    let tlMin = Color(red: 1.0, green: 0.745, blue: 0.180)
    let tlMax = Color(red: 0.157, green: 0.788, blue: 0.255)

    static func make(mode: ThemeMode, accent: AccentName) -> Tokens {
        switch mode {
        case .dark:
            return Tokens(
                mode: .dark,
                accent: accent.primary,
                accentSoft: accent.soft,
                bgWindow: .oklch(0.18, 0.005, 270),
                bgSidebar: .oklch(0.205, 0.006, 270),
                bgPanel: .oklch(0.22, 0.006, 270),
                bgElev: .oklch(0.245, 0.006, 270),
                bgElev2: .oklch(0.27, 0.007, 270),
                bgHover: .oklch(0.27, 0.008, 270),
                bgActive: .oklch(0.31, 0.01, 270),
                bgInput: .oklch(0.225, 0.006, 270),
                line: .oklch(0.30, 0.008, 270),
                lineSoft: .oklch(0.255, 0.006, 270),
                fg: .oklch(0.96, 0.005, 270),
                fg2: .oklch(0.75, 0.006, 270),
                fg3: .oklch(0.55, 0.006, 270),
                fg4: .oklch(0.42, 0.006, 270)
            )
        case .light:
            return Tokens(
                mode: .light,
                accent: accent.primary,
                accentSoft: accent.soft,
                bgWindow: .oklch(0.985, 0.002, 270),
                bgSidebar: .oklch(0.965, 0.003, 270),
                bgPanel: .oklch(0.985, 0.002, 270),
                bgElev: .oklch(1, 0, 0),
                bgElev2: .oklch(0.98, 0.002, 270),
                bgHover: .oklch(0.94, 0.003, 270),
                bgActive: .oklch(0.91, 0.004, 270),
                bgInput: .oklch(0.97, 0.002, 270),
                line: .oklch(0.88, 0.004, 270),
                lineSoft: .oklch(0.93, 0.003, 270),
                fg: .oklch(0.18, 0.005, 270),
                fg2: .oklch(0.36, 0.006, 270),
                fg3: .oklch(0.52, 0.006, 270),
                fg4: .oklch(0.68, 0.006, 270)
            )
        }
    }

    // pill background/foreground for a category kind
    func pill(for kind: ItemKind) -> (bg: Color, fg: Color) {
        switch kind {
        case .skill:  return (.oklch(0.72, 0.14, 152, 0.14), mode == .light ? .oklch(0.42, 0.16, 152) : .oklch(0.78, 0.16, 152))
        case .plugin: return (.oklch(0.78, 0.13, 78, 0.16),  mode == .light ? .oklch(0.48, 0.14, 78)  : .oklch(0.82, 0.14, 78))
        case .mcp:    return (.oklch(0.70, 0.13, 232, 0.18), mode == .light ? .oklch(0.42, 0.15, 232) : .oklch(0.76, 0.15, 232))
        }
    }

    func categoryColor(_ kind: ItemKind) -> Color {
        switch kind {
        case .skill: return catSkill
        case .plugin: return catPlugin
        case .mcp: return catMCP
        }
    }

    func statusColor(_ status: ItemStatus) -> Color {
        switch status {
        case .ok: return ok
        case .warn: return warn
        case .err: return err
        case .off: return fg4
        }
    }
}

// MARK: - Theme manager (persisted, injected into the environment)

@MainActor
final class ThemeManager: ObservableObject {
    @Published var mode: ThemeMode { didSet { persist("theme.mode", mode.rawValue) } }
    @Published var accent: AccentName { didSet { persist("theme.accent", accent.rawValue) } }
    @Published var density: DensityName { didSet { persist("theme.density", density.rawValue) } }
    @Published var sidebarLayout: SidebarLayout { didSet { persist("theme.sidebar", sidebarLayout.rawValue) } }

    init() {
        let d = UserDefaults.standard
        mode = ThemeMode(rawValue: d.string(forKey: "theme.mode") ?? "") ?? .dark
        accent = AccentName(rawValue: d.string(forKey: "theme.accent") ?? "") ?? .violet
        density = DensityName(rawValue: d.string(forKey: "theme.density") ?? "") ?? .regular
        sidebarLayout = SidebarLayout(rawValue: d.string(forKey: "theme.sidebar") ?? "") ?? .default
    }

    var tokens: Tokens { Tokens.make(mode: mode, accent: accent) }
    var metrics: DensityName { density }
    var sidebarWidth: CGFloat { sidebarLayout.width }
    var colorScheme: ColorScheme { mode == .dark ? .dark : .light }

    private func persist(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
