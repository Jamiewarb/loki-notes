#if canImport(SwiftUI)
import SwiftUI
import LociDesignSystem
import LociMarkdown

/// `/` slash menu for inserting / converting block types (PR09).
struct SlashMenuView: View {
    let query: String
    let onSelect: (SlashBlockKind) -> Void

    private var filtered: [SlashBlockKind] {
        SlashBlockKind.allCases.filter { $0.matches(query: query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Insert block")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .padding(.horizontal, LociSpacing.stack(.md))
                .padding(.vertical, LociSpacing.stack(.sm))

            ForEach(filtered, id: \.self) { kind in
                Button {
                    onSelect(kind)
                } label: {
                    HStack {
                        Text(kind.title)
                            .font(LociTypography.font(.body))
                            .foregroundStyle(LociColors.ink)
                        Spacer(minLength: 0)
                        Text("/\(kind.slashToken)")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                    .padding(.horizontal, LociSpacing.stack(.md))
                    .padding(.vertical, LociSpacing.stack(.sm))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if filtered.isEmpty {
                Text("No matching blocks")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .padding(LociSpacing.stack(.md))
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
        .background(LociColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous)
                .stroke(LociColors.line, lineWidth: 1)
        )
        .accessibilityIdentifier("slash-menu")
    }
}
#endif
