import Foundation

/// Read Apple Calendar (or fake) events for a day — no vault writes (PR31).
public protocol AppleCalendarServing: Sendable {
    func authorizationStatus() -> AppleAuthStatus
    func events(on day: Date, calendar: Calendar) async throws -> [AppleCalendarEvent]
}

/// Read/write Apple Reminders (or fake) — optional task sync (PR31).
public protocol AppleRemindersServing: Sendable {
    func authorizationStatus() -> AppleAuthStatus
    func reminders(dueOn day: Date?, calendar: Calendar) async throws -> [AppleReminderItem]
    func upsert(_ item: AppleReminderItem) async throws
}

/// Calendar events on daily + Meeting create + optional Reminders sync (PR31).
///
/// Event list is **UI chrome only** — listing events must never rewrite daily markdown.
/// Creating a Meeting is a vault write via `ObjectServing` under `objects/meeting/`.
/// Reminders pull/push runs only on an explicit user action when sync is enabled.
public protocol AppleIntegrationServing: AppleCalendarServing, AppleRemindersServing, Sendable {
    func loadSettings() async throws -> AppleIntegrationSettings
    func saveSettings(_ settings: AppleIntegrationSettings) async throws

    /// Events for the inspected daily day (chrome — no vault write).
    func eventsForDaily(day: Date, calendar: Calendar) async throws -> [AppleCalendarEvent]

    /// Idempotent: reuse Meeting with property `event-id` == event.id when present.
    func createMeeting(
        from event: AppleCalendarEvent,
        using objects: any ObjectServing,
        schema: any SchemaServing,
        index: any IndexQuerying
    ) async throws -> LociObjectMeta

    func existingMeeting(
        forEventID eventID: String,
        index: any IndexQuerying
    ) async throws -> LociObjectMeta?

    /// Pull due reminders into today’s daily as `- [ ]` lines via ObjectServing.
    /// No-op (returns 0) when `remindersSyncEnabled` is false.
    @discardableResult
    func pullRemindersIntoToday(
        day: Date,
        calendar: Calendar,
        daily: any DailyNoteServing,
        objects: any ObjectServing
    ) async throws -> Int

    /// Push incomplete IndexedTasks from today’s daily into Reminders (fake/EventKit).
    @discardableResult
    func pushOpenTasksToReminders(
        day: Date,
        calendar: Calendar,
        index: any IndexQuerying
    ) async throws -> Int
}
