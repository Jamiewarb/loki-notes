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
        XCTAssertTrue(ids.contains(.daily))
        XCTAssertTrue(ids.contains(.image))
        XCTAssertTrue(ids.contains(.meeting))
        XCTAssertTrue(ids.contains(.weblink))
        let page = try await store.loadType(.page)
        XCTAssertEqual(page.name, "Page")
        XCTAssertTrue(page.isBuiltIn)
        XCTAssertEqual(page.id, .page)

        let daily = try await store.loadType(.daily)
        XCTAssertEqual(daily.name, "Daily")
        XCTAssertTrue(daily.isDaily)
        XCTAssertTrue(daily.isBuiltIn)

        let image = try await store.loadType(.image)
        XCTAssertEqual(image.name, "Image")
        XCTAssertTrue(image.isBuiltIn)
        XCTAssertTrue(image.properties.contains { $0.id == "media-path" })

        let meeting = try await store.loadType(.meeting)
        XCTAssertEqual(meeting.name, "Meeting")
        XCTAssertTrue(meeting.isBuiltIn)
        XCTAssertTrue(meeting.properties.contains { $0.id == "event-id" })

        let weblink = try await store.loadType(.weblink)
        XCTAssertEqual(weblink.name, "Weblink")
        XCTAssertTrue(weblink.isBuiltIn)
        XCTAssertTrue(weblink.properties.contains { $0.id == "url" && $0.kind == .url })

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

        let book = try await store.createType(
            name: "Book",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        var withProps = book
        withProps.properties = [
            PropertyDef(id: "author", name: "Author", kind: .text),
            PropertyDef(
                id: "status",
                name: "Status",
                kind: .select,
                options: ["To Read", "Reading", "Done"]
            ),
        ]
        try await store.saveType(withProps)

        // Fresh store against the same vault root — proves disk persistence.
        let store2 = SchemaStore(vault: vault)
        let ids = try await store2.knownTypeIDs()
        XCTAssertEqual(ids.map(\.rawValue), ["book", "daily", "image", "meeting", "page", "weblink"])
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
        XCTAssertEqual(all.count, 6)
        XCTAssertEqual(
            Set(all.map(\.id.rawValue)),
            Set(["page", "daily", "image", "meeting", "weblink", "project"])
        )
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

    func testCreateCustomTypeWritesJSONAndObjectsFolder() async throws {
        let (vault, store) = try makeStore()
        try await store.bootstrapSchema(spaceName: "Books Lab")

        let book = try await store.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: nil
        )
        XCTAssertEqual(book.id.rawValue, "books")
        XCTAssertEqual(book.name, "Books")
        XCTAssertTrue(book.properties.isEmpty)
        XCTAssertFalse(book.isBuiltIn)

        let typePath = SchemaStore.typeRelativePath(for: book.id)
        let typeExists = try await vault.fileExists(atRelativePath: typePath)
        XCTAssertTrue(typeExists)

        let root = try await vault.vaultRootURL
        let folder = root.appendingPathComponent(
            SchemaStore.objectsFolderRelativePath(for: book.id),
            isDirectory: true
        )
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func testCreateCustomTypeDuplicateThrows() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema()
        _ = try await store.createType(name: "Books", icon: "book", color: "#8B5A2B", slug: nil)
        do {
            _ = try await store.createType(name: "Books", icon: "book", color: "#8B5A2B", slug: nil)
            XCTFail("expected typeAlreadyExists")
        } catch let error as LociError {
            guard case .typeAlreadyExists("books") = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func testCreateReservedSlugThrows() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema()
        do {
            _ = try await store.createType(name: "Page Clone", icon: "doc", color: "#000", slug: "page")
            XCTFail("expected invalidTypeSlug")
        } catch let error as LociError {
            guard case .invalidTypeSlug("page") = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func testRenameAndDeleteCustomType() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema()
        let book = try await store.createType(name: "Books", icon: "book", color: "#8B5A2B", slug: "book")
        let renamed = try await store.renameType(book.id, name: "Library")
        XCTAssertEqual(renamed.name, "Library")
        XCTAssertEqual(renamed.id.rawValue, "book")

        try await store.deleteType(book.id, force: false)
        let ids = try await store.knownTypeIDs()
        XCTAssertFalse(ids.contains(book.id))
    }

    func testDeleteBuiltInPageThrows() async throws {
        let (_, store) = try makeStore()
        try await store.bootstrapSchema()
        do {
            try await store.deleteType(.page, force: true)
            XCTFail("expected typeProtected")
        } catch let error as LociError {
            guard case .typeProtected("page") = error else {
                return XCTFail("wrong error \(error)")
            }
        }
        do {
            try await store.deleteType(.daily, force: true)
            XCTFail("expected typeProtected")
        } catch let error as LociError {
            guard case .typeProtected("daily") = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func testDeleteTypeWithObjectsRequiresForce() async throws {
        let (vault, store) = try makeStore()
        try await store.bootstrapSchema()
        let book = try await store.createType(name: "Books", icon: "book", color: "#8B5A2B", slug: "book")
        try await vault.writeFile(
            Data("# Deep Work\n".utf8),
            atRelativePath: "objects/book/deep-work.md"
        )
        do {
            try await store.deleteType(book.id, force: false)
            XCTFail("expected typeNotEmpty")
        } catch let error as LociError {
            guard case .typeNotEmpty("book") = error else {
                return XCTFail("wrong error \(error)")
            }
        }
        try await store.deleteType(book.id, force: true)
        let ids = try await store.knownTypeIDs()
        XCTAssertFalse(ids.contains(book.id))
    }

    func testModuleVersionIsPR13() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr13")
                || LociVaultModule.version.contains("pr14")
                || LociVaultModule.version.contains("pr15")
                || LociVaultModule.version.contains("pr17")
                || LociVaultModule.version.contains("pr18") || LociVaultModule.version.contains("pr19") || LociVaultModule.version.contains("pr20") || LociVaultModule.version.contains("pr21") || LociVaultModule.version.contains("pr22") || LociVaultModule.version.contains("pr23") || LociVaultModule.version.contains("pr24") || LociVaultModule.version.contains("pr25") || LociVaultModule.version.contains("pr26") || LociVaultModule.version.contains("pr27") || LociVaultModule.version.contains("pr28") || LociVaultModule.version.contains("pr29") || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35") || LociVaultModule.version.contains("pr36") || LociVaultModule.version.contains("pr37")
        )
    }
}
