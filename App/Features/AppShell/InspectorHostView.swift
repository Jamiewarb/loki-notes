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
                    VStack(alignment: .leading, spacing: LociSpacing.stack(.xl)) {
                        CreatedTodayPanel(
                            services: services,
                            day: services.inspectedDailyDay
                        )
                        TasksFeature.openTasksPanel(
                            services: services,
                            day: services.inspectedDailyDay
                        )
                    }
                    .padding(LociSpacing.stack(.lg))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LociColors.panel.opacity(0.55))
                .lociAppear(.panel)
            } else if case .tasks = route {
                ScrollView {
                    VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                        Text("Tasks")
                            .font(LociTypography.font(.overline))
                            .tracking(0.08)
                            .foregroundStyle(LociColors.inkSoft)
                        Text(
                            "Today = daily note tasks. Open = incomplete anywhere. Checkboxes write vault markdown via save → index."
                        )
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.inkSoft)
                    }
                    .padding(LociSpacing.stack(.lg))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LociColors.panel.opacity(0.55))
                .lociAppear(.panel)
            } else if case .object(let id) = route {
                ScrollView {
                    VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
                        PropertiesFeature.editor(services: services, objectID: id)
                        TagsFeature.objectTags(services: services, objectID: id)
                        LinksFeature.backlinks(services: services, objectID: id)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if case .search = route {
                SearchInspectorView(services: services)
            } else if case .graph = route {
                GraphFeature.inspector(services: services)
            } else if case .calendar = route {
                CalendarFeature.inspector(services: services)
            } else if case .tags = route {
                ScrollView {
                    VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                        Text("Tag aliases")
                            .font(LociTypography.font(.overline))
                            .tracking(0.08)
                            .foregroundStyle(LociColors.inkSoft)
                        Text(
                            "Aliases live in `.loci/space.json` (`tagAliases`). Queries expand them so #wellness finds #health."
                        )
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.inkSoft)
                    }
                    .padding(LociSpacing.stack(.lg))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LociColors.panel.opacity(0.55))
                .lociAppear(.panel)
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
        case .daily: return "Created today · Open tasks"
        case .tasks: return "Aggregation"
        case .search: return "Filters"
        case .types: return "Type metadata"
        case .settings: return "Sync status"
        case .designGallery: return "Tokens"
        case .tags: return "Aliases"
        case .graph: return "Caps · navigation"
        case .calendar: return "Dots · daily jump"
        case .object: return "Properties"
        }
    }

    private var blurb: String {
        switch route {
        case .daily:
            return "Created today + open tasks are index-only — never rewritten into the daily .md."
        case .tasks:
            return "Today / Open lists read IndexQuerying; toggles persist through ObjectServing.save."
        case .search:
            return "Recent queries and type filters — IndexQuerying.search only."
        case .types:
            return "Open a type dashboard to edit property defs and templates."
        case .settings:
            return "iCloud vs local Documents — index never stored in the vault."
        case .designGallery:
            return "editorial-sage · Fraunces + Source Sans 3 · moss-teal accent."
        case .tags:
            return "Tag aliases in space.json expand queries across spellings."
        case .graph:
            return "Graph reads the links table via IndexQuerying; node tap opens via Navigating."
        case .calendar:
            return "Calendar dots are index-derived; day select opens daily/YYYY-MM-DD.md."
        case .object:
            return "Properties, object tags, and backlinks from the local index."
        }
    }

    private var hint: String {
        "macOS: trailing split column · iOS: sheet / secondary stack (adapted in AppShellView)."
    }
}
