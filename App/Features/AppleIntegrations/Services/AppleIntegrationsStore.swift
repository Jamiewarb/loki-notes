import Foundation
import LociCore

/// Thin feature-local facade over `AppleIntegrationServing` (PR31).
@MainActor
final class AppleIntegrationsStore {
    private let apple: any AppleIntegrationServing

    init(apple: any AppleIntegrationServing) {
        self.apple = apple
    }

    func calendarAuthorizationStatus() -> AppleAuthStatus {
        apple.calendarAuthorizationStatus()
    }

    func requestCalendarAccess() async -> AppleAuthStatus {
        await apple.requestCalendarAccess()
    }

    func remindersAuthorizationStatus() -> AppleAuthStatus {
        apple.remindersAuthorizationStatus()
    }

    func requestRemindersAccess() async -> AppleAuthStatus {
        await apple.requestRemindersAccess()
    }

    func loadSettings() async throws -> AppleIntegrationSettings {
        try await apple.loadSettings()
    }

    func saveSettings(_ settings: AppleIntegrationSettings) async throws {
        try await apple.saveSettings(settings)
    }

    func eventsForDaily(day: Date, calendar: Calendar = .current) async throws -> [AppleCalendarEvent] {
        try await apple.eventsForDaily(day: day, calendar: calendar)
    }

    func createMeeting(
        from event: AppleCalendarEvent,
        using objects: any ObjectServing,
        schema: any SchemaServing,
        index: any IndexQuerying
    ) async throws -> LociObjectMeta {
        try await apple.createMeeting(from: event, using: objects, schema: schema, index: index)
    }

    @discardableResult
    func pullRemindersIntoToday(
        day: Date,
        calendar: Calendar = .current,
        daily: any DailyNoteServing,
        objects: any ObjectServing
    ) async throws -> Int {
        try await apple.pullRemindersIntoToday(
            day: day,
            calendar: calendar,
            daily: daily,
            objects: objects
        )
    }

    @discardableResult
    func pushOpenTasksToReminders(
        day: Date,
        calendar: Calendar = .current,
        index: any IndexQuerying
    ) async throws -> Int {
        try await apple.pushOpenTasksToReminders(day: day, calendar: calendar, index: index)
    }
}
