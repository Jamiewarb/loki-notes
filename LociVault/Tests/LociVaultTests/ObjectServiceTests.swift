import XCTest
import Foundation
import LociCore
import LociMarkdown
import LociIndex
@testable import LociVault

final class ObjectServiceTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-objects-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-objects-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        objects = nil
        index = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Object CRUD Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index)
    }

    func testCreateIndexListOpenSaveDeleteLoop() async throws {
        try await boot()

        let created = try await objects.create(typeID: .page, title: "Deep Work")
        XCTAssertEqual(created.typeID, .page)
        XCTAssertEqual(created.title, "Deep Work")
        XCTAssertTrue(created.relativePath.hasPrefix("objects/page/"))
        XCTAssertTrue(created.relativePath.hasSuffix(".md"))
        XCTAssertTrue(created.relativePath.contains("deep-work"))

        let listed = try await index.objects(typeID: .page)
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.id, created.id)

        let opened = try await objects.open(id: created.id)
        XCTAssertEqual(opened.meta.id, created.id)
        XCTAssertEqual(opened.meta.title, "Deep Work")
        XCTAssertTrue(opened.bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        var meta = opened.meta
        meta.title = "Deep Work Notes"
        try await objects.save(meta: meta, bodyMarkdown: "Focus chapter.\n\n#focus")

        let reopened = try await objects.open(id: created.id)
        XCTAssertEqual(reopened.meta.title, "Deep Work Notes")
        XCTAssertTrue(reopened.bodyMarkdown.contains("Focus chapter"))

        let afterSave = try await index.object(id: created.id)
        XCTAssertEqual(afterSave?.title, "Deep Work Notes")
        XCTAssertTrue(afterSave?.tags.contains("focus") == true)

        let search = try await index.search(query: "Focus")
        XCTAssertEqual(search.count, 1)

        try await objects.delete(id: created.id)
        let deletedMeta = try await index.object(id: created.id)
        XCTAssertNil(deletedMeta)
        let pagesAfterDelete = try await index.objects(typeID: .page)
        XCTAssertTrue(pagesAfterDelete.isEmpty)
        let fileExists = try await vault.fileExists(atRelativePath: created.relativePath)
        XCTAssertFalse(fileExists)

        // Tombstone retained under .loci/trash/
        let trashRoot = try await vault.vaultRootURL
            .appendingPathComponent(VaultLayout.trashDirectory, isDirectory: true)
        let trashItems = try FileManager.default.contentsOfDirectory(
            at: trashRoot,
            includingPropertiesForKeys: nil
        )
        XCTAssertFalse(trashItems.isEmpty)

        let vaultRoot = try await vault.vaultRootURL
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))
    }

    func testSlugCollisionFallsBackToUniquePath() async throws {
        try await boot()
        let a = try await objects.create(typeID: .page, title: "Same Title")
        let b = try await objects.create(typeID: .page, title: "Same Title")
        XCTAssertNotEqual(a.relativePath, b.relativePath)
        let pages = try await index.objects(typeID: .page)
        XCTAssertEqual(pages.count, 2)
    }

    func testPathAllocatorSlugify() {
        XCTAssertEqual(ObjectPathAllocator.slugify("Hello Loci"), "hello-loci")
        XCTAssertEqual(ObjectPathAllocator.slugify("  Deep  Work!! "), "deep-work")
        XCTAssertEqual(ObjectPathAllocator.slugify(""), "")
    }

    func testCreateObjectOfCustomTypeAppearsOnlyUnderThatType() async throws {
        try await boot()
        let schema = SchemaStore(vault: vault)
        let bookType = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        let deepWork = try await objects.create(typeID: bookType.id, title: "Deep Work")
        XCTAssertEqual(deepWork.typeID.rawValue, "book")
        XCTAssertTrue(deepWork.relativePath.hasPrefix("objects/book/"))

        let books = try await index.objects(typeID: bookType.id)
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.title, "Deep Work")

        let pages = try await index.objects(typeID: .page)
        XCTAssertTrue(pages.isEmpty)
    }

    func testOpenMissingObjectThrows() async throws {
        try await boot()
        do {
            _ = try await objects.open(id: ObjectID())
            XCTFail("expected objectNotFound")
        } catch let error as LociError {
            guard case .objectNotFound = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }
}
