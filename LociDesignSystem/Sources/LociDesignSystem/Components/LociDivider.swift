#if canImport(SwiftUI)
import SwiftUI

/// Hairline divider using the design-system line token.
public struct LociDivider: View {
    private let vertical: Bool

    public init(vertical: Bool = false) {
        self.vertical = vertical
    }

    public var body: some View {
        if vertical {
            Rectangle()
                .fill(LociColors.line)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
        } else {
            Rectangle()
                .fill(LociColors.line)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }
}
#endif
