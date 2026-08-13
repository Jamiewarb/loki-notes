import XCTest
import Foundation
import LociCore
import LociMarkdown
import LociIndex
@testable import LociVault

final class DailyNoteServiceTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!
    private var daily: DailyNoteService!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-daily-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-daily-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDownWithError() throws {
        daily = nil
        index = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Daily Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        daily = DailyNoteService(vault: vault, index: index)
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testEnsureTodayCreatesDeterministicPathAndId() async throws {
        try await boot()
        let today = day(2026, 8, 13)
        let opened = try await daily.ensure(for: today, calendar: calendar)

        XCTAssertEqual(opened.meta.typeID, .daily)
        XCTAssertEqual(opened.meta.relativePath, "daily/2026-08-13.md")
        XCTAssertEqual(opened.meta.id.dailyDateKey, "daily-2026-08-13")
        XCTAssertEqual(opened.meta.id, ObjectID.daily(year: 2026, month: 8, day: 13))
        XCTAssertEqual(opened.meta.title, "2026-08-13")
        XCTAssertTrue(opened.bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        let exists = try await vault.fileExists(atRelativePath: "daily/2026-08-13.md")
        XCTAssertTrue(exists)

        let data = try await vault.readFile(atRelativePath: "daily/2026-08-13.md")
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("id: daily-2026-08-13"))
        XCTAssertTrue(text.contains("type: daily"))

        let indexed = try await index.object(id: opened.meta.id)
        XCTAssertEqual(indexed?.relativePath, "daily/2026-08-13.md")
    }

    func testEnsureIsIdempotentDoesNotRewriteBody() async throws {
        try await boot()
        let today = day(2026, 8, 13)
        var opened = try await daily.ensure(for: today, calendar: calendar)

        // Simulate user edit via ObjectService-style save path on DailyNoteService internals:
        // write body through vault + re-ensure.
        let objects = ObjectService(vault: vault, index: index)
        var meta = opened.meta
        try await objects.save(meta: meta, bodyMarkdown: "Kept thoughts.\n")

        opened = try await daily.ensure(for: today, calendar: calendar)
        XCTAssertTrue(opened.bodyMarkdown.contains("Kept thoughts"))

        let again = try await daily.ensure(for: today, calendar: calendar)
        XCTAssertEqual(again.meta.id, opened.meta.id)
        XCTAssertEqual(again.meta.relativePath, opened.meta.relativePath)
        XCTAssertTrue(again.bodyMarkdown.contains("Kept thoughts"))
    }

    func testNavigateYesterdayCreatesSeparateFile() async throws {
        try await boot()
        let today = day(2026, 8, 13)
        let yesterday = daily.previousDay(of: today, calendar: calendar)

        let todayNote = try await daily.ensure(for: today, calendar: calendar)
        let yNote = try await daily.ensure(for: yesterday, calendar: calendar)

        XCTAssertEqual(todayNote.meta.relativePath, "daily/2026-08-13.md")
        XCTAssertEqual(yNote.meta.relativePath, "daily/2026-08-12.md")
        XCTAssertNotEqual(todayNote.meta.id, yNote.meta.id)
        XCTAssertEqual(yNote.meta.id.dailyDateKey, "daily-2026-08-12")

        let dailies = try await index.objects(typeID: .daily)
        XCTAssertEqual(dailies.count, 2)
    }

    func testOpenMissingThrows() async throws {
        try await boot()
        do {
            _ = try await daily.open(date: day(2026, 1, 1), calendar: calendar)
            XCTFail("expected fileNotFound")
        } catch let error as LociError {
            guard case .fileNotFound = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func testSelectAndNextDayAPI() async throws {
        try await boot()
        let today = day(2026, 8, 13)
        XCTAssertEqual(
            DailyNoteIdentity.title(
                for: daily.select(date: today, calendar: calendar),
                calendar: calendar
            ),
            "2026-08-13"
        )
        let next = daily.nextDay(of: today, calendar: calendar)
        XCTAssertEqual(DailyNoteIdentity.title(for: next, calendar: calendar), "2026-08-14")
    }

    func testIndexNeverInsideVaultForDaily() async throws {
        try await boot()
        _ = try await daily.ensure(for: day(2026, 8, 13), calendar: calendar)
        let vaultRoot = try await vault.vaultRootURL
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))
    }
}
