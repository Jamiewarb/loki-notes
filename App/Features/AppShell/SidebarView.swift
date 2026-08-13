import SwiftUI
import LociCore
import LociDesignSystem

/// Left column: brand-forward Loci mark, primary destinations, type entries, tooling.
struct SidebarView: View {
    @Bindable var services: AppServices
    @State private var schemaTypes: [ObjectType] = []

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            brandHeader

            VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                sectionLabel("Navigate")
                ForEach(AppRoute.primary) { destination in
                    LociListRow(
                        title: destination.title,
                        subtitle: destination.subtitle,
                        systemImage: destination.systemImage,
                        isSelected: isSelected(destination)
                    ) {
                        Task {
                            if destination == .types {
                                services.focusedTypeID = nil
                            }
                            if destination == .search {
                                await services.openSearch()
                            } else {
                                await services.open(route: destination.route)
                            }
                        }
                    }
                }
                LociButton("New Page", style: .secondary) {
                    Task {
                        do {
                            _ = try await services.createPage(title: "Untitled")
                        } catch {
                            await services.open(route: .settings)
                        }
                    }
                }
                .padding(.top, LociSpacing.stack(.xs))
            }

            VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                sectionLabel("Types")
                if schemaTypes.isEmpty {
                    Text("Open vault to list types")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                        .padding(.vertical, LociSpacing.stack(.xs))
                } else {
                    ForEach(schemaTypes, id: \.id.rawValue) { type in
                        LociListRow(
                            title: type.name,
                            subtitle: ".\(type.id.rawValue)",
                            systemImage: type.icon,
                            isSelected: services.selectedRoute == .types
                                && services.focusedTypeID == type.id
                        ) {
                            Task { await services.openTypeDashboard(type.id) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                sectionLabel("Pinned")
                ForEach(PinnedItemStub.placeholders) { pin in
                    LociListRow(
                        title: pin.title,
                        subtitle: pin.subtitle,
                        systemImage: "pin",
                        isSelected: false
                    ) {
                        // Stub — pin navigation lands with collections.
                    }
                    .opacity(0.72)
                }
            }

            Spacer(minLength: LociSpacing.stack(.md))

            VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                sectionLabel("Studio")
                ForEach(AppRoute.tooling) { destination in
                    LociListRow(
                        title: destination.title,
                        subtitle: destination.subtitle,
                        systemImage: destination.systemImage,
                        isSelected: isSelected(destination)
                    ) {
                        Task {
                            if destination == .tags {
                                services.focusedTag = nil
                            }
                            await services.open(route: destination.route)
                        }
                    }
                }
            }
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.soft)
        .task { await reloadTypes() }
        .onChange(of: services.selectedRoute) { _, _ in
            Task { await reloadTypes() }
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
            Text(LociDesignSystem.brandName)
                .font(LociTypography.font(.brand))
                .tracking(LociTypography.brandTracking * LociTypography.brandSize)
                .foregroundStyle(LociColors.ink)
                .lociAppear(.brand)
            Text(services.spaceName == LociDesignSystem.brandName
                 ? LociDesignSystem.tagline
                 : services.spaceName)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .lociAppear(.soft)
            SyncStatusFeature.chip(services: services)
                .padding(.top, LociSpacing.stack(.xs))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(LociDesignSystem.brandName) app shell")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(LociTypography.font(.overline))
            .tracking(0.08)
            .foregroundStyle(LociColors.inkSoft)
            .padding(.top, LociSpacing.stack(.sm))
    }

    private func isSelected(_ destination: AppRoute) -> Bool {
        if destination == .types {
            return services.selectedRoute == .types && services.focusedTypeID == nil
        }
        if destination == .tags {
            return services.selectedRoute == .tags
        }
        return AppRoute(route: services.selectedRoute) == destination
    }

    private func reloadTypes() async {
        do {
            schemaTypes = try await services.schema.allTypes()
        } catch {
            schemaTypes = []
        }
    }
}
