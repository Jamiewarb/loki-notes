import XCTest
import LociCore
import LociIndex
import LociMarkdown
@testable import LociVault

final class SafariClipSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!
    private var capture: CaptureService!
    private var safari: SafariClipService!

    override func setUpWithError() throws {
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-safari-vault-\(UUID().uuidString)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-safari-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Safari Tests")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
        capture = CaptureService(vault: vault, objects: objects, dailyNotes: daily)
        safari = SafariClipService(vault: vault, capture: capture, objects: objects)
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func testEnqueueWritesInboxWithoutIndex() async throws {
        try await boot()
        let clip = SafariClip(
            pageURL: "https://example.com/x",
            pageTitle: "X",
            selection: "Hello",
            destination: .appendToToday
        )
        let path = try await safari.enqueue(clip)
        XCTAssertTrue(path.hasPrefix(".loci/inbox/"))
        let data = try await vault.readFile(atRelativePath: path)
        let item = try CaptureInboxCodec.decode(data)
        XCTAssertEqual(item.source, .safari)
        XCTAssertEqual(item.kind, .appendToToday)
        // Index lives outside vault
        let root = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
            }
        }
        XCTAssertFalse(sqliteInVault)
    }

    func testDrainAppendsDailyWithSafariTag() async throws {
        let calendar = utcCalendar
        try await boot()
        _ = try await safari.enqueue(
            SafariClip(
                pageURL: "https://news.example/a",
                pageTitle: "News",
                selection: "Inbox clip",
                destination: .appendToToday
            )
        )
        let results = try await safari.drain(calendar: calendar)
        XCTAssertEqual(results.count, 1)
        let line = try XCTUnwrap(results.first?.appendedLine)
        XCTAssertTrue(line.contains("Inbox clip"))
        XCTAssertTrue(line.contains("https://news.example/a"))
        XCTAssertTrue(line.contains("· safari"))
        let opened = try await daily.ensureToday(calendar: calendar)
        XCTAssertTrue(opened.bodyMarkdown.contains("· safari"))
        let pending = try await capture.listPendingInbox()
        XCTAssertTrue(pending.isEmpty)
    }

    func testDrainCreatesWeblinkWithURLProperty() async throws {
        let calendar = utcCalendar
        try await boot()
        _ = try await safari.enqueue(
            SafariClip(
                pageURL: "https://example.com/weblink",
                pageTitle: "Weblink Page",
                selection: "Clip body",
                destination: .weblinkObject
            )
        )
        let results = try await safari.drain(calendar: calendar)
        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.kind, .createObject)
        XCTAssertTrue(result.relativePath.hasPrefix("objects/weblink/"))
        let opened = try await objects.open(id: result.objectID)
        XCTAssertEqual(opened.meta.title, "Weblink Page")
        XCTAssertEqual(opened.meta.properties["url"], .url("https://example.com/weblink"))
        XCTAssertEqual(opened.meta.properties["clipped-from"], .text("Weblink Page"))
        XCTAssertTrue(opened.bodyMarkdown.contains("> Clip body"))
    }

    func testDirectClipToToday() async throws {
        let calendar = utcCalendar
        try await boot()
        let result = try await safari.clip(
            SafariClip(
                pageURL: "https://direct.example",
                selection: "Direct",
                destination: .appendToToday
            ),
            calendar: calendar
        )
        XCTAssertEqual(result.kind, .appendToToday)
        XCTAssertNil(result.inboxRelativePath)
        XCTAssertTrue(result.appendedLine?.contains("· safari") == true)
    }

    func testWeblinkTypeSeeded() async throws {
        try await boot()
        let type = try await schema.loadType(.weblink)
        XCTAssertTrue(type.isBuiltIn)
        XCTAssertEqual(type.name, "Weblink")
        let root = try await vault.vaultRootURL
        let folder = root.appendingPathComponent("objects/weblink", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertTrue(LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35"))
    }
}
