import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class CollectionsSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-col-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-col-db-\(stamp)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "Collections Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
    }

    func testCollectionCRUDAndVaultPath() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )

        let created = try await schema.createCollection(
            typeID: book.id,
            name: "Favorites",
            slug: "favorites"
        )
        XCTAssertEqual(created.id, "book.favorites")
        XCTAssertTrue(created.memberIDs.isEmpty)

        let path = SchemaStore.collectionRelativePath(for: "book.favorites")
        XCTAssertEqual(path, ".loci/collections/book.favorites.json")
        let exists = try await vault.fileExists(atRelativePath: path)
        XCTAssertTrue(exists)

        let listed = try await schema.listCollections(typeID: book.id)
        XCTAssertEqual(listed.map(\.id), ["book.favorites"])

        // Round-trip via fresh store (disk is truth).
        let store2 = SchemaStore(vault: vault)
        let again = try await store2.loadCollection("book.favorites")
        XCTAssertEqual(again.id, created.id)
        XCTAssertEqual(again.name, "Favorites")

        try await schema.deleteCollection("book.favorites")
        let gone = try await vault.fileExists(atRelativePath: path)
        XCTAssertFalse(gone)
        let afterDelete = try await schema.listCollections(typeID: book.id)
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testAddRemoveMembershipPreservesOrder() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        let a = try await objects.create(typeID: book.id, title: "Deep Work")
        let b = try await objects.create(typeID: book.id, title: "Atomic Habits")
        let c = try await objects.create(typeID: book.id, title: "Range")

        _ = try await schema.createCollection(
            typeID: book.id,
            name: "Reading List",
            slug: "reading-list"
        )

        var col = try await schema.addToCollection("book.reading-list", objectID: a.id)
        col = try await schema.addToCollection("book.reading-list", objectID: b.id)
        col = try await schema.addToCollection("book.reading-list", objectID: c.id)
        // Idempotent add.
        col = try await schema.addToCollection("book.reading-list", objectID: a.id)
        XCTAssertEqual(col.memberIDs, [a.id, b.id, c.id])

        col = try await schema.removeFromCollection("book.reading-list", objectID: b.id)
        XCTAssertEqual(col.memberIDs, [a.id, c.id])

        do {
            _ = try await schema.removeFromCollection("book.reading-list", objectID: b.id)
            XCTFail("expected collectionMemberNotFound")
        } catch LociError.collectionMemberNotFound {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }

        // Membership is vault JSON, not index.
        let data = try await vault.readFile(
            atRelativePath: SchemaStore.collectionRelativePath(for: "book.reading-list")
        )
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains(a.id.frontMatterIDString))
        XCTAssertTrue(json.contains(c.id.frontMatterIDString))
        XCTAssertFalse(json.contains(b.id.frontMatterIDString))
    }

    func testCollectionsSkeletonDirectoryAndDuplicateRejected() async throws {
        try await boot()
        XCTAssertTrue(VaultLayout.requiredDirectories.contains(VaultLayout.collectionsDirectory))
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(VaultLayout.collectionsDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)

        _ = try await schema.createCollection(typeID: .page, name: "Inbox", slug: "inbox")
        do {
            _ = try await schema.createCollection(typeID: .page, name: "Inbox 2", slug: "inbox")
            XCTFail("expected collectionAlreadyExists")
        } catch LociError.collectionAlreadyExists("page.inbox") {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testModuleVersionsIncludePR22() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr2")
                || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35") || LociVaultModule.version.contains("pr36")
        )
        XCTAssertTrue(
            LociIndexModule.version.contains("pr2")
                || LociIndexModule.version.contains("pr30")
        )
        XCTAssertTrue(
            LociMarkdownModule.version.contains("pr2")
                || LociMarkdownModule.version.contains("pr30")
        )
    }
}
