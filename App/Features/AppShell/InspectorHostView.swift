import SwiftUI
import LociCore
import LociDesignSystem

/// Trailing column (macOS) / sheet slot (iOS) — properties, backlinks, outline later.
struct InspectorHostView: View {
    let route: Route
    var services: AppServices

    var body: some View {
        Group {
            if case .daily = route {
                ScrollView {
                    CreatedTodayPanel(
                        services: services,
                        day: services.inspectedDailyDay
                    )
                    .padding(LociSpacing.stack(.lg))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LociColors.panel.opacity(0.55))
                .lociAppear(.panel)
            } else if case .object(let id) = route {
                ScrollView {
                    PropertiesFeature.editor(services: services, objectID: id)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if case .types = route, let typeID = services.focusedTypeID {
                ScrollView {
                    VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
                        PropertiesFeature.defsEditor(services: services, typeID: typeID)
                        TemplatesFeature.picker(services: services, typeID: typeID)
                    }
                    .padding(LociSpacing.stack(.lg))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LociColors.panel.opacity(0.55))
                .lociAppear(.panel)
            } else {
                placeholderBody
            }
        }
    }

    private var placeholderBody: some View {
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
            return "Created today is index-only — never rewritten into the daily .md."
        case .search:
            return "Recent queries and filter chips will appear here (PR18)."
        case .types:
            return "Open a type dashboard to edit property defs and templates."
        case .settings:
            return "iCloud vs local Documents — index never stored in the vault."
        case .designGallery:
            return "editorial-sage · Fraunces + Source Sans 3 · moss-teal accent."
        case .object:
            return "Property values persist in YAML frontmatter on save."
        }
    }

    private var hint: String {
        "macOS: trailing split column · iOS: sheet / secondary stack (adapted in AppShellView)."
    }
}
