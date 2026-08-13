#if canImport(SwiftUI)
import SwiftUI

/// Sidebar / list row with selection and focus states.
public struct LociListRow: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let isSelected: Bool
    private let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isSelected: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: LociSpacing.stack(.md)) {
                if let systemImage {
                    LociIcon(systemImage, size: 16)
                        .foregroundStyle(isSelected ? LociColors.inkInverse : LociColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LociTypography.font(.headline))
                        .foregroundStyle(isSelected ? LociColors.inkInverse : LociColors.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(isSelected ? LociColors.inkInverse.opacity(0.85) : LociColors.inkSoft)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LociSpacing.stack(.md))
            .padding(.vertical, LociSpacing.stack(.sm) + 2)
            .background(
                RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous)
                    .fill(isSelected ? LociColors.accent : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
#endif
