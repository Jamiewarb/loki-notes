import Foundation
import LociCore
import LociVault
import LociIndex
import LociMarkdown

/// CLI: Apple Calendar / Reminders fixtures for DevHarness (PR31 / PR36).
/// Linux always injects fakes; proof flags record EventKit wiring + linuxUsesFakes.
@main
struct LociAppleDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-apple-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-apple-demo-db-\(stamp)", isDirectory: true)
        let appleParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-apple-demo-settings-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appleParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Apple")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // Fixed UTC day 2026-08-13
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 13
        comps.hour = 10
        comps.minute = 0
        let start = calendar.date(from: comps)!
        comps.hour = 11
        let end = calendar.date(from: comps)!
        let day = calendar.startOfDay(for: start)

        let event = AppleCalendarEvent(
            id: "evt-design-review-pr31",
            title: "Design review",
            start: start,
            end: end,
            location: "Studio A",
            calendarName: "Work",
            notes: "Ship PR31 calendar chrome."
        )

        let apple = AppleIntegrationService(
            settingsDirectory: appleParent,
            calendarStore: FakeAppleCalendarStore(events: [event]),
            remindersStore: FakeAppleRemindersStore(items: [
                AppleReminderItem(
                    id: "rem-ship-pr31",
                    title: "Ship PR31",
                    isCompleted: false,
                    dueDayKey: ReminderTaskMapper.dayKey(for: day, calendar: calendar)
                )
            ])
        )

        // Ensure daily exists; capture body before listing events.
        var opened = try await daily.ensure(for: day, calendar: calendar)
        let bodyBeforeEvents = opened.bodyMarkdown

        let listed = try await apple.eventsForDaily(day: day, calendar: calendar)
        opened = try await daily.open(date: day, calendar: calendar)
        let bodyAfterEvents = opened.bodyMarkdown
        let dailyUnchanged = bodyBeforeEvents == bodyAfterEvents

        let meeting1 = try await apple.createMeeting(
            from: event,
            using: objects,
            schema: schema,
            index: index
        )
        let meeting2 = try await apple.createMeeting(
            from: event,
            using: objects,
            schema: schema,
            index: index
        )
        let idempotent = meeting1.id == meeting2.id

        try await apple.saveSettings(AppleIntegrationSettings(remindersSyncEnabled: true))
        let pulled = try await apple.pullRemindersIntoToday(
            day: day,
            calendar: calendar,
            daily: daily,
            objects: objects
        )
        opened = try await daily.open(date: day, calendar: calendar)
        let reminderSynced = opened.bodyMarkdown.contains("Ship PR31") && pulled >= 1

        try await index.rebuild()

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        var settingsInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
                if url.lastPathComponent == "settings.json",
                    url.path.contains("/apple/")
                {
                    settingsInVault = true
                }
            }
        }

        let settingsOutside =
            !apple.settingsFileURL.path.hasPrefix(vaultRoot.path + "/")
            && !apple.settingsFileURL.path.hasPrefix(vaultRoot.path)

        let meetingType = try await schema.loadType(.meeting)

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "indexInsideVault": sqliteInVault,
            "settingsInsideVault": settingsInVault,
            "settingsOutsideVault": settingsOutside,
            "day": DailyNoteIdentity.title(for: day, calendar: calendar),
            "events": listed.map { ev -> [String: Any] in
                [
                    "id": ev.id,
                    "title": ev.title,
                    "location": ev.location ?? "",
                    "calendar": ev.calendarName ?? "",
                ]
            },
            "meeting": [
                "id": meeting1.id.frontMatterIDString,
                "path": meeting1.relativePath,
                "title": meeting1.title,
                "eventId": {
                    if case .text(let v) = meeting1.properties["event-id"] { return v }
                    return ""
                }(),
            ],
            "meetingIdempotent": idempotent,
            "dailyUnchangedAfterEvents": dailyUnchanged,
            "reminderSynced": reminderSynced,
            "remindersPulled": pulled,
            "dailyBodyAfterSync": opened.bodyMarkdown,
            "meetingTypeSeeded": meetingType.id == .meeting && meetingType.isBuiltIn,
            "proof": [
                "eventsListed": listed.count == 1 && listed.first?.title == "Design review",
                "meetingPath": meeting1.relativePath.hasPrefix("objects/meeting/"),
                "idempotent": idempotent,
                "dailyUnchanged": dailyUnchanged,
                "reminderSynced": reminderSynced,
                "indexOutsideVault": !sqliteInVault,
                "settingsOutsideVault": settingsOutside && !settingsInVault,
                "meetingTypeSeeded": meetingType.isBuiltIn,
                "eventKitWired": EventKitNotes.eventKitWired,
                "linuxUsesFakes": EventKitNotes.linuxUsesFakes,
            ],
            "eventKitWired": EventKitNotes.eventKitWired,
            "linuxUsesFakes": EventKitNotes.linuxUsesFakes,
            "dailyUnchanged": dailyUnchanged,
            "note":
                "PR36: EventKit on Apple (mapped to AppleCalendarEvent). Linux uses fakes. Event list is UI chrome (daily .md unchanged). Meeting via ObjectServing. Reminders sync explicit + settings outside vault.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
