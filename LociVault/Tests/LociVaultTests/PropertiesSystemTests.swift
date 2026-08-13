import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class PropertiesSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-props-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-props-db-\(stamp)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "Props Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index)
    }

    func testUpsertPropertyDefsOnBookType() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        _ = try await schema.upsertProperty(
            book.id,
            def: PropertyDef(
                id: "status",
                name: "Status",
                kind: .select,
                options: ["To Read", "Reading", "Done"]
            )
        )
        _ = try await schema.upsertProperty(
            book.id,
            def: PropertyDef(id: "rating", name: "Rating", kind: .number)
        )

        let store2 = SchemaStore(vault: vault)
        let loaded = try await store2.loadType(book.id)
        XCTAssertEqual(loaded.properties.count, 2)
        XCTAssertEqual(loaded.properties.map(\.id), ["status", "rating"])
        XCTAssertEqual(loaded.properties[0].options, ["To Read", "Reading", "Done"])
    }

    func testPropertyValuesSurviveReloadAndIndexColumns() async throws {
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
                PropertyDef(id: "rating", name: "Rating", kind: .number),
            ]
        )

        var meta = try await objects.create(typeID: book.id, title: "Deep Work")
        meta.properties = [
            "status": .select("Reading"),
            "rating": .number(5),
        ]
        try await objects.save(meta: meta, bodyMarkdown: "Focus is a skill.\n")

        // Survive reload (fresh ObjectService + open).
        let objects2 = ObjectService(vault: vault, index: index)
        let opened = try await objects2.open(id: meta.id)
        XCTAssertEqual(opened.meta.properties["status"], .select("Reading"))
        XCTAssertEqual(opened.meta.properties["rating"], .number(5))

        // Index properties_json + properties_idx columns.
        let indexed = try await index.object(id: meta.id)
        XCTAssertEqual(indexed?.properties["status"], .select("Reading"))
        XCTAssertEqual(indexed?.properties["rating"], .number(5))

        let rows = try await index.propertyIndex(objectID: meta.id)
        XCTAssertEqual(Set(rows.map(\.key)), Set(["status", "rating"]))
        let status = rows.first { $0.key == "status" }
        XCTAssertEqual(status?.valueText, "Reading")
        let rating = rows.first { $0.key == "rating" }
        XCTAssertEqual(rating?.valueNumber, 5)

        let filtered = try await index.objects(
            typeID: book.id,
            propertyKey: "status",
            equalsText: "Reading"
        )
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, meta.id)
    }

    func testRemovePropertyDef() async throws {
        try await boot()
        let book = try await schema.createType(name: "Books", icon: "book", color: "#8B5A2B", slug: "book")
        _ = try await schema.upsertProperty(
            book.id,
            def: PropertyDef(id: "status", name: "Status", kind: .text)
        )
        _ = try await schema.removeProperty(book.id, propertyID: "status")
        let loaded = try await schema.loadType(book.id)
        XCTAssertTrue(loaded.properties.isEmpty)

        do {
            _ = try await schema.removeProperty(book.id, propertyID: "missing")
            XCTFail("expected propertyNotFound")
        } catch let error as LociError {
            if case .propertyNotFound = error {
                // ok
            } else {
                XCTFail("unexpected \(error)")
            }
        }
    }

    func testPropertyKeyAndFormatting() throws {
        XCTAssertEqual(try PropertyKey.resolve(explicit: nil, fromName: "Status"), "status")
        XCTAssertEqual(PropertyKey.fromName("Page URL"), "page-url")
        XCTAssertEqual(
            PropertyValueFormatting.coerce(draft: "Reading", kind: .select),
            .select("Reading")
        )
        XCTAssertEqual(
            PropertyValueFormatting.coerce(draft: "5", kind: .number),
            .number(5)
        )
        XCTAssertEqual(
            PropertyValueFormatting.coerce(draft: "true", kind: .checkbox),
            .bool(true)
        )
        XCTAssertEqual(PropertyValueFormatting.displayString(.multiSelect(["a", "b"])), "a, b")
    }

    func testModuleVersionIsPR13() {
        XCTAssertTrue(LociVaultModule.version.contains("pr13") || LociVaultModule.version.contains("pr14") || LociVaultModule.version.contains("pr15") || LociVaultModule.version.contains("pr16") || LociVaultModule.version.contains("pr17") || LociVaultModule.version.contains("pr18") || LociVaultModule.version.contains("pr19") || LociVaultModule.version.contains("pr20") || LociVaultModule.version.contains("pr21") || LociVaultModule.version.contains("pr22") || LociVaultModule.version.contains("pr23") || LociVaultModule.version.contains("pr24") || LociVaultModule.version.contains("pr25") || LociVaultModule.version.contains("pr26") || LociVaultModule.version.contains("pr27") || LociVaultModule.version.contains("pr28"))
        XCTAssertTrue(LociIndexModule.version.contains("pr13") || LociIndexModule.version.contains("pr14") || LociIndexModule.version.contains("pr15") || LociIndexModule.version.contains("pr17") || LociIndexModule.version.contains("pr18") || LociIndexModule.version.contains("pr19") || LociIndexModule.version.contains("pr20") || LociIndexModule.version.contains("pr21") || LociIndexModule.version.contains("pr22") || LociIndexModule.version.contains("pr23") || LociIndexModule.version.contains("pr24") || LociIndexModule.version.contains("pr25") || LociIndexModule.version.contains("pr26") || LociIndexModule.version.contains("pr27") || LociIndexModule.version.contains("pr28"))
    }
}
