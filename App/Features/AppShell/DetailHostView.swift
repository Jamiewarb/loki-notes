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
                if let services {
                    DailyNoteFeature.root(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .daily,
                        message: "Today’s note opens here (PR10). Deterministic path daily/YYYY-MM-DD.md."
                    )
                }
            case .tasks:
                if let services {
                    TasksFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .tasks,
                        message: "Today / Open tasks from the local index (PR19). Toggles persist via ObjectServing.save."
                    )
                }
            case .search:
                if let services {
                    SearchFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .search,
                        message: "Local index FTS (PR07/PR18). Reads IndexQuerying only — never blocks typing. Index never lives in the vault."
                    )
                }
            case .types:
                if let services {
                    ObjectTypesFeature.root(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .types,
                        message: "Object type list + dashboards (PR12). Schema under .loci/types/."
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
            case .tags:
                if let services {
                    TagsFeature.browse(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .tags,
                        message: "Cross-type #tags browse (PR17). Index projection only."
                    )
                }
            case .graph:
                if let services {
                    GraphFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .graph,
                        message: "Link graph from IndexQuerying.graph (PR24). Cap + type filter."
                    )
                }
            case .calendar:
                if let services {
                    CalendarFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .calendar,
                        message: "Month/week calendar around daily notes (PR25). Index dots · jump to daily."
                    )
                }
            case .capture:
                if let services {
                    CaptureFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .capture,
                        message: "Quick capture (PR26). Extensions enqueue .loci/inbox/; app drains → today / typed object."
                    )
                }
            case .importExport:
                if let services {
                    ImportExportFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .importExport,
                        message: "Import (PR27). Markdown folder · Obsidian · Capacities — dry-run then apply into the vault."
                    )
                }
            case .typeConvert:
                if let services {
                    TypeConversionFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .typeConvert,
                        message: "Type conversion (PR28). Property map · move objects/<type>/ · ObjectID stable."
                    )
                }
            case .ai:
                if let services {
                    AIFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .ai,
                        message: "AI assist (PR30). Summarize · rewrite · translate · autofill — on-device / BYOK opt-in."
                    )
                }
            case .apple:
                if let services {
                    AppleIntegrationsFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .apple,
                        message: "Apple Calendar / Reminders (PR31). Event chrome · Meeting objects · optional Reminders sync."
                    )
                }
            case .safari:
                if let services {
                    SafariClipperFeature.destination(services: services)
                } else {
                    DestinationPlaceholderView(
                        route: .safari,
                        message: "Safari clipper (PR32). Selection/page → today or Weblink via .loci/inbox/."
                    )
                }
            case .object(let id):
                if let services {
                    ObjectEditorFeature.editor(services: services, objectID: id)
                } else {
                    DestinationPlaceholderView(
                        route: .object(id),
                        message: "Object editor host (PR08+). id \(id.uuidString)"
                    )
                }
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
        case .tasks: return "tasks"
        case .search: return "search"
        case .types: return "types"
        case .settings: return "settings"
        case .designGallery: return "designGallery"
        case .tags: return "tags-\(services?.focusedTag ?? "all")"
        case .graph: return "graph"
        case .calendar: return "calendar"
        case .capture: return "capture"
        case .importExport: return "importExport"
        case .typeConvert: return "typeConvert"
        case .ai: return "ai"
        case .apple: return "apple"
        case .safari: return "safari"
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
