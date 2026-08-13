import XCTest
import LociCore
@testable import LociVault

final class SchemaStoreTests: XCTestCase {
    private var tempParent: URL!

    override func setUpWithError() throws {
        tempParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-schema-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempParent {
            try? FileManager.default.removeItem(at: tempParent)
        }
    }

    private func makeStore() throws -> (VaultService, SchemaStore) {
        let vault = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        return (vault, SchemaStore(vault: vault))
    }

    func testBootstrapSeedsPageType() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema(spaceName: "Schema Lab")

        let ids = try await store.knownTypeIDs()
        XCTAssertTrue(ids.contains(.page))
        let page = try await store.loadType(.page)
        XCTAssertEqual(page.name, "Page")
        XCTAssertTrue(page.isBuiltIn)
        XCTAssertEqual(page.id, .page)

        let settings = try await store.loadSpaceSettings()
        XCTAssertEqual(settings.name, "Schema Lab")
    }

    func testEnsureSkeletonAlsoSeedsPage() async throws {
        let (vault, store) = try makeStore()
        try await vault.ensureSkeleton(spaceName: "Via Skeleton")
        let pagePath = SchemaStore.typeRelativePath(for: .page)
        let exists = try await vault.fileExists(atRelativePath: pagePath)
        XCTAssertTrue(exists)
        let page = try await store.loadType(.page)
        XCTAssertEqual(page.name, "Page")
    }

    func testBootstrapIsIdempotentAndPreservesSpacePins() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema(spaceName: "Pinned Space")
        var settings = try await store.loadSpaceSettings()
        settings.pins = ["page"]
        try await store.saveSpaceSettings(settings)

        try await store.bootstrapSchema(spaceName: "Should Not Overwrite")
        let again = try await store.loadSpaceSettings()
        XCTAssertEqual(again.name, "Pinned Space")
        XCTAssertEqual(again.pins, ["page"])

        let page = try await store.loadType(.page)
        XCTAssertEqual(page.name, "Page")
    }

    func testAddCustomTypeThenReload() async throws {
        let (vault, store) = try makeStore()
        try await store.bootstrapSchema(spaceName: "Custom")

        let book = ObjectType(
            id: ObjectTypeID("book"),
            name: "Book",
            icon: "book",
            color: "#8B5A2B",
            properties: [
                PropertyDef(id: "author", name: "Author", kind: .text),
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["To Read", "Reading", "Done"]
                ),
            ]
        )
        try await store.saveType(book)

        // Fresh store against the same vault root — proves disk persistence.
        let store2 = SchemaStore(vault: vault)
        let ids = try await store2.knownTypeIDs()
        XCTAssertEqual(ids.map(\.rawValue), ["book", "page"])
        let loaded = try await store2.loadType(ObjectTypeID("book"))
        XCTAssertEqual(loaded.name, "Book")
        XCTAssertEqual(loaded.properties.count, 2)
        XCTAssertEqual(loaded.properties[1].kind, .select)
    }

    func testAllTypesIncludesPageAndCustom() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema()
        try await store.saveType(
            ObjectType(id: ObjectTypeID("project"), name: "Project", icon: "folder")
        )
        let all = try await store.allTypes()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(Set(all.map(\.id.rawValue)), Set(["page", "project"]))
    }

    func testLoadMissingTypeThrowsSchemaNotFound() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema()
        do {
            _ = try await store.loadType(ObjectTypeID("missing"))
            XCTFail("expected schemaNotFound")
        } catch let error as LociError {
            guard case .schemaNotFound(let path) = error else {
                return XCTFail("wrong error \(error)")
            }
            XCTAssertTrue(path.contains("missing.json"))
        }
    }

    func testTypeRelativePathShape() {
        XCTAssertEqual(
            SchemaStore.typeRelativePath(for: .page),
            ".loci/types/page.json"
        )
        XCTAssertEqual(
            SchemaStore.typeRelativePath(for: ObjectTypeID("book")),
            ".loci/types/book.json"
        )
    }

    func testPageJSONIsPrettyPrintedOnDisk() async throws {
        let (vault, store) = try makeStore()
        try await store.bootstrapSchema()
        let data = try await vault.readFile(atRelativePath: ".loci/types/page.json")
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("\"id\""))
        XCTAssertTrue(text.contains("page"))
        XCTAssertTrue(text.contains("\n"), "expected pretty-printed JSON")
    }

    func testModuleVersionIsPR08() {
        XCTAssertTrue(LociVaultModule.version.contains("pr08"))
    }
}
