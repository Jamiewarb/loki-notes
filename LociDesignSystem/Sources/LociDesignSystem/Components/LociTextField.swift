#if canImport(SwiftUI)
import SwiftUI

/// Text field styled to the Loci paper/ink system.
public struct LociTextField: View {
    private let title: String
    private let placeholder: String
    @Binding private var text: String

    public init(_ title: String, text: Binding<String>, placeholder: String = "") {
        self.title = title
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
            Text(title)
                .font(LociTypography.font(.overline))
                .tracking(LociTypography.overlineTracking * LociTypography.overlineSize)
                .textCase(.uppercase)
                .foregroundStyle(LociColors.inkSoft)

            TextField(placeholder, text: $text)
                .font(LociTypography.font(.body))
                .padding(.horizontal, LociSpacing.stack(.md))
                .padding(.vertical, LociSpacing.stack(.md))
                .background(LociColors.panel)
                .clipShape(RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous)
                        .strokeBorder(LociColors.line, lineWidth: 1)
                )
        }
    }
}
#endif
