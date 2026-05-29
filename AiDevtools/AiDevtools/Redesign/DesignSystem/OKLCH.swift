import SwiftUI

/// OKLCH → sRGB conversion so we can port the design's `oklch(L C H / a)` tokens verbatim.
///
/// The design system (ds.css) is authored entirely in OKLCH. SwiftUI has no native
/// OKLCH initializer, so we convert OKLCH → OKLab → linear sRGB and hand the linear
/// components to `Color(.sRGBLinear, …)`, which applies the sRGB transfer function for us.
enum OKLCH {
    /// - Parameters:
    ///   - l: Perceptual lightness, 0…1.
    ///   - c: Chroma, ~0…0.4.
    ///   - h: Hue in degrees, 0…360.
    ///   - alpha: Opacity, 0…1.
    static func color(_ l: Double, _ c: Double, _ h: Double, _ alpha: Double = 1) -> Color {
        let hr = h * .pi / 180
        let a = c * cos(hr)
        let b = c * sin(hr)

        // OKLab → LMS (cube-rooted)
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b

        let lc = l_ * l_ * l_
        let mc = m_ * m_ * m_
        let sc = s_ * s_ * s_

        // LMS → linear sRGB
        var r =  4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        var g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        var bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        r = min(max(r, 0), 1)
        g = min(max(g, 0), 1)
        bl = min(max(bl, 0), 1)

        return Color(.sRGBLinear, red: r, green: g, blue: bl, opacity: alpha)
    }
}

extension Color {
    /// Shorthand mirroring the CSS `oklch()` function used throughout the design tokens.
    static func oklch(_ l: Double, _ c: Double, _ h: Double, _ a: Double = 1) -> Color {
        OKLCH.color(l, c, h, a)
    }
}
