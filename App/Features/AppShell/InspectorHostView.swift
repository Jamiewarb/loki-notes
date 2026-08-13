import SwiftUI
import LociCore
import LociDesignSystem

/// Trailing column (macOS) / sheet slot (iOS) — properties, backlinks, outline later.
struct InspectorHostView: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Inspector")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text(title)
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text(blurb)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            LociDivider()

            Text(hint)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
    }

    private var title: String {
        switch route {
        case .daily: return "Created today"
        case .search: return "Filters"
        case .types: return "Type metadata"
        case .settings: return "Sync status"
        case .designGallery: return "Tokens"
        case .object: return "Properties"
        }
    }

    private var blurb: String {
        switch route {
        case .daily:
            return "Outline stays light. “Created today” (PR11) is an inspector panel from the index — never rewritten into this daily .md."
        case .search:
            return "Recent queries and filter chips will appear here (PR18)."
        case .types:
            return "Property defs for the selected type (PR13)."
        case .settings:
            return "iCloud vs local Documents — index never stored in the vault."
        case .designGallery:
            return "editorial-sage · Fraunces + Source Sans 3 · moss-teal accent."
        case .object:
            return "Backlinks, properties, and outline for the open object."
        }
    }

    private var hint: String {
        "macOS: trailing split column · iOS: sheet / secondary stack (adapted in AppShellView)."
    }
}
