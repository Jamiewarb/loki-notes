import XCTest
import LociCore
import LociIndex
import LociMarkdown
@testable import LociVault

final class CaptureSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!
    private var capture: CaptureService!

    override func setUpWithError() throws {
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-capture-vault-\(UUID().uuidString)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-capture-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot(calendar: Calendar) async throws {
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Capture Tests")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
        capture = CaptureService(vault: vault, objects: objects, dailyNotes: daily)
        _ = calendar
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func testEnqueueWritesInboxJSONWithoutIndex() async throws {
        try await boot(calendar: utcCalendar)
        let item = CaptureInboxItem.appendLine("From share", source: .share)
        let path = try await CaptureInboxWriter.enqueue(item, vault: vault)
        XCTAssertTrue(path.hasPrefix(".loci/inbox/"))
        XCTAssertTrue(path.hasSuffix(".json"))
        let exists = try await vault.fileExists(atRelativePath: path)
        XCTAssertTrue(exists)
        let data = try await vault.readFile(atRelativePath: path)
        let decoded = try CaptureInboxCodec.decode(data)
        XCTAssertEqual(decoded.text, "From share")
        XCTAssertEqual(decoded.source, .share)
        XCTAssertEqual(decoded.kind, .appendToToday)
    }

    func testDrainAppendsToTodayAndRemovesInbox() async throws {
        let calendar = utcCalendar
        try await boot(calendar: calendar)

        let item = CaptureInboxItem.appendLine(
            "Inbox line",
            source: .widget,
            sourceURL: "https://example.com"
        )
        let inboxPath = try await capture.enqueue(item)
        let existsBefore = try await vault.fileExists(atRelativePath: inboxPath)
        XCTAssertTrue(existsBefore)

        let results = try await capture.drainInbox(calendar: calendar)
        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.kind, .appendToToday)
        XCTAssertTrue(result.relativePath.hasPrefix("daily/"))
        XCTAssertEqual(result.inboxRelativePath, inboxPath)
        let existsAfter = try await vault.fileExists(atRelativePath: inboxPath)
        XCTAssertFalse(existsAfter)

        let opened = try await daily.open(date: Date(), calendar: calendar)
        XCTAssertTrue(opened.bodyMarkdown.contains("Inbox line"))
        XCTAssertTrue(opened.bodyMarkdown.contains("https://example.com"))
        XCTAssertTrue(opened.bodyMarkdown.contains("widget"))
        XCTAssertEqual(result.objectID, opened.meta.id)
    }

    func testDrainCreatesTypedObject() async throws {
        let calendar = utcCalendar
        try await boot(calendar: calendar)

        let item = CaptureInboxItem.createTyped(
            typeID: .page,
            title: "Shared Article",
            text: "Clip body",
            source: .share,
            sourceURL: "https://news.example/a"
        )
        _ = try await capture.enqueue(item)
        let results = try await capture.drainInbox(calendar: calendar)
        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.kind, .createObject)
        XCTAssertTrue(result.relativePath.hasPrefix("objects/page/"))

        let opened = try await objects.open(id: result.objectID)
        XCTAssertEqual(opened.meta.title, "Shared Article")
        XCTAssertTrue(opened.bodyMarkdown.contains("Clip body"))
        XCTAssertTrue(opened.bodyMarkdown.contains("https://news.example/a"))
        let pending = try await capture.listPendingInbox()
        XCTAssertTrue(pending.isEmpty)
    }

    func testDirectAppendToToday() async throws {
        let calendar = utcCalendar
        try await boot(calendar: calendar)
        let result = try await capture.appendToToday(
            "Direct note",
            sourceURL: nil,
            source: .menuBar,
            calendar: calendar
        )
        XCTAssertEqual(result.kind, .appendToToday)
        XCTAssertNil(result.inboxRelativePath)
        let opened = try await daily.ensureToday(calendar: calendar)
        XCTAssertTrue(opened.bodyMarkdown.contains("Direct note"))
        XCTAssertTrue(opened.bodyMarkdown.contains("menuBar"))
    }

    func testSkeletonIncludesInboxDirectory() async throws {
        try await boot(calendar: utcCalendar)
        let root = try await vault.vaultRootURL
        let inbox = root.appendingPathComponent(VaultLayout.inboxDirectory, isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: inbox.path))
        // Index must not live in vault
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }
        XCTAssertFalse(sqliteInVault)
    }
}
