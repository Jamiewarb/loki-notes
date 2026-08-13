import XCTest
import Foundation
import LociCore
import LociMarkdown
import LociIndex
@testable import LociVault

/// PR11 critical invariant: creating a Page must not rewrite the daily `.md`.
final class CreatedTodayNonMutationTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!
    private var daily: DailyNoteService!
    private var objects: ObjectService!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-created-today-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-created-today-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDownWithError() throws {
        objects = nil
        daily = nil
        index = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Created Today Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        daily = DailyNoteService(vault: vault, index: index)
        objects = ObjectService(vault: vault, index: index)
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Deterministic content fingerprint (CryptoKit unavailable on Linux CI).
    private func contentFingerprint(_ data: Data) -> String {
        "len=\(data.count);hex=\(data.map { String(format: "%02x", $0) }.joined())"
    }

    func testCreatePageDoesNotMutateDailyMarkdownBytes() async throws {
        try await boot()
        let today = day(2026, 8, 13)
        let dailyPath = "daily/2026-08-13.md"

        _ = try await daily.ensure(for: today, calendar: calendar)
        // Give the daily note a stable body so we can detect any rewrite.
        let dailyMeta = try await daily.open(date: today, calendar: calendar).meta
        try await objects.save(
            meta: dailyMeta,
            bodyMarkdown: "## Inbox\n\nStable body for mutation proof.\n"
        )

        let beforeData = try await vault.readFile(atRelativePath: dailyPath)
        let beforeText = String(data: beforeData, encoding: .utf8) ?? ""
        let beforeHash = contentFingerprint(beforeData)
        let beforeMod = try await modificationDate(forRelativePath: dailyPath)

        // Critical: ObjectService.create must only write the new Page path.
        let page = try await objects.create(typeID: .page, title: "Created Today Page")

        let afterData = try await vault.readFile(atRelativePath: dailyPath)
        let afterText = String(data: afterData, encoding: .utf8) ?? ""
        let afterHash = contentFingerprint(afterData)
        let afterMod = try await modificationDate(forRelativePath: dailyPath)

        XCTAssertEqual(beforeHash, afterHash, "daily .md content hash must be unchanged")
        XCTAssertEqual(beforeData, afterData, "daily .md Data bytes must be identical")
        XCTAssertEqual(beforeText, afterText, "daily .md UTF-8 must be identical")
        XCTAssertEqual(beforeMod, afterMod, "daily .md mtime must be unchanged")

        // Page is indexed under created(on:) for that calendar day.
        let created = try await index.created(on: today)
        XCTAssertTrue(
            created.contains(where: { $0.id == page.id }),
            "new Page should appear in IndexQuerying.created(on:)"
        )
        XCTAssertTrue(
            created.contains(where: { $0.typeID == .daily }),
            "daily note itself remains in the raw index query"
        )

        // Panel UX filters Daily-type rows (see CreatedTodayPanel.filterForPanel).
        let panelItems = created.filter { $0.typeID != .daily }
        XCTAssertTrue(panelItems.contains(where: { $0.id == page.id }))
        XCTAssertFalse(panelItems.contains(where: { $0.typeID == .daily }))

        // Daily file still does not mention the new page (no auto wiki-link rewrite).
        XCTAssertFalse(afterText.contains(page.id.uuidString.lowercased()))
        XCTAssertFalse(afterText.contains("Created Today Page"))
    }

    func testCreatedOnQueryIncludesPageAndDailySeparately() async throws {
        try await boot()
        let today = day(2026, 8, 13)
        let note = try await daily.ensure(for: today, calendar: calendar)
        let page = try await objects.create(typeID: .page, title: "Another")

        let hits = try await index.created(on: today)
        let ids = Set(hits.map(\.id))
        XCTAssertTrue(ids.contains(note.meta.id))
        XCTAssertTrue(ids.contains(page.id))
        XCTAssertEqual(hits.filter { $0.typeID != .daily }.count, 1)
    }

    private func modificationDate(forRelativePath path: String) async throws -> Date {
        let root = try await vault.vaultRootURL
        let url = root.appendingPathComponent(path)
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = values.contentModificationDate else {
            throw LociError.fileNotFound(path)
        }
        return date
    }
}
