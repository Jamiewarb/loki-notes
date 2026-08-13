import SwiftUI
import LociCore
import LociDesignSystem

/// App shell root — macOS split mental model; iOS tab/stack adaptation.
/// Features talk through `Navigating` / `Route`; this view owns chrome only.
struct AppShellView: View {
    @Bindable var services: AppServices
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var inspectorPresented = false

    var body: some View {
        #if os(macOS)
        macSplitShell
        #else
        iosTabShell
        #endif
    }

    // MARK: - macOS (sidebar | detail | inspector)

    #if os(macOS)
    private var macSplitShell: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(services: services)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } content: {
            DetailHostView(route: services.selectedRoute, services: services)
                .navigationTitle(services.selectedRoute.title)
        } detail: {
            InspectorHostView(route: services.selectedRoute, services: services)
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(LociColors.accent)
        .background { LociAtmosphereBackground() }
    }
    #endif

    // MARK: - iOS (daily-first tabs + stack; inspector as sheet)

    #if !os(macOS)
    private var iosTabShell: some View {
        TabView(selection: iosTabBinding) {
            iosStack(for: .daily)
                .tabItem { Label("Daily", systemImage: Route.daily.systemImage) }
                .tag(AppRoute.daily)

            iosStack(for: .tasks)
                .tabItem { Label("Tasks", systemImage: Route.tasks.systemImage) }
                .tag(AppRoute.tasks)

            iosStack(for: .search)
                .tabItem { Label("Search", systemImage: Route.search.systemImage) }
                .tag(AppRoute.search)

            iosStack(for: .types)
                .tabItem { Label("Types", systemImage: Route.types.systemImage) }
                .tag(AppRoute.types)

            NavigationStack {
                settingsRoot
            }
            .tabItem { Label("Settings", systemImage: Route.settings.systemImage) }
            .tag(AppRoute.settings)
        }
        .tint(LociColors.accent)
        .sheet(isPresented: $inspectorPresented) {
            NavigationStack {
                InspectorHostView(route: services.selectedRoute, services: services)
                    .navigationTitle("Inspector")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { inspectorPresented = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func iosStack(for destination: AppRoute) -> some View {
        NavigationStack {
            DetailHostView(route: destination.route, services: services)
                .navigationTitle(destination.title)
                .toolbar { inspectorToolbar }
        }
    }

    private var settingsRoot: some View {
        List {
            Section("Space") {
                NavigationLink {
                    DetailHostView(route: .settings, services: services)
                        .navigationTitle("Settings")
                } label: {
                    Label("Vault & sync", systemImage: Route.settings.systemImage)
                }
            }
            Section("Studio") {
                NavigationLink {
                    TagsFeature.browse(services: services)
                        .navigationTitle("Tags")
                        .onAppear {
                            Task { await services.open(route: .tags) }
                        }
                } label: {
                    Label("Tags", systemImage: Route.tags.systemImage)
                }
                NavigationLink {
                    GraphFeature.destination(services: services)
                        .navigationTitle("Graph")
                        .onAppear {
                            Task { await services.open(route: .graph) }
                        }
                } label: {
                    Label("Graph", systemImage: Route.graph.systemImage)
                }
                NavigationLink {
                    CalendarFeature.destination(services: services)
                        .navigationTitle("Calendar")
                        .onAppear {
                            Task { await services.open(route: .calendar) }
                        }
                } label: {
                    Label("Calendar", systemImage: Route.calendar.systemImage)
                }
                NavigationLink {
                    CaptureFeature.destination(services: services)
                        .navigationTitle("Capture")
                        .onAppear {
                            Task { await services.open(route: .capture) }
                        }
                } label: {
                    Label("Capture", systemImage: Route.capture.systemImage)
                }
                NavigationLink {
                    DesignGalleryView()
                        .navigationTitle("Design")
                        .onAppear {
                            Task { await services.open(route: .designGallery) }
                        }
                } label: {
                    Label("Design gallery", systemImage: Route.designGallery.systemImage)
                }
            }
            Section("Pinned") {
                ForEach(PinnedItemStub.placeholders) { pin in
                    Label(pin.title, systemImage: "pin")
                        .foregroundStyle(LociColors.inkSoft)
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar { inspectorToolbar }
        .onAppear {
            // Keep Settings tab selection when pushing Design gallery.
            if services.selectedRoute.isPrimaryDestination,
               services.selectedRoute != .settings
            {
                Task { await services.open(route: .settings) }
            }
        }
    }

    private var inspectorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                inspectorPresented = true
            } label: {
                Image(systemName: "sidebar.trailing")
            }
            .accessibilityLabel("Open inspector")
        }
    }

    private var iosTabBinding: Binding<AppRoute> {
        Binding(
            get: {
                let mapped = AppRoute(route: services.selectedRoute)
                if mapped == .designGallery || mapped == .tags || mapped == .graph
                    || mapped == .calendar
                {
                    return .settings
                }
                return mapped ?? .daily
            },
            set: { route in
                Task {
                    if route == .search {
                        await services.openSearch()
                    } else {
                        await services.open(route: route.route)
                    }
                }
            }
        )
    }
    #endif
}
