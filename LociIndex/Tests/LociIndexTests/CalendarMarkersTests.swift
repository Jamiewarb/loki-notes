import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class CalendarMarkersTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-cal-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-cal-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDownWithError() throws {
        index = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        try await vault.ensureSkeleton(spaceName: "Calendar Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
    }

    private func writeObject(
        id: String,
        type: String,
        title: String,
        path: String,
        created: Date,
        body: String
    ) async throws {
        let md = """
            ---
            id: \(id)
            type: \(type)
            title: \(title)
            created: \(iso(created))
            updated: \(iso(created))
            tags: []
            ---

            \(body)
            """
        try await vault.writeFile(Data(md.utf8), atRelativePath: path)
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    func testMarkersForDailyContentAndCreations() async throws {
        try await boot()
        let day12 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        let day13 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let day14 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 14))!

        // Daily with content on 13th
        try await writeObject(
            id: "daily-2026-08-13",
            type: "daily",
            title: "2026-08-13",
            path: "daily/2026-08-13.md",
            created: day13.addingTimeInterval(9 * 3600),
            body: "Inbox thoughts.\n"
        )
        // Empty-ish daily on 12th (whitespace only → no content)
        try await writeObject(
            id: "daily-2026-08-12",
            type: "daily",
            title: "2026-08-12",
            path: "daily/2026-08-12.md",
            created: day12.addingTimeInterval(8 * 3600),
            body: "\n"
        )
        // Page created on 13th
        try await writeObject(
            id: UUID().uuidString.lowercased(),
            type: "page",
            title: "Created On 13",
            path: "objects/page/created-13.md",
            created: day13.addingTimeInterval(12 * 3600),
            body: "Hello.\n"
        )
        // Page created on 14th (no daily)
        try await writeObject(
            id: UUID().uuidString.lowercased(),
            type: "page",
            title: "Created On 14",
            path: "objects/page/created-14.md",
            created: day14.addingTimeInterval(10 * 3600),
            body: "Later.\n"
        )

        try await index.rebuild()

        let markers = try await index.calendarMarkers(
            from: day12,
            to: day14,
            calendar: calendar
        )
        let byKey = Dictionary(uniqueKeysWithValues: markers.map { ($0.dayKey, $0) })

        let m12 = try XCTUnwrap(byKey["2026-08-12"])
        XCTAssertTrue(m12.hasDailyNote)
        XCTAssertFalse(m12.hasContent)
        XCTAssertEqual(m12.creationCount, 1) // the daily itself
        XCTAssertTrue(m12.showsDot)

        let m13 = try XCTUnwrap(byKey["2026-08-13"])
        XCTAssertTrue(m13.hasDailyNote)
        XCTAssertTrue(m13.hasContent)
        XCTAssertEqual(m13.creationCount, 2) // daily + page
        XCTAssertTrue(m13.showsDot)

        let m14 = try XCTUnwrap(byKey["2026-08-14"])
        XCTAssertFalse(m14.hasDailyNote)
        XCTAssertFalse(m14.hasContent)
        XCTAssertEqual(m14.creationCount, 1)
        XCTAssertTrue(m14.showsDot)

        XCTAssertTrue(LociIndexModule.version.contains("pr25") || LociIndexModule.version.contains("pr26") || LociIndexModule.version.contains("pr27") || LociIndexModule.version.contains("pr28"))
    }

    func testCalendarChromeDoesNotRequireVaultRewrite() async throws {
        try await boot()
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        try await writeObject(
            id: "daily-2026-08-13",
            type: "daily",
            title: "2026-08-13",
            path: "daily/2026-08-13.md",
            created: day,
            body: "Keep me.\n"
        )
        try await index.rebuild()
        let before = try await vault.readFile(atRelativePath: "daily/2026-08-13.md")
        _ = try await index.calendarMarkers(from: day, to: day, calendar: calendar)
        let after = try await vault.readFile(atRelativePath: "daily/2026-08-13.md")
        XCTAssertEqual(before, after)
    }
}
