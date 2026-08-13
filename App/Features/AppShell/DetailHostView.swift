import SwiftUI
import LociCore
import LociDesignSystem

/// Center column — hosts the active destination (placeholders until feature PRs).
struct DetailHostView: View {
    let route: Route
    var services: AppServices?

    var body: some View {
        Group {
            switch route {
            case .daily:
                DestinationPlaceholderView(
                    route: .daily,
                    message: "Today’s note opens here (PR10). Deterministic path daily/YYYY-MM-DD.md."
                )
            case .search:
                DestinationPlaceholderView(
                    route: .search,
                    message: "Local index FTS (PR07/PR18). Reads IndexQuerying only — never blocks typing. Index never lives in the vault."
                )
            case .types:
                if let services {
                    TypeListView(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .types,
                        message: "Object type list (PR05). Schema under .loci/types/."
                    )
                }
            case .settings:
                if let services {
                    VaultSettingsView(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .settings,
                        message: "Vault root, local Documents fallback, and sync status (PR04 / PR21)."
                    )
                }
            case .designGallery:
                DesignGalleryView()
            case .object(let id):
                DestinationPlaceholderView(
                    route: .object(id),
                    message: "Object editor host (PR08+). id \(id.uuidString)"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { LociAtmosphereBackground() }
        .id(routeIdentity)
        .lociPanelTransition()
        .animation(LociMotion.panel, value: routeIdentity)
    }

    private var routeIdentity: String {
        switch route {
        case .daily: return "daily"
        case .search: return "search"
        case .types: return "types"
        case .settings: return "settings"
        case .designGallery: return "designGallery"
        case .object(let id): return "object-\(id.uuidString)"
        }
    }
}

/// Shared placeholder body for destinations not yet implemented.
struct DestinationPlaceholderView: View {
    let route: Route
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(route.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(route.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text(message)
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            LociEmptyState(
                title: "\(route.title) placeholder",
                message: "App shell navigation is live. Feature content arrives in a later PR.",
                systemImage: route.systemImage
            )
            .padding(.top, LociSpacing.stack(.md))
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
