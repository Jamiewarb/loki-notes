import Foundation
import LociCore

/// Concrete Apple Calendar / Reminders integration (PR31 / PR36).
///
/// Settings live under Application Support `Loci/apple/` — **never** the vault.
/// Injected stores: EventKit when `canImport(EventKit)`, else in-memory fakes.
/// Listing events never writes daily markdown; Meeting create goes through ObjectServing.
public final class AppleIntegrationService: AppleIntegrationServing, @unchecked Sendable {
    private let settingsDirectory: URL
    private let settingsURL: URL
    private let lock = NSLock()
    public let calendarStore: any AppleCalendarServing
    public let remindersStore: any AppleRemindersServing

    public init(
        settingsDirectory: URL,
        calendarStore: (any AppleCalendarServing)? = nil,
        remindersStore: (any AppleRemindersServing)? = nil
    ) {
        self.settingsDirectory = settingsDirectory
        self.settingsURL = settingsDirectory.appendingPathComponent(
            "settings.json",
            isDirectory: false
        )
        self.calendarStore = calendarStore ?? AppleStoreFactory.makeCalendarStore()
        self.remindersStore = remindersStore ?? AppleStoreFactory.makeRemindersStore()
    }

    /// Application Support `Loci/apple/` on Apple; temp `Loci/apple/` on Linux.
    public static func defaultDirectory() throws -> URL {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Loci/apple", isDirectory: true)
        #else
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Loci/apple", isDirectory: true)
        #endif
    }

    public static func makeDefault() throws -> AppleIntegrationService {
        AppleIntegrationService(
            settingsDirectory: try defaultDirectory(),
            calendarStore: AppleStoreFactory.makeCalendarStore(),
            remindersStore: AppleStoreFactory.makeRemindersStore()
        )
    }

    public var settingsFileURL: URL { settingsURL }

    // MARK: - Settings

    public func loadSettings() async throws -> AppleIntegrationSettings {
        try loadSettingsLocked()
    }

    public func saveSettings(_ settings: AppleIntegrationSettings) async throws {
        try saveSettingsLocked(settings)
    }

    // MARK: - Calendar

    public func calendarAuthorizationStatus() -> AppleAuthStatus {
        calendarStore.calendarAuthorizationStatus()
    }

    public func requestCalendarAccess() async -> AppleAuthStatus {
        await calendarStore.requestCalendarAccess()
    }

    public func events(on day: Date, calendar: Calendar) async throws -> [AppleCalendarEvent] {
        try await calendarStore.events(on: day, calendar: calendar)
    }

    public func eventsForDaily(day: Date, calendar: Calendar) async throws -> [AppleCalendarEvent] {
        try await events(on: day, calendar: calendar)
    }

    // MARK: - Reminders

    public func remindersAuthorizationStatus() -> AppleAuthStatus {
        remindersStore.remindersAuthorizationStatus()
    }

    public func requestRemindersAccess() async -> AppleAuthStatus {
        await remindersStore.requestRemindersAccess()
    }

    public func reminders(
        dueOn day: Date?,
        calendar: Calendar
    ) async throws -> [AppleReminderItem] {
        try await remindersStore.reminders(dueOn: day, calendar: calendar)
    }

    public func upsert(_ item: AppleReminderItem) async throws {
        try await remindersStore.upsert(item)
    }

    // MARK: - Meeting create

    public func existingMeeting(
        forEventID eventID: String,
        index: any IndexQuerying
    ) async throws -> LociObjectMeta? {
        let matches = try await index.objects(
            typeID: .meeting,
            propertyKey: "event-id",
            equalsText: eventID
        )
        return matches.first
    }

    public func createMeeting(
        from event: AppleCalendarEvent,
        using objects: any ObjectServing,
        schema: any SchemaServing,
        index: any IndexQuerying
    ) async throws -> LociObjectMeta {
        _ = schema
        if let existing = try await existingMeeting(forEventID: event.id, index: index) {
            return existing
        }
        // Ensure Meeting type exists (idempotent seed path via bootstrap elsewhere).
        var meta = try await objects.create(
            typeID: .meeting,
            title: MeetingObjectFactory.title(from: event)
        )
        for (key, value) in MeetingObjectFactory.properties(from: event) {
            meta.properties[key] = value
        }
        meta.updated = Date()
        let body = MeetingObjectFactory.bodyMarkdown(from: event)
        try await objects.save(meta: meta, bodyMarkdown: body)
        if let refreshed = try? await index.object(id: meta.id) {
            return refreshed
        }
        return try await objects.open(id: meta.id).meta
    }

    // MARK: - Reminders sync

    @discardableResult
    public func pullRemindersIntoToday(
        day: Date,
        calendar: Calendar,
        daily: any DailyNoteServing,
        objects: any ObjectServing
    ) async throws -> Int {
        let settings = try await loadSettings()
        guard settings.remindersSyncEnabled else { return 0 }
        let items = try await reminders(dueOn: day, calendar: calendar)
        var opened = try await daily.ensure(for: day, calendar: calendar)
        var body = opened.bodyMarkdown
        var added = 0
        for item in items where !item.isCompleted {
            if ReminderTaskMapper.bodyContainsTask(title: item.title, body: body) {
                continue
            }
            body = ReminderTaskMapper.appendMissingTask(title: item.title, toBody: body)
            added += 1
        }
        if added > 0 {
            opened.meta.updated = Date()
            try await objects.save(meta: opened.meta, bodyMarkdown: body)
        }
        return added
    }

    @discardableResult
    public func pushOpenTasksToReminders(
        day: Date,
        calendar: Calendar,
        index: any IndexQuerying
    ) async throws -> Int {
        let settings = try await loadSettings()
        guard settings.remindersSyncEnabled else { return 0 }
        let tasks = try await index.tasks(inDailyNoteOn: day, calendar: calendar)
        let open = tasks.filter { !$0.isCompleted }
        let dayKey = ReminderTaskMapper.dayKey(for: day, calendar: calendar)
        var pushed = 0
        let existing = try await remindersStore.reminders(dueOn: day, calendar: calendar)
        for task in open {
            if existing.contains(where: {
                $0.title.caseInsensitiveCompare(task.text) == .orderedSame
            }) {
                continue
            }
            let item = AppleReminderItem(
                id: "task-\(task.id)",
                title: task.text,
                isCompleted: false,
                dueDayKey: dayKey
            )
            try await upsert(item)
            pushed += 1
        }
        return pushed
    }

    // MARK: - Settings I/O

    private func loadSettingsLocked() throws -> AppleIntegrationSettings {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return AppleIntegrationSettings()
        }
        let data = try Data(contentsOf: settingsURL)
        return try JSONDecoder().decode(AppleIntegrationSettings.self, from: data)
    }

    private func saveSettingsLocked(_ settings: AppleIntegrationSettings) throws {
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: settingsURL.path
        )
    }
}
