import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class QueryEngineTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-qe-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-qe-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        objects = nil
        index = nil
        schema = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Query Engine Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
    }

    func testTypeTagsPropertyAndDateRangeFilters() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        _ = try await schema.setProperties(
            book.id,
            properties: [
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["To Read", "Reading", "Done"]
                ),
                PropertyDef(id: "pages", name: "Pages", kind: .number),
            ]
        )

        let early = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
        let mid = ISO8601DateFormatter().date(from: "2026-06-01T12:00:00Z")!
        let late = ISO8601DateFormatter().date(from: "2026-08-01T12:00:00Z")!

        var deep = try await objects.create(typeID: book.id, title: "Deep Work")
        deep.created = early
        deep.updated = early
        deep.tags = ["focus"]
        deep.properties["status"] = .select("Reading")
        deep.properties["pages"] = .number(300)
        try await objects.save(meta: deep, bodyMarkdown: "Focus.\n")

        var habits = try await objects.create(typeID: book.id, title: "Atomic Habits")
        habits.created = mid
        habits.updated = mid
        habits.tags = ["habits"]
        habits.properties["status"] = .select("Done")
        habits.properties["pages"] = .number(250)
        try await objects.save(meta: habits, bodyMarkdown: "Habits.\n")

        var range = try await objects.create(typeID: book.id, title: "Range")
        range.created = late
        range.updated = late
        range.tags = ["focus", "general"]
        range.properties["status"] = .select("Reading")
        range.properties["pages"] = .number(350)
        try await objects.save(meta: range, bodyMarkdown: "Range.\n")

        _ = try await objects.create(typeID: .page, title: "Unrelated page")

        // Type + tag + property equals
        let readingFocus = try await index.execute(
            QueryDefinition(
                typeID: book.id,
                tags: ["focus"],
                properties: [.equals("status", text: "Reading")],
                sort: .titleAsc
            )
        )
        XCTAssertEqual(readingFocus.map(\.title).sorted(), ["Deep Work", "Range"])

        // Tag any mode
        let anyTag = try await index.execute(
            QueryDefinition(
                typeID: book.id,
                tags: ["habits", "general"],
                tagMode: .any,
                sort: .titleAsc
            )
        )
        XCTAssertEqual(anyTag.map(\.title).sorted(), ["Atomic Habits", "Range"])

        // Property numeric gt
        let longBooks = try await index.execute(
            QueryDefinition(
                typeID: book.id,
                properties: [.greaterThan("pages", number: 280)],
                sort: .titleAsc
            )
        )
        XCTAssertEqual(longBooks.map(\.title).sorted(), ["Deep Work", "Range"])

        // Created range (mid → late inclusive)
        let recent = try await index.execute(
            QueryDefinition(
                typeID: book.id,
                created: DateRangeFilter(from: mid, to: late),
                sort: .createdAsc
            )
        )
        XCTAssertEqual(recent.map(\.title), ["Atomic Habits", "Range"])

        // Limit
        let limited = try await index.execute(
            QueryDefinition(typeID: book.id, limit: 1, sort: .titleAsc)
        )
        XCTAssertEqual(limited.count, 1)
        XCTAssertEqual(limited.first?.title, "Atomic Habits")
    }

    func testSavedQueryVaultCRUDAndExecute() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        var deep = try await objects.create(typeID: book.id, title: "Deep Work")
        deep.tags = ["focus"]
        try await objects.save(meta: deep, bodyMarkdown: "x\n")
        _ = try await objects.create(typeID: book.id, title: "Other")

        let created = try await schema.createQuery(
            name: "Focus books",
            definition: QueryDefinition(typeID: book.id, tags: ["focus"]),
            slug: "focus-books",
            pinnedTypeID: book.id
        )
        XCTAssertEqual(created.id, "focus-books")
        let path = SchemaStore.queryRelativePath(for: "focus-books")
        XCTAssertEqual(path, ".loci/queries/focus-books.json")
        let exists = try await vault.fileExists(atRelativePath: path)
        XCTAssertTrue(exists)

        let data = try await vault.readFile(atRelativePath: path)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("focus-books"))
        XCTAssertFalse(json.contains("Deep Work")) // no live results in vault file

        let pinned = try await schema.listPinnedQueries(typeID: book.id)
        XCTAssertEqual(pinned.map(\.id), ["focus-books"])

        let hits = try await index.execute(created.definition)
        XCTAssertEqual(hits.map(\.title), ["Deep Work"])

        _ = try await schema.setQueryPinned("focus-books", typeID: nil)
        let unpinned = try await schema.listPinnedQueries(typeID: book.id)
        XCTAssertTrue(unpinned.isEmpty)

        try await schema.deleteQuery("focus-books")
        let gone = try await vault.fileExists(atRelativePath: path)
        XCTAssertFalse(gone)
    }

    func testQueriesSkeletonAndDuplicateRejected() async throws {
        try await boot()
        XCTAssertTrue(VaultLayout.requiredDirectories.contains(VaultLayout.queriesDirectory))
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(VaultLayout.queriesDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)

        _ = try await schema.createQuery(
            name: "Inbox",
            definition: QueryDefinition(typeID: .page),
            slug: "inbox",
            pinnedTypeID: nil
        )
        do {
            _ = try await schema.createQuery(
                name: "Inbox 2",
                definition: QueryDefinition(typeID: .page),
                slug: "inbox",
                pinnedTypeID: nil
            )
            XCTFail("expected queryAlreadyExists")
        } catch LociError.queryAlreadyExists("inbox") {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testModuleVersionsIncludePR23() {
        XCTAssertTrue(LociVaultModule.version.contains("pr23") || LociVaultModule.version.contains("pr24") || LociVaultModule.version.contains("pr25") || LociVaultModule.version.contains("pr26") || LociVaultModule.version.contains("pr27") || LociVaultModule.version.contains("pr28") || LociVaultModule.version.contains("pr29") || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35") || LociVaultModule.version.contains("pr36") || LociVaultModule.version.contains("pr37") || LociVaultModule.version.contains("pr38") || LociVaultModule.version.contains("pr39"))
        XCTAssertTrue(LociIndexModule.version.contains("pr23") || LociIndexModule.version.contains("pr24") || LociIndexModule.version.contains("pr25") || LociIndexModule.version.contains("pr26") || LociIndexModule.version.contains("pr27") || LociIndexModule.version.contains("pr28") || LociIndexModule.version.contains("pr29") || LociIndexModule.version.contains("pr30"))
        XCTAssertTrue(LociMarkdownModule.version.contains("pr23") || LociMarkdownModule.version.contains("pr24") || LociMarkdownModule.version.contains("pr25") || LociMarkdownModule.version.contains("pr26") || LociMarkdownModule.version.contains("pr27") || LociMarkdownModule.version.contains("pr28") || LociMarkdownModule.version.contains("pr29") || LociMarkdownModule.version.contains("pr30"))
    }
}
