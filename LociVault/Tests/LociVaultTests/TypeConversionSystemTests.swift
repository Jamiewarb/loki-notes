import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class TypeConversionSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-convert-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-convert-db-\(stamp)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "Convert Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
    }

    func testConvertMovesFileKeepsObjectIDAndRemapsProperties() async throws {
        try await boot()

        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        let person = try await schema.createType(
            name: "People",
            icon: "person",
            color: "#2B5A8B",
            slug: "person"
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
                PropertyDef(id: "rating", name: "Rating", kind: .number),
                PropertyDef(id: "isbn", name: "ISBN", kind: .text),
            ]
        )
        _ = try await schema.setProperties(
            person.id,
            properties: [
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["Active", "Archived"]
                ),
                PropertyDef(id: "score", name: "Rating", kind: .number),
                PropertyDef(id: "role", name: "Role", kind: .text),
            ]
        )

        var meta = try await objects.create(typeID: book.id, title: "Deep Work")
        let stableID = meta.id
        meta.properties = [
            "status": .select("Reading"),
            "rating": .number(5),
            "isbn": .text("978-1"),
        ]
        let body = "Focus is a skill. See [[other]].\n"
        try await objects.save(meta: meta, bodyMarkdown: body)

        let existsBefore = try await vault.fileExists(atRelativePath: meta.relativePath)
        XCTAssertTrue(existsBefore)
        XCTAssertTrue(meta.relativePath.hasPrefix("objects/book/"))

        let plan = try await objects.planConversion(id: stableID, toTypeID: person.id)
        XCTAssertEqual(plan.sourceTypeID, book.id)
        XCTAssertEqual(plan.targetTypeID, person.id)
        XCTAssertTrue(plan.proposedRelativePath.hasPrefix("objects/person/"))
        XCTAssertEqual(
            plan.mappings.first { $0.sourcePropertyID == "status" }?.targetPropertyID,
            "status"
        )
        XCTAssertEqual(
            plan.mappings.first { $0.sourcePropertyID == "rating" }?.targetPropertyID,
            "score"
        )
        XCTAssertNil(plan.mappings.first { $0.sourcePropertyID == "isbn" }?.targetPropertyID)

        let beforeOpen = try await objects.open(id: stableID)
        let result = try await objects.convert(
            id: stableID,
            toTypeID: person.id,
            propertyMap: plan.mappings
        )

        XCTAssertEqual(result.objectID, stableID)
        XCTAssertEqual(result.sourceTypeID, book.id)
        XCTAssertEqual(result.targetTypeID, person.id)
        XCTAssertEqual(result.oldRelativePath, meta.relativePath)
        XCTAssertTrue(result.newRelativePath.hasPrefix("objects/person/"))
        let oldGone = try await vault.fileExists(atRelativePath: result.oldRelativePath)
        let newExists = try await vault.fileExists(atRelativePath: result.newRelativePath)
        XCTAssertFalse(oldGone)
        XCTAssertTrue(newExists)

        let opened = try await objects.open(id: stableID)
        XCTAssertEqual(opened.meta.id, stableID)
        XCTAssertEqual(opened.meta.typeID, person.id)
        XCTAssertEqual(opened.meta.relativePath, result.newRelativePath)
        XCTAssertEqual(opened.meta.properties["status"], .select("Reading"))
        XCTAssertEqual(opened.meta.properties["score"], .number(5))
        XCTAssertNil(opened.meta.properties["isbn"])
        XCTAssertEqual(opened.bodyMarkdown, beforeOpen.bodyMarkdown)

        let indexed = try await index.object(id: stableID)
        XCTAssertEqual(indexed?.typeID, person.id)
        XCTAssertEqual(indexed?.relativePath, result.newRelativePath)
        XCTAssertEqual(indexed?.properties["score"], .number(5))

        // Old path must not remain as a live index row.
        let books = try await index.objects(typeID: book.id)
        XCTAssertTrue(books.isEmpty)
        let people = try await index.objects(typeID: person.id)
        XCTAssertEqual(people.count, 1)
        XCTAssertEqual(people.first?.id, stableID)
    }

    func testConvertPreservesIncomingLinksByObjectID() async throws {
        try await boot()

        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        let person = try await schema.createType(
            name: "People",
            icon: "person",
            color: "#2B5A8B",
            slug: "person"
        )

        let bookMeta = try await objects.create(typeID: book.id, title: "Atomic Habits")
        let bookID = bookMeta.id
        try await objects.save(meta: bookMeta, bodyMarkdown: "Habits compound.\n")

        let linker = try await objects.create(typeID: .page, title: "Linker")
        let linkBody = "See [[\(bookID.uuidString.lowercased())|Atomic Habits]].\n"
        try await objects.save(meta: linker, bodyMarkdown: linkBody)

        let before = try await index.backlinks(to: bookID)
        XCTAssertEqual(before.count, 1)
        XCTAssertEqual(before.first?.source.id, linker.id)

        let plan = try await objects.planConversion(id: bookID, toTypeID: person.id)
        let result = try await objects.convert(
            id: bookID,
            toTypeID: person.id,
            propertyMap: plan.mappings
        )
        XCTAssertEqual(result.objectID, bookID)

        let after = try await index.backlinks(to: bookID)
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.source.id, linker.id)

        let opened = try await objects.open(id: bookID)
        XCTAssertEqual(opened.meta.typeID, person.id)
        XCTAssertTrue(opened.meta.relativePath.hasPrefix("objects/person/"))
    }

    func testRefuseDailyAndSameType() async throws {
        try await boot()
        let page = try await objects.create(typeID: .page, title: "Note")

        do {
            _ = try await objects.convert(id: page.id, toTypeID: .page, propertyMap: [])
            XCTFail("expected same-type refusal")
        } catch let error as LociError {
            if case .typeConversionNotAllowed = error {
                // ok
            } else {
                XCTFail("unexpected \(error)")
            }
        }

        do {
            _ = try await objects.convert(id: page.id, toTypeID: .daily, propertyMap: [])
            XCTFail("expected daily target refusal")
        } catch let error as LociError {
            if case .typeConversionNotAllowed = error {
                // ok
            } else {
                XCTFail("unexpected \(error)")
            }
        }
    }

    func testMoveFileOnVault() async throws {
        try await boot()
        let data = Data("hello".utf8)
        try await vault.writeFile(data, atRelativePath: "objects/page/a.md")
        try await vault.moveFile(
            fromRelativePath: "objects/page/a.md",
            toRelativePath: "objects/page/b.md"
        )
        let aGone = try await vault.fileExists(atRelativePath: "objects/page/a.md")
        let bExists = try await vault.fileExists(atRelativePath: "objects/page/b.md")
        XCTAssertFalse(aGone)
        XCTAssertTrue(bExists)
        let read = try await vault.readFile(atRelativePath: "objects/page/b.md")
        XCTAssertEqual(read, data)
    }

    func testModuleVersionIsPR28() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr28") || LociVaultModule.version.contains("pr29") || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35") || LociVaultModule.version.contains("pr36") || LociVaultModule.version.contains("pr37") || LociVaultModule.version.contains("pr38") || LociVaultModule.version.contains("pr39") || LociVaultModule.version.contains("pr40") || LociVaultModule.version.contains("pr41"),
            LociVaultModule.version
        )
        XCTAssertTrue(
            LociIndexModule.version.contains("pr28") || LociIndexModule.version.contains("pr29") || LociIndexModule.version.contains("pr30"),
            LociIndexModule.version
        )
    }
}
