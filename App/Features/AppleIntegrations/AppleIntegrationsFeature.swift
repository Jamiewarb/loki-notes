import SwiftUI
import LociCore

/// Public entry for Apple Calendar / Reminders integrations (PR31).
///
/// Event list is inspector chrome (never rewrites daily markdown). Meeting create
/// and Reminders sync go through `AppleIntegrationServing` + ObjectServing.
enum AppleIntegrationsFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        RemindersSyncView(services: services)
    }

    @MainActor
    static func dailyEvents(services: AppServices, day: Date) -> some View {
        DailyEventsPanel(services: services, day: day)
    }

    @MainActor
    static func settingsSection(services: AppServices) -> some View {
        RemindersSyncView(services: services, compact: true)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        RemindersSyncView(services: services)
    }
}
