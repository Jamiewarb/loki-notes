import Foundation

/// In-memory calendar store for Linux tests and demos (PR31). No EventKit.
public final class FakeAppleCalendarStore: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AppleCalendarEvent] = []
    public private(set) var authStatus: AppleAuthStatus = .authorized

    public init(events: [AppleCalendarEvent] = [], authStatus: AppleAuthStatus = .authorized) {
        self.events = events
        self.authStatus = authStatus
    }

    public func replaceAllForTesting(_ events: [AppleCalendarEvent]) {
        lock.lock()
        defer { lock.unlock() }
        self.events = events
    }

    public func authorizationStatus() -> AppleAuthStatus {
        authStatus
    }

    public func setAuthStatusForTesting(_ status: AppleAuthStatus) {
        authStatus = status
    }

    public func events(on day: Date, calendar: Calendar) -> [AppleCalendarEvent] {
        lock.lock()
        defer { lock.unlock() }
        return AppleEventDayFilter.events(events, on: day, calendar: calendar)
    }

    public func allEventsForTesting() -> [AppleCalendarEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

/// In-memory Reminders store for Linux tests and demos (PR31). No EventKit.
public final class FakeAppleRemindersStore: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: AppleReminderItem] = [:]
    public private(set) var authStatus: AppleAuthStatus = .authorized

    public init(items: [AppleReminderItem] = [], authStatus: AppleAuthStatus = .authorized) {
        for item in items {
            self.items[item.id] = item
        }
        self.authStatus = authStatus
    }

    public func replaceAllForTesting(_ items: [AppleReminderItem]) {
        lock.lock()
        defer { lock.unlock() }
        self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    public func authorizationStatus() -> AppleAuthStatus {
        authStatus
    }

    public func setAuthStatusForTesting(_ status: AppleAuthStatus) {
        authStatus = status
    }

    public func reminders(dueOn day: Date?, calendar: Calendar) -> [AppleReminderItem] {
        lock.lock()
        defer { lock.unlock() }
        let all = Array(items.values)
        guard let day else {
            return all.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        let key = ReminderTaskMapper.dayKey(for: day, calendar: calendar)
        return all
            .filter { $0.dueDayKey == nil || $0.dueDayKey == key }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func upsert(_ item: AppleReminderItem) {
        lock.lock()
        defer { lock.unlock() }
        items[item.id] = item
    }

    public func allItemsForTesting() -> [AppleReminderItem] {
        lock.lock()
        defer { lock.unlock() }
        return Array(items.values)
    }
}
