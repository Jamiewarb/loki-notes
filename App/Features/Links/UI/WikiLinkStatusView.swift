import SwiftUI
import LociCore
import LociDesignSystem
import LociMarkdown

/// Compact chips under a block showing resolved vs broken wiki-links.
struct WikiLinkStatusView: View {
    var styles: [WikiLinkStyle]
    var onOpen: ((ObjectID) -> Void)?

    var body: some View {
        if styles.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(styles.enumerated()), id: \.offset) { _, style in
                    HStack(spacing: 6) {
                        Text(style.displayText)
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(style.isBroken ? LociColors.danger : LociColors.accent)
                            .underline(style.isBroken, pattern: .dash)
                        if style.isBroken {
                            Text("broken")
                                .font(LociTypography.font(.caption))
                                .foregroundStyle(LociColors.danger)
                        }
                    }
                    .accessibilityIdentifier(
                        style.isBroken
                            ? "wiki-style-broken-\(style.link.target)"
                            : "wiki-style-ok-\(style.link.target)"
                    )
                }
            }
            .accessibilityIdentifier("wiki-link-status")
        }
    }
}
