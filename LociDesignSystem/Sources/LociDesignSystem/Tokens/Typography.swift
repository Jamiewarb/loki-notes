/// Typography tokens — expressive editorial display + readable body.
/// Font family names mirror Google Fonts / DevHarness CSS (`Fraunces`, `Source Sans 3`).
/// Sizes are portable Doubles for Linux tests.
public enum LociTypography: Sendable {
    public static let displayFamily = "Fraunces"
    public static let bodyFamily = "Source Sans 3"
    public static let displayFallback = "Georgia"
    public static let bodyFallback = "Helvetica Neue"

    public static let brandSize: Double = 44
    public static let displaySize: Double = 28
    public static let titleSize: Double = 22
    public static let headlineSize: Double = 17
    public static let bodySize: Double = 16
    public static let calloutSize: Double = 14
    public static let captionSize: Double = 12
    public static let overlineSize: Double = 11

    public static let brandTracking: Double = -0.03
    public static let overlineTracking: Double = 0.08
    public static let bodyLineHeightMultiple: Double = 1.45

    public enum Role: String, CaseIterable, Sendable {
        case brand
        case display
        case title
        case headline
        case body
        case callout
        case caption
        case overline
    }

    public static func size(for role: Role) -> Double {
        switch role {
        case .brand: return brandSize
        case .display: return displaySize
        case .title: return titleSize
        case .headline: return headlineSize
        case .body: return bodySize
        case .callout: return calloutSize
        case .caption: return captionSize
        case .overline: return overlineSize
        }
    }

    public static func isDisplayRole(_ role: Role) -> Bool {
        switch role {
        case .brand, .display, .title: return true
        case .headline, .body, .callout, .caption, .overline: return false
        }
    }

    /// SwiftUI `Font.custom(_:size:relativeTo:)` text-style name (Linux-testable).
    /// Numeric `size(for:)` values remain the unscaled defaults.
    public static let usesDynamicTypeRelativeTo = true

    public static func dynamicTypeTextStyleName(for role: Role) -> String {
        switch role {
        case .brand: return "largeTitle"
        case .display: return "title"
        case .title: return "title2"
        case .headline: return "headline"
        case .body: return "body"
        case .callout: return "callout"
        case .caption, .overline: return "caption"
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension LociTypography {
    /// Prefer custom faces when bundled. `relativeTo:` lets Dynamic Type scale
    /// from the numeric token size (the unscaled default).
    public static func textStyle(for role: Role) -> Font.TextStyle {
        switch role {
        case .brand: return .largeTitle
        case .display: return .title
        case .title: return .title2
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .caption, .overline: return .caption
        }
    }

    public static func font(_ role: Role, weight: Font.Weight = .regular) -> Font {
        let size = size(for: role)
        let family = isDisplayRole(role) ? displayFamily : bodyFamily
        let custom = Font.custom(family, size: CGFloat(size), relativeTo: textStyle(for: role))
        // `.weight` on custom fonts is best-effort.
        switch role {
        case .brand:
            return custom.weight(weight == .regular ? .bold : weight)
        case .display, .title, .headline:
            return custom.weight(weight == .regular ? .semibold : weight)
        case .body, .callout:
            return custom.weight(weight)
        case .caption, .overline:
            return custom.weight(weight == .regular ? .medium : weight)
        }
    }
}
#endif
