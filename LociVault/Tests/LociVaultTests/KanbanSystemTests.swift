import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class KanbanSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-kanban-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-kanban-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
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
        try await schema.bootstrapSchema(spaceName: "Kanban Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
    }

    func testMoveUpdatesVaultYAMLNotBodyOrDaily() async throws {
        try await boot()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: calendar)
        let dailyBefore = openedDaily.bodyMarkdown

        let books = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        let statusDef = PropertyDef(
            id: "status",
            name: "Status",
            kind: .select,
            options: ["To Read", "Reading", "Done"]
        )
        _ = try await schema.setProperties(books.id, properties: [statusDef])

        var deep = try await objects.create(typeID: books.id, title: "Deep Work")
        deep.properties["status"] = .select("Reading")
        try await objects.save(meta: deep, bodyMarkdown: "Focus is a skill.\n")
        var habits = try await objects.create(typeID: books.id, title: "Atomic Habits")
        habits.properties["status"] = .select("Done")
        try await objects.save(meta: habits, bodyMarkdown: "Tiny changes.\n")
        var toRead = try await objects.create(typeID: books.id, title: "Range")
        toRead.properties["status"] = .select("To Read")
        try await objects.save(meta: toRead, bodyMarkdown: "Generalists.\n")

        let beforeDeep = try await objects.open(id: deep.id)
        let next = KanbanMove.next(
            meta: beforeDeep.meta,
            groupBy: "status",
            destinationKey: "Done",
            properties: [statusDef]
        )
        var moved = beforeDeep.meta
        moved.properties = next.properties
        moved.tags = next.tags
        try await objects.save(meta: moved, bodyMarkdown: beforeDeep.bodyMarkdown)

        let afterDeep = try await objects.open(id: deep.id)
        XCTAssertEqual(afterDeep.bodyMarkdown, beforeDeep.bodyMarkdown)
        XCTAssertEqual(afterDeep.meta.properties["status"], .select("Done"))
        XCTAssertFalse(KanbanProof.markdownLooksLikeBoardLayout(afterDeep.bodyMarkdown))

        let yaml = String(
            data: try await vault.readFile(atRelativePath: afterDeep.meta.relativePath),
            encoding: .utf8
        ) ?? ""
        XCTAssertTrue(yaml.contains("Done"))
        XCTAssertFalse(yaml.contains("kanban-column"))

        let hits = try await index.execute(
            QueryDefinition(typeID: books.id, sort: .titleAsc)
        )
        let columns = KanbanMove.columns(
            objects: hits,
            groupBy: "status",
            properties: [statusDef]
        )
        XCTAssertEqual(columns.map(\.key), ["To Read", "Reading", "Done"])
        XCTAssertEqual(columns[2].objects.map(\.title), ["Atomic Habits", "Deep Work"])

        var type = try await schema.loadType(books.id)
        type.dashboard.defaultView = TypeDashboardConfig.boardView
        type.dashboard.defaultGroupBy = "status"
        try await schema.saveType(type)
        let saved = try JSONDecoder().decode(
            ObjectType.self,
            from: try await vault.readFile(
                atRelativePath: SchemaStore.typeRelativePath(for: books.id)
            )
        )
        XCTAssertEqual(saved.dashboard.defaultView, "board")

        let dailyAfter = try await daily.open(date: day, calendar: calendar)
        XCTAssertEqual(dailyAfter.bodyMarkdown, dailyBefore)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
            }
        }
        XCTAssertFalse(sqliteInVault)
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))

        let proof = KanbanProof.evaluate(
            columnKeys: columns.map(\.key),
            expectedColumnKeys: ["To Read", "Reading", "Done"],
            yamlSnippet: yaml,
            expectedYAMLValue: "Done",
            bodyBefore: beforeDeep.bodyMarkdown,
            bodyAfter: afterDeep.bodyMarkdown,
            dailyUnchanged: dailyAfter.bodyMarkdown == dailyBefore,
            indexInsideVault: sqliteInVault
        )
        XCTAssertTrue(proof.boardColumnsFromGroup)
        XCTAssertTrue(proof.moveUpdatesVaultYAML)
        XCTAssertTrue(proof.layoutNotWrittenToMarkdown)
        XCTAssertFalse(proof.indexInsideVault)
    }

    func testModuleVersionIsPR42() {
        XCTAssertTrue(LociVaultModule.version.contains("pr42") || LociVaultModule.version.contains("pr43"), LociVaultModule.version)
        XCTAssertTrue(
            LociVaultModule.version == "0.42.0-pr42" || LociVaultModule.version == "0.43.0-pr43",
            LociVaultModule.version
        )
    }
}
