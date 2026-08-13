import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class DashboardSystemTests: XCTestCase {
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
            .appendingPathComponent("loci-dash-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-dash-db-\(stamp)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "Dashboard Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
    }

    func testFilterSortGroupDoesNotRewriteObjectOrDailyMarkdown() async throws {
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
        _ = try await schema.setProperties(
            books.id,
            properties: [
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["To Read", "Reading", "Done"]
                )
            ]
        )

        var deep = try await objects.create(typeID: books.id, title: "Deep Work")
        deep.properties["status"] = .select("Reading")
        try await objects.save(meta: deep, bodyMarkdown: "Focus is a skill.\n")
        var habits = try await objects.create(typeID: books.id, title: "Atomic Habits")
        habits.properties["status"] = .select("Done")
        try await objects.save(meta: habits, bodyMarkdown: "Tiny changes.\n")
        var range = try await objects.create(typeID: books.id, title: "Range")
        range.properties["status"] = .select("Reading")
        try await objects.save(meta: range, bodyMarkdown: "Generalists.\n")

        let beforeDeep = try await objects.open(id: deep.id)
        let beforeHabits = try await objects.open(id: habits.id)
        let beforeRange = try await objects.open(id: range.id)

        let definition = DashboardQuery.definition(
            typeID: books.id,
            filterKey: "status",
            filterText: "Reading",
            sort: .titleAsc
        )
        let hits = try await index.execute(definition)
        XCTAssertEqual(hits.map(\.title), ["Deep Work", "Range"])

        let grouped = DashboardGrouping.sections(objects: hits, groupBy: "status")
        XCTAssertEqual(grouped.map(\.key), ["Reading"])

        var type = try await schema.loadType(books.id)
        type.dashboard.defaultSort = QuerySort.titleAsc.rawValue
        type.dashboard.defaultGroupBy = "status"
        type.dashboard.defaultFilterKey = "status"
        type.dashboard.defaultFilterText = "Reading"
        try await schema.saveType(type)

        let afterDeep = try await objects.open(id: deep.id)
        let afterHabits = try await objects.open(id: habits.id)
        let afterRange = try await objects.open(id: range.id)
        XCTAssertEqual(afterDeep.bodyMarkdown, beforeDeep.bodyMarkdown)
        XCTAssertEqual(afterHabits.bodyMarkdown, beforeHabits.bodyMarkdown)
        XCTAssertEqual(afterRange.bodyMarkdown, beforeRange.bodyMarkdown)
        XCTAssertEqual(afterDeep.meta.properties["status"], .select("Reading"))

        let dailyAfter = try await daily.open(date: day, calendar: calendar)
        XCTAssertEqual(dailyAfter.bodyMarkdown, dailyBefore)

        let typeJSON = try await vault.readFile(
            atRelativePath: SchemaStore.typeRelativePath(for: books.id)
        )
        let saved = try JSONDecoder().decode(ObjectType.self, from: typeJSON)
        XCTAssertEqual(saved.dashboard.defaultSort, "titleAsc")
        XCTAssertEqual(saved.dashboard.defaultGroupBy, "status")
        XCTAssertEqual(saved.dashboard.defaultFilterKey, "status")
        XCTAssertEqual(saved.dashboard.defaultFilterText, "Reading")

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

        let proof = DashboardViewProof.evaluate(
            filteredTitles: hits.map(\.title),
            expectedFilteredTitles: ["Deep Work", "Range"],
            sortedTitles: hits.map(\.title),
            expectedSortedTitles: ["Deep Work", "Range"],
            sectionKeys: grouped.map(\.key),
            expectedSectionKey: "Reading",
            objectMarkdownUnchanged: afterDeep.bodyMarkdown == beforeDeep.bodyMarkdown,
            dailyUnchanged: dailyAfter.bodyMarkdown == dailyBefore,
            indexInsideVault: sqliteInVault
        )
        XCTAssertTrue(proof.filterApplied)
        XCTAssertTrue(proof.sortApplied)
        XCTAssertTrue(proof.groupApplied)
        XCTAssertTrue(proof.resultsNotWrittenToMarkdown)
        XCTAssertFalse(proof.indexInsideVault)
    }

    func testModuleVersionIsPR41() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr41") || LociVaultModule.version.contains("pr42") || LociVaultModule.version.contains("pr43"),
            LociVaultModule.version
        )
        XCTAssertTrue(
            LociVaultModule.version == "0.41.0-pr41" || LociVaultModule.version == "0.42.0-pr42" || LociVaultModule.version == "0.43.0-pr43",
            LociVaultModule.version
        )
    }
}
