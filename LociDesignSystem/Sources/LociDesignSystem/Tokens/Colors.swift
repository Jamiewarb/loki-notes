import Foundation

/// Semantic color tokens for Loci.
/// Hex + sRGB components are Linux-testable; SwiftUI `Color` wrappers live behind `canImport(SwiftUI)`.
public enum LociColors: Sendable {
    // MARK: - Brand / ink

    /// Deep forest charcoal — primary text and brand weight.
    public static let inkHex = "#1A2421"
    public static let inkRGB: (r: Double, g: Double, b: Double, a: Double) = (0.102, 0.141, 0.129, 1)

    /// Softened ink for secondary copy.
    public static let inkSoftHex = "#3D4A45"
    public static let inkSoftRGB: (r: Double, g: Double, b: Double, a: Double) = (0.239, 0.290, 0.271, 1)

    /// Inverse text on accent fills.
    public static let inkInverseHex = "#F7FBF9"
    public static let inkInverseRGB: (r: Double, g: Double, b: Double, a: Double) = (0.969, 0.984, 0.976, 1)

    // MARK: - Surfaces

    /// Primary paper / canvas.
    public static let paperHex = "#E8EFE8"
    public static let paperRGB: (r: Double, g: Double, b: Double, a: Double) = (0.910, 0.937, 0.910, 1)

    /// Deeper paper for recessed panels.
    public static let paperDeepHex = "#D2DDD4"
    public static let paperDeepRGB: (r: Double, g: Double, b: Double, a: Double) = (0.824, 0.867, 0.831, 1)

    /// Elevated panel wash (light translucency intention).
    public static let panelHex = "#FAFCFA"
    public static let panelRGB: (r: Double, g: Double, b: Double, a: Double) = (0.980, 0.988, 0.980, 1)

    // MARK: - Accent

    /// Moss-teal accent — selection, primary CTA, focus.
    public static let accentHex = "#0F6B5C"
    public static let accentRGB: (r: Double, g: Double, b: Double, a: Double) = (0.059, 0.420, 0.361, 1)

    /// Soft accent wash for hover / chips.
    public static let accentSoftHex = "#C5E4DC"
    public static let accentSoftRGB: (r: Double, g: Double, b: Double, a: Double) = (0.773, 0.894, 0.863, 1)

    // MARK: - Atmosphere (gradient stops)

    public static let mistHex = "#B8D4C8"
    public static let mistRGB: (r: Double, g: Double, b: Double, a: Double) = (0.722, 0.831, 0.784, 1)

    public static let meadowHex = "#C9D9C4"
    public static let meadowRGB: (r: Double, g: Double, b: Double, a: Double) = (0.788, 0.851, 0.769, 1)

    // MARK: - Lines / feedback

    public static let lineHex = "#1A2421"
    /// Hairline at ~12% opacity of ink.
    public static let lineAlpha: Double = 0.12

    public static let dangerHex = "#9B3A2F"
    public static let dangerRGB: (r: Double, g: Double, b: Double, a: Double) = (0.608, 0.227, 0.184, 1)

    public static let focusRingHex = "#0F6B5C"
    public static let focusRingAlpha: Double = 0.35

    /// Ordered swatch list for galleries / tests.
    public static let paletteHexes: [String] = [
        inkHex, inkSoftHex, paperHex, paperDeepHex, panelHex,
        accentHex, accentSoftHex, mistHex, meadowHex, dangerHex,
    ]
}

#if canImport(SwiftUI)
import SwiftUI

extension LociColors {
    public static var ink: Color { Color(lociHex: inkHex) }
    public static var inkSoft: Color { Color(lociHex: inkSoftHex) }
    public static var inkInverse: Color { Color(lociHex: inkInverseHex) }
    public static var paper: Color { Color(lociHex: paperHex) }
    public static var paperDeep: Color { Color(lociHex: paperDeepHex) }
    public static var panel: Color { Color(lociHex: panelHex).opacity(0.82) }
    public static var accent: Color { Color(lociHex: accentHex) }
    public static var accentSoft: Color { Color(lociHex: accentSoftHex) }
    public static var mist: Color { Color(lociHex: mistHex) }
    public static var meadow: Color { Color(lociHex: meadowHex) }
    public static var line: Color { Color(lociHex: lineHex).opacity(lineAlpha) }
    public static var danger: Color { Color(lociHex: dangerHex) }
    public static var focusRing: Color { Color(lociHex: focusRingHex).opacity(focusRingAlpha) }
}

extension Color {
    /// Creates a Color from `#RRGGBB` or `#RRGGBBAA`.
    init(lociHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let hasAlpha = cleaned.count == 8
        let a = hasAlpha ? Double((value & 0xFF00_0000) >> 24) / 255 : 1
        let r = Double((value & 0x00FF_0000) >> 16) / 255
        let g = Double((value & 0x0000_FF00) >> 8) / 255
        let b = Double(value & 0x0000_00FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
#endif
