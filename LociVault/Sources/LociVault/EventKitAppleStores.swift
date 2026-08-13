#if canImport(EventKit)
import EventKit
import Foundation
import LociCore

/// Real Calendar store. Maps `EKEvent` → `AppleCalendarEvent` (PR36).
///
/// Denied / restricted / write-only → empty list, no crash. Never writes vault files.
public final class EventKitCalendarStore: AppleCalendarServing, @unchecked Sendable {
    private let store = EKEventStore()

    public init() {}

    public func calendarAuthorizationStatus() -> AppleAuthStatus {
        AppleAuthStatusMapper.fromEventKitRawValue(
            EKEventStore.authorizationStatus(for: .event).rawValue
        )
    }

    public func requestCalendarAccess() async -> AppleAuthStatus {
        let current = calendarAuthorizationStatus()
        if current == .authorized || current == .denied || current == .unavailable {
            return current
        }
        do {
            let granted: Bool
            if #available(iOS 17.0, macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    public func events(on day: Date, calendar: Calendar) async throws -> [AppleCalendarEvent] {
        var status = calendarAuthorizationStatus()
        if status == .notDetermined {
            status = await requestCalendarAccess()
        }
        guard status == .authorized else { return [] }
        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)
        return ekEvents.compactMap { EventKitBridge.mapEvent($0) }
            .sorted { $0.start < $1.start }
    }
}

/// Real Reminders store. Maps `EKReminder` → `AppleReminderItem` (PR36).
public final class EventKitRemindersStore: AppleRemindersServing, @unchecked Sendable {
    private let store = EKEventStore()

    public init() {}

    public func remindersAuthorizationStatus() -> AppleAuthStatus {
        AppleAuthStatusMapper.fromEventKitRawValue(
            EKEventStore.authorizationStatus(for: .reminder).rawValue
        )
    }

    public func requestRemindersAccess() async -> AppleAuthStatus {
        let current = remindersAuthorizationStatus()
        if current == .authorized || current == .denied || current == .unavailable {
            return current
        }
        do {
            let granted: Bool
            if #available(iOS 17.0, macOS 14.0, *) {
                granted = try await store.requestFullAccessToReminders()
            } else {
                granted = try await store.requestAccess(to: .reminder)
            }
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    public func reminders(dueOn day: Date?, calendar: Calendar) async throws -> [AppleReminderItem] {
        var status = remindersAuthorizationStatus()
        if status == .notDetermined {
            status = await requestRemindersAccess()
        }
        guard status == .authorized else { return [] }
        let mapped = await fetchReminders(calendar: calendar)
        guard let day else {
            return mapped.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        let key = ReminderTaskMapper.dayKey(for: day, calendar: calendar)
        return mapped
            .filter { $0.dueDayKey == nil || $0.dueDayKey == key }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func upsert(_ item: AppleReminderItem) async throws {
        var status = remindersAuthorizationStatus()
        if status == .notDetermined {
            status = await requestRemindersAccess()
        }
        guard status == .authorized else { return }
        let existing = await fetchEKReminders()
        let match =
            existing.first { $0.calendarItemIdentifier == item.id }
            ?? existing.first {
                ($0.title ?? "").caseInsensitiveCompare(item.title) == .orderedSame
            }
        let reminder = match ?? EKReminder(eventStore: store)
        if match == nil {
            guard let list = store.defaultCalendarForNewReminders() else { return }
            reminder.calendar = list
        }
        reminder.title = item.title
        reminder.isCompleted = item.isCompleted
        if let dueKey = item.dueDayKey,
            let due = ReminderTaskMapper.date(fromDayKey: dueKey)
        {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day],
                from: due
            )
        }
        try store.save(reminder, commit: true)
    }

    private func fetchReminders(calendar: Calendar) async -> [AppleReminderItem] {
        let ek = await fetchEKReminders()
        return ek.compactMap { EventKitBridge.mapReminder($0, calendar: calendar) }
    }

    private func fetchEKReminders() async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            let predicate = store.predicateForReminders(in: nil)
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: (reminders as? [EKReminder]) ?? [])
            }
        }
    }
}

/// EKEvent / EKReminder → Core models. Lives in Vault so LociCore stays EventKit-free.
enum EventKitBridge {
    static func mapEvent(_ event: EKEvent) -> AppleCalendarEvent? {
        AppleCalendarEventMapper.map(
            id: event.eventIdentifier ?? event.calendarItemIdentifier,
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            location: event.location,
            calendarName: event.calendar?.title,
            notes: event.notes
        )
    }

    static func mapReminder(_ reminder: EKReminder, calendar: Calendar) -> AppleReminderItem? {
        let due = reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
        return AppleReminderItemMapper.map(
            id: reminder.calendarItemIdentifier,
            title: reminder.title,
            isCompleted: reminder.isCompleted,
            due: due,
            calendar: calendar
        )
    }
}
#endif

#if !canImport(EventKit)
/// EventKit adapters compile only when the EventKit SDK is present (Apple).
/// Linux SPM uses `AppleStoreFactory` fakes — this marker keeps the file non-empty.
enum EventKitAppleStoresUnavailable: Sendable {}
#endif
