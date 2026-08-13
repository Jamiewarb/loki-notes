#if canImport(SwiftUI)
import SwiftUI

/// Thin SF Symbol wrapper with consistent sizing and accessibility.
public struct LociIcon: View {
    private let systemName: String
    private let size: CGFloat
    private let weight: Font.Weight

    public init(_ systemName: String, size: CGFloat = 16, weight: Font.Weight = .semibold) {
        self.systemName = systemName
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .accessibilityHidden(true)
    }
}
#endif
