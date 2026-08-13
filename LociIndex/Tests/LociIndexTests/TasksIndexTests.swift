import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class TasksIndexTests: XCTestCase {
    func testIndexProjectsOpenAndTodayTasks() async throws {
        let stamp = UUID().uuidString
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tasks-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tasks-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: vaultParent)
            try? FileManager.default.removeItem(at: indexParent)
        }

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Tasks Test")
        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        var page = try await objects.create(typeID: .page, title: "Ship List")
        try await objects.save(
            meta: page,
            bodyMarkdown: """
                Notes

                - [ ] From page open
                - [x] From page done
                """
        )

        let cal = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 13
        let day = cal.date(from: comps)!
        let openedDaily = try await daily.ensure(for: day, calendar: cal)
        try await objects.save(
            meta: openedDaily.meta,
            bodyMarkdown: """
                Morning

                - [ ] Daily open task
                - [x] Daily done task
                """
        )

        try await index.rebuild()

        let open = try await index.openTasks()
        XCTAssertEqual(Set(open.map(\.text)), Set(["From page open", "Daily open task"]))

        let dayTasks = try await index.tasks(inDailyNoteOn: day, calendar: cal)
        XCTAssertEqual(Set(dayTasks.map(\.text)), Set(["Daily open task", "Daily done task"]))
        XCTAssertEqual(TaskAggregation.open(dayTasks).map(\.text), ["Daily open task"])

        // Toggle via body edit + save → index updates
        let target = open.first { $0.text == "From page open" }!
        let reopened = try await objects.open(id: target.objectID)
        let nextBody = try TaskBodyEdits.toggle(
            bodyMarkdown: reopened.bodyMarkdown,
            blockIndex: target.blockIndex,
            itemIndex: target.itemIndex
        )
        try await objects.save(meta: reopened.meta, bodyMarkdown: nextBody)

        let openAfter = try await index.openTasks()
        XCTAssertFalse(openAfter.contains { $0.text == "From page open" })
        let completed = try await index.tasks(completed: true)
        XCTAssertTrue(completed.contains { $0.text == "From page open" })

        let vaultRoot = try await vault.vaultRootURL
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))
    }
}
