#if canImport(SwiftUI)
import SwiftUI

/// Empty / placeholder surface — one purpose, brand-aware, not a card heap.
public struct LociEmptyState: View {
    private let title: String
    private let message: String
    private let systemImage: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        title: String,
        message: String,
        systemImage: String = "tray",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: LociSpacing.stack(.lg)) {
            LociIcon(systemImage, size: 36)
                .foregroundStyle(LociColors.accent)
                .lociAppear(.soft)

            Text(title)
                .font(LociTypography.font(.title))
                .foregroundStyle(LociColors.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if let actionTitle, let action {
                LociButton(actionTitle, style: .primary, action: action)
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(LociSpacing.stack(.xl))
    }
}
#endif
