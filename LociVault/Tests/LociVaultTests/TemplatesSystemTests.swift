import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class TemplatesSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tpl-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tpl-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDownWithError() throws {
        daily = nil
        objects = nil
        index = nil
        schema = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Templates Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
    }

    func testTemplateCRUDAndStarDefault() async throws {
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
            ]
        )

        let created = try await schema.createTemplate(
            typeID: book.id,
            name: "Default Book",
            bodyMarkdown: "## Summary\n\n## Quotes\n\n## Notes\n",
            defaultProperties: ["status": .select("To Read")],
            slug: "default",
            makeDefault: true
        )
        XCTAssertEqual(created.id, "book.default")

        let path = SchemaStore.templateRelativePath(for: "book.default")
        let pathExists = try await vault.fileExists(atRelativePath: path)
        XCTAssertTrue(pathExists)

        let loaded = try await schema.loadTemplate("book.default")
        XCTAssertEqual(loaded.name, "Default Book")
        XCTAssertTrue(loaded.bodyMarkdown.contains("## Summary"))
        XCTAssertEqual(loaded.defaultProperties["status"], .select("To Read"))

        let type = try await schema.loadType(book.id)
        XCTAssertEqual(type.defaultTemplateID, "book.default")
        XCTAssertTrue(type.templateIDs.contains("book.default"))

        let listed = try await schema.listTemplates(typeID: book.id)
        XCTAssertEqual(listed.count, 1)

        // Round-trip via fresh store.
        let store2 = SchemaStore(vault: vault)
        let again = try await store2.loadTemplate("book.default")
        XCTAssertEqual(again, loaded)
    }

    func testCreateObjectAppliesBookDefaultTemplate() async throws {
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
        _ = try await schema.createTemplate(
            typeID: book.id,
            name: "Default Book",
            bodyMarkdown: "## Summary\n\n## Quotes\n\n## Notes\n",
            defaultProperties: [
                "status": .select("To Read"),
                "rating": .number(0),
            ],
            slug: "default",
            makeDefault: true
        )

        let meta = try await objects.create(typeID: book.id, title: "Deep Work")
        XCTAssertEqual(meta.properties["status"], .select("To Read"))
        XCTAssertEqual(meta.properties["rating"], .number(0))

        let opened = try await objects.open(id: meta.id)
        XCTAssertTrue(opened.bodyMarkdown.contains("## Summary"))
        XCTAssertTrue(opened.bodyMarkdown.contains("## Quotes"))
        XCTAssertTrue(opened.bodyMarkdown.contains("## Notes"))
        XCTAssertEqual(opened.meta.properties["status"], .select("To Read"))

        let data = try await vault.readFile(atRelativePath: meta.relativePath)
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("template: book.default"))
    }

    func testDailyUsesDailyTemplate() async throws {
        try await boot()
        _ = try await schema.createTemplate(
            typeID: .daily,
            name: "Daily Default",
            bodyMarkdown: "## Morning\n\n## Evening\n",
            defaultProperties: [:],
            slug: "default",
            makeDefault: true
        )

        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let opened = try await daily.ensure(for: day, calendar: calendar)
        XCTAssertTrue(opened.bodyMarkdown.contains("## Morning"))
        XCTAssertTrue(opened.bodyMarkdown.contains("## Evening"))

        let data = try await vault.readFile(atRelativePath: "daily/2026-08-13.md")
        let text = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("template: daily.default"))
        XCTAssertTrue(text.contains("## Morning"))
    }

    func testApplyTemplateIfEmptyOnlyWhenBlank() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        _ = try await schema.createTemplate(
            typeID: book.id,
            name: "Default Book",
            bodyMarkdown: "## Summary\n",
            defaultProperties: ["status": .select("To Read")],
            slug: "default",
            makeDefault: false
        )

        // Create without default (none starred).
        let meta = try await objects.create(typeID: book.id, title: "Blank Book")
        let applied = try await objects.applyTemplateIfEmpty(id: meta.id, templateID: "book.default")
        XCTAssertTrue(applied.bodyMarkdown.contains("## Summary"))
        XCTAssertEqual(applied.meta.properties["status"], .select("To Read"))

        // Non-empty body is left alone.
        try await objects.save(meta: applied.meta, bodyMarkdown: "## Already written\n")
        let skipped = try await objects.applyTemplateIfEmpty(id: meta.id, templateID: "book.default")
        XCTAssertTrue(skipped.bodyMarkdown.contains("## Already written"))
        XCTAssertFalse(skipped.bodyMarkdown.contains("## Summary"))
    }

    func testDeleteTemplateClearsDefault() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        _ = try await schema.createTemplate(
            typeID: book.id,
            name: "Default Book",
            bodyMarkdown: "## X\n",
            defaultProperties: [:],
            slug: "default",
            makeDefault: true
        )
        try await schema.deleteTemplate("book.default")
        let type = try await schema.loadType(book.id)
        XCTAssertNil(type.defaultTemplateID)
        XCTAssertFalse(type.templateIDs.contains("book.default"))
        let stillThere = try await vault.fileExists(
            atRelativePath: SchemaStore.templateRelativePath(for: "book.default")
        )
        XCTAssertFalse(stillThere)
    }

    func testModuleVersionIsPR14() {
        XCTAssertTrue(LociVaultModule.version.contains("pr14") || LociVaultModule.version.contains("pr15") || LociVaultModule.version.contains("pr16") || LociVaultModule.version.contains("pr17") || LociVaultModule.version.contains("pr18"))
        XCTAssertTrue(LociIndexModule.version.contains("pr14") || LociIndexModule.version.contains("pr15") || LociIndexModule.version.contains("pr17") || LociIndexModule.version.contains("pr18"))
    }
}
