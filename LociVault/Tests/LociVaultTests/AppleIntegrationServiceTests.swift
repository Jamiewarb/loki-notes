import XCTest
import LociCore
import LociIndex
import LociMarkdown
@testable import LociVault

final class AppleIntegrationServiceTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var appleParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!
    private var apple: AppleIntegrationService!
    private var utc: Calendar!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-apple-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-apple-db-\(stamp)", isDirectory: true)
        appleParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-apple-settings-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appleParent, withIntermediateDirectories: true)
        utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDownWithError() throws {
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
        if let appleParent { try? FileManager.default.removeItem(at: appleParent) }
    }

    private func boot(events: [AppleCalendarEvent] = [], reminders: [AppleReminderItem] = []) async throws {
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Apple Tests")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
        apple = AppleIntegrationService(
            settingsDirectory: appleParent,
            calendarStore: FakeAppleCalendarStore(events: events),
            remindersStore: FakeAppleRemindersStore(items: reminders)
        )
    }

    private func day20260813() -> (day: Date, event: AppleCalendarEvent) {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 13
        comps.hour = 10
        comps.minute = 0
        let start = utc.date(from: comps)!
        comps.hour = 11
        let end = utc.date(from: comps)!
        let day = utc.startOfDay(for: start)
        let event = AppleCalendarEvent(
            id: "evt-design-review",
            title: "Design review",
            start: start,
            end: end,
            location: "Studio A",
            calendarName: "Work"
        )
        return (day, event)
    }

    func testMeetingTypeSeededOnBootstrap() async throws {
        try await boot()
        let meeting = try await schema.loadType(.meeting)
        XCTAssertEqual(meeting.id, .meeting)
        XCTAssertTrue(meeting.isBuiltIn)
        XCTAssertTrue(meeting.properties.contains { $0.id == "event-id" })
        let root = try await vault.vaultRootURL
        let folder = root.appendingPathComponent("objects/meeting", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }

    func testEventsForDayAndDailyBodyUnchanged() async throws {
        let pair = day20260813()
        try await boot(events: [pair.event])
        var opened = try await daily.ensure(for: pair.day, calendar: utc)
        let before = opened.bodyMarkdown
        let listed = try await apple.eventsForDaily(day: pair.day, calendar: utc)
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.title, "Design review")
        opened = try await daily.open(date: pair.day, calendar: utc)
        XCTAssertEqual(opened.bodyMarkdown, before)
    }

    func testCreateMeetingIdempotentViaObjectServing() async throws {
        let pair = day20260813()
        try await boot(events: [pair.event])
        let first = try await apple.createMeeting(
            from: pair.event,
            using: objects,
            schema: schema,
            index: index
        )
        XCTAssertTrue(first.relativePath.hasPrefix("objects/meeting/"))
        if case .text(let eid) = first.properties["event-id"] {
            XCTAssertEqual(eid, pair.event.id)
        } else {
            XCTFail("expected event-id")
        }
        let second = try await apple.createMeeting(
            from: pair.event,
            using: objects,
            schema: schema,
            index: index
        )
        XCTAssertEqual(first.id, second.id)
        let meetings = try await index.objects(typeID: .meeting)
        XCTAssertEqual(meetings.count, 1)
    }

    func testRemindersPullWritesTaskIntoDaily() async throws {
        let pair = day20260813()
        let reminder = AppleReminderItem(
            id: "rem-1",
            title: "Ship PR31",
            isCompleted: false,
            dueDayKey: ReminderTaskMapper.dayKey(for: pair.day, calendar: utc)
        )
        try await boot(reminders: [reminder])
        try await apple.saveSettings(AppleIntegrationSettings(remindersSyncEnabled: true))
        let added = try await apple.pullRemindersIntoToday(
            day: pair.day,
            calendar: utc,
            daily: daily,
            objects: objects
        )
        XCTAssertEqual(added, 1)
        let opened = try await daily.open(date: pair.day, calendar: utc)
        XCTAssertTrue(opened.bodyMarkdown.contains("- [ ] Ship PR31"))

        // Disabled → no-op
        try await apple.saveSettings(AppleIntegrationSettings(remindersSyncEnabled: false))
        let again = try await apple.pullRemindersIntoToday(
            day: pair.day,
            calendar: utc,
            daily: daily,
            objects: objects
        )
        XCTAssertEqual(again, 0)
    }

    func testIndexAndSettingsNotInVault() async throws {
        try await boot()
        try await apple.saveSettings(AppleIntegrationSettings(remindersSyncEnabled: true))
        let vaultRoot = try await vault.vaultRootURL
        XCTAssertFalse(apple.settingsFileURL.path.hasPrefix(vaultRoot.path))
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
            }
        }
        XCTAssertFalse(sqliteInVault)
        XCTAssertTrue(
            LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32")
                || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35")
                || LociVaultModule.version.contains("pr36") || LociVaultModule.version.contains("pr37") || LociVaultModule.version.contains("pr38") || LociVaultModule.version.contains("pr39") || LociVaultModule.version.contains("pr40")
        )
    }

    func testDeniedCalendarReturnsEmptyWithoutWritingDaily() async throws {
        let pair = day20260813()
        try await boot()
        apple = AppleIntegrationService(
            settingsDirectory: appleParent,
            calendarStore: FakeAppleCalendarStore(events: [pair.event], authStatus: .denied),
            remindersStore: FakeAppleRemindersStore()
        )
        var opened = try await daily.ensure(for: pair.day, calendar: utc)
        let before = opened.bodyMarkdown
        let listed = try await apple.eventsForDaily(day: pair.day, calendar: utc)
        XCTAssertTrue(listed.isEmpty)
        XCTAssertEqual(apple.calendarAuthorizationStatus(), .denied)
        opened = try await daily.open(date: pair.day, calendar: utc)
        XCTAssertEqual(opened.bodyMarkdown, before)
        let proof = EventKitProof.evaluate(dailyUnchanged: before == opened.bodyMarkdown, indexInsideVault: false)
        XCTAssertTrue(proof.dailyUnchanged)
        XCTAssertTrue(proof.eventKitWired)
    }

    func testDefaultFactoryUsesFakesOnLinux() {
        XCTAssertTrue(EventKitNotes.eventKitWired)
        #if canImport(EventKit)
        XCTAssertTrue(AppleStoreFactory.usesEventKit)
        #else
        XCTAssertFalse(AppleStoreFactory.usesEventKit)
        XCTAssertTrue(EventKitNotes.linuxUsesFakes)
        XCTAssertTrue(AppleStoreFactory.makeCalendarStore() is FakeAppleCalendarStore)
        XCTAssertTrue(AppleStoreFactory.makeRemindersStore() is FakeAppleRemindersStore)
        #endif
    }
}
