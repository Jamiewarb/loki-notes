/// Spacing scale (points). Linux-testable Doubles; SwiftUI helpers when available.
public enum LociSpacing: Sendable {
    public static let xxs: Double = 2
    public static let xs: Double = 4
    public static let sm: Double = 8
    public static let md: Double = 12
    public static let lg: Double = 16
    public static let xl: Double = 24
    public static let xxl: Double = 32
    public static let xxxl: Double = 48

    /// Canonical ascending scale for tests and galleries.
    public static let scale: [Double] = [xxs, xs, sm, md, lg, xl, xxl, xxxl]

    public enum Token: String, CaseIterable, Sendable {
        case xxs, xs, sm, md, lg, xl, xxl, xxxl

        public var value: Double {
            switch self {
            case .xxs: return LociSpacing.xxs
            case .xs: return LociSpacing.xs
            case .sm: return LociSpacing.sm
            case .md: return LociSpacing.md
            case .lg: return LociSpacing.lg
            case .xl: return LociSpacing.xl
            case .xxl: return LociSpacing.xxl
            case .xxxl: return LociSpacing.xxxl
            }
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

extension LociSpacing {
    public static func stack(_ token: Token) -> CGFloat { CGFloat(token.value) }
}
#endif
