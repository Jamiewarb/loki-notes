/// Corner radius tokens.
public enum LociRadius: Sendable {
    public static let none: Double = 0
    public static let sm: Double = 6
    public static let md: Double = 10
    public static let lg: Double = 14
    public static let xl: Double = 20

    public static let scale: [Double] = [none, sm, md, lg, xl]
}

#if canImport(SwiftUI)
import SwiftUI

extension LociRadius {
    public static var control: CGFloat { CGFloat(md) }
    public static var panel: CGFloat { CGFloat(lg) }
}
#endif
