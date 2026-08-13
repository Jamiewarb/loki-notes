#if canImport(SwiftUI)
import SwiftUI

/// Primary interactive control — solid, quiet, brand-aligned.
public struct LociButton: View {
    public enum Style: Sendable {
        case primary
        case secondary
        case quiet
        case destructive
    }

    private let title: String
    private let style: Style
    private let systemImage: String?
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: LociSpacing.stack(.sm)) {
                if let systemImage {
                    LociIcon(systemImage, size: 14)
                }
                Text(title)
                    .font(LociTypography.font(.headline))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LociSpacing.stack(.md))
            .padding(.horizontal, LociSpacing.stack(.lg))
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous)
                    .strokeBorder(border, lineWidth: style == .secondary ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var background: Color {
        switch style {
        case .primary: return LociColors.accent
        case .secondary: return LociColors.panel
        case .quiet: return LociColors.accentSoft.opacity(0.55)
        case .destructive: return LociColors.danger.opacity(0.12)
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return LociColors.inkInverse
        case .secondary, .quiet: return LociColors.ink
        case .destructive: return LociColors.danger
        }
    }

    private var border: Color {
        switch style {
        case .secondary: return LociColors.line
        default: return .clear
        }
    }
}
#endif
