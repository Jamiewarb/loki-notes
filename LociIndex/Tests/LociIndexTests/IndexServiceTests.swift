import XCTest
import Foundation
import GRDB
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class IndexServiceTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-index-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-index-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        index = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        try await vault.ensureSkeleton(spaceName: "Index Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
    }

    private func writePage(
        id: UUID,
        title: String,
        path: String,
        created: Date,
        body: String,
        tags: [String] = []
    ) async throws {
        let tagsYAML: String
        if tags.isEmpty {
            tagsYAML = "[]"
        } else {
            tagsYAML = "[" + tags.joined(separator: ", ") + "]"
        }
        let md = """
            ---
            id: \(id.uuidString.lowercased())
            type: page
            title: \(title)
            created: \(iso(created))
            updated: \(iso(created))
            tags: \(tagsYAML)
            ---

            \(body)
            """
        try await vault.writeFile(Data(md.utf8), atRelativePath: path)
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    func testIndexDatabasePathIsOutsideVault() async throws {
        try await boot()
        let vaultRoot = try await vault.vaultRootURL
        let dbURL = index.databaseURL

        XCTAssertFalse(
            dbURL.path.hasPrefix(vaultRoot.path),
            "index.sqlite must not live under the vault root"
        )
        XCTAssertEqual(dbURL.lastPathComponent, "index.sqlite")
        XCTAssertTrue(dbURL.path.contains(indexParent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }

    func testFullRebuildIndexesVaultMarkdown() async throws {
        try await boot()
        let id = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeee1")!
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!
        try await writePage(
            id: id,
            title: "Deep Work",
            path: "objects/page/deep-work.md",
            created: created,
            body: "Focus on [[bbbbbbbb-bbbb-4ccc-8ddd-eeeeeeeeeee2|related]] and #focus.",
            tags: ["book"]
        )

        try await index.rebuild()

        let meta = try await index.object(id: ObjectID(id))
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?.title, "Deep Work")
        XCTAssertEqual(meta?.typeID, .page)
        XCTAssertEqual(meta?.relativePath, "objects/page/deep-work.md")
        XCTAssertTrue(meta?.tags.contains("book") == true)
        XCTAssertTrue(meta?.tags.contains("focus") == true)

        let pages = try await index.objects(typeID: .page)
        XCTAssertEqual(pages.count, 1)

        let hits = try await index.search(query: "Focus")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.id, ObjectID(id))

        let dayHits = try await index.created(on: created)
        XCTAssertEqual(dayHits.count, 1)
    }

    func testIncrementalCreateModifyDelete() async throws {
        try await boot()
        let id = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeee3")!
        let created = ISO8601DateFormatter().date(from: "2026-08-12T08:00:00Z")!
        let path = "objects/page/note.md"

        try await writePage(
            id: id,
            title: "Draft",
            path: path,
            created: created,
            body: "Hello world."
        )
        try await index.applyVaultEvent(relativePath: path, kind: .created)

        var meta = try await index.object(id: ObjectID(id))
        XCTAssertEqual(meta?.title, "Draft")

        try await writePage(
            id: id,
            title: "Published",
            path: path,
            created: created,
            body: "Hello searchable content."
        )
        try await index.applyVaultEvent(relativePath: path, kind: .modified)
        meta = try await index.object(id: ObjectID(id))
        XCTAssertEqual(meta?.title, "Published")
        let search = try await index.search(query: "searchable")
        XCTAssertEqual(search.count, 1)

        try await vault.deleteFile(atRelativePath: path)
        try await index.applyVaultEvent(relativePath: path, kind: .deleted)
        XCTAssertNil(try await index.object(id: ObjectID(id)))
        XCTAssertTrue(try await index.objects(typeID: .page).isEmpty)
    }

    func testNoIndexSqliteInsideVaultAfterIndexing() async throws {
        try await boot()
        let id = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeee4")!
        try await writePage(
            id: id,
            title: "Guardrail",
            path: "objects/page/guard.md",
            created: Date(),
            body: "Body"
        )
        try await index.rebuild()

        let vaultRoot = try await vault.vaultRootURL
        var found: [String] = []
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite"
                    || url.pathExtension == "sqlite"
                    || url.pathExtension == "sqlite-wal"
                    || url.pathExtension == "sqlite-shm"
                {
                    found.append(url.path)
                }
            }
        }
        XCTAssertTrue(found.isEmpty, "found sqlite under vault: \(found)")
    }

    func testIgnoresMarkdownOutsideObjectsAndDaily() async throws {
        try await boot()
        try await vault.writeFile(
            Data("# Scratch\n".utf8),
            atRelativePath: "media/files/readme.md"
        )
        try await index.rebuild()
        XCTAssertTrue(try await index.objects(typeID: .page).isEmpty)
    }

    func testCreatedOnUsesCalendarDayUTC() async throws {
        try await boot()
        let morning = ISO8601DateFormatter().date(from: "2026-08-13T01:00:00Z")!
        let evening = ISO8601DateFormatter().date(from: "2026-08-13T22:00:00Z")!
        let otherDay = ISO8601DateFormatter().date(from: "2026-08-14T12:00:00Z")!

        let id1 = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let id2 = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let id3 = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!

        try await writePage(id: id1, title: "A", path: "objects/page/a.md", created: morning, body: "a")
        try await writePage(id: id2, title: "B", path: "objects/page/b.md", created: evening, body: "b")
        try await writePage(id: id3, title: "C", path: "objects/page/c.md", created: otherDay, body: "c")
        try await index.rebuild()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = ISO8601DateFormatter().date(from: "2026-08-13T12:00:00Z")!

        let queue = try DatabaseQueue(path: index.databaseURL.path)
        let hits = try await queue.read { db in
            try CreatedOnQuery.created(db: db, on: day, calendar: cal)
        }
        XCTAssertEqual(Set(hits.map(\.title)), Set(["A", "B"]))
    }

    func testIndexDatabaseAPIEncodesVaultIDAndDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("idx-api-\(UUID().uuidString)")
        let db = IndexDatabase(vaultID: "test-vault", directory: dir)
        XCTAssertEqual(db.vaultID, "test-vault")
        XCTAssertEqual(db.directory, dir)
        XCTAssertEqual(db.databaseURL.lastPathComponent, "index.sqlite")
        XCTAssertTrue(db.databaseURL.path.contains("test-vault"))
        XCTAssertEqual(LociIndexModule.applicationSupportSubdirectory, "Loci")
        XCTAssertFalse(LociIndexModule.version.isEmpty)
    }

    func testDailyNoteIsIndexed() async throws {
        try await boot()
        let id = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let created = ISO8601DateFormatter().date(from: "2026-08-13T09:00:00Z")!
        let md = """
            ---
            id: \(id.uuidString.lowercased())
            type: daily
            title: 2026-08-13
            created: \(iso(created))
            updated: \(iso(created))
            tags: []
            ---

            Morning thoughts.
            """
        try await vault.writeFile(Data(md.utf8), atRelativePath: "daily/2026-08-13.md")
        try await index.rebuild()

        let dailies = try await index.objects(typeID: .daily)
        XCTAssertEqual(dailies.count, 1)
        XCTAssertEqual(dailies.first?.relativePath, "daily/2026-08-13.md")
        let hits = try await index.search(query: "Morning")
        XCTAssertEqual(hits.first?.typeID, .daily)
    }

    func testSearchEmptyQueryReturnsEmpty() async throws {
        try await boot()
        XCTAssertTrue(try await index.search(query: "   ").isEmpty)
    }
}
