import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: task projection + Today/Open aggregation for DevHarness Tasks panel (PR19).
@main
struct LociTasksDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tasks-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tasks-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Tasks")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 13
        let day = cal.date(from: comps)!

        let openedDaily = try await daily.ensure(for: day, calendar: cal)
        try await objects.save(
            meta: openedDaily.meta,
            bodyMarkdown: """
                Focus day

                - [ ] Review PR19 Tasks
                - [x] Seed daily note
                """
        )

        var page = try await objects.create(typeID: .page, title: "Launch Checklist")
        try await objects.save(
            meta: page,
            bodyMarkdown: """
                Page tasks

                - [ ] Check task in a Page
                - [ ] Write evidence
                - [x] Scaffold feature folder
                """
        )
        page = try await index.object(id: page.id) ?? page

        try await index.rebuild()

        // Simulate demo: check the page task → completed in Open / Today lists.
        let beforeOpen = try await index.openTasks()
        guard let target = beforeOpen.first(where: { $0.text == "Check task in a Page" }) else {
            throw LociError.notImplemented("expected open page task")
        }
        let reopened = try await objects.open(id: target.objectID)
        let toggledBody = try TaskBodyEdits.toggle(
            bodyMarkdown: reopened.bodyMarkdown,
            blockIndex: target.blockIndex,
            itemIndex: target.itemIndex
        )
        try await objects.save(meta: reopened.meta, bodyMarkdown: toggledBody)

        let openTasks = try await index.openTasks()
        let todayTasks = try await index.tasks(inDailyNoteOn: day, calendar: cal)
        let completed = try await index.tasks(completed: true)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let pageCompleted = completed.contains { $0.text == "Check task in a Page" }
        let pageStillOpen = openTasks.contains { $0.text == "Check task in a Page" }
        let dailyOpen = TaskAggregation.open(todayTasks)

        let payload: [String: Any] = [
            "moduleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "vaultModuleVersion": LociVaultModule.version,
            "sqliteEngine": "GRDB",
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "vaultID": index.vaultID,
            "indexInsideVault": sqliteInVault,
            "day": DailyNoteIdentity.title(for: day, calendar: cal),
            "dailyPath": DailyNoteIdentity.relativePath(for: day, calendar: cal),
            "todayTasks": todayTasks.map { taskJSON($0) },
            "openTasks": openTasks.map { taskJSON($0) },
            "completedTasks": completed.map { taskJSON($0) },
            "proof": [
                "pageToggleCompleted": pageCompleted && !pageStillOpen,
                "dailyOpenCount": dailyOpen.count,
                "openCount": openTasks.count,
                "todayCount": todayTasks.count,
                "completedCount": completed.count,
                "indexOutsideVault": !sqliteInVault,
                "dailyHasOpen": dailyOpen.contains { $0.text == "Review PR19 Tasks" },
            ],
            "note":
                "PR19: Task blocks index into tasks table; Today = daily note tasks; Open = incomplete; toggles persist via ObjectServing.save.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func taskJSON(_ task: IndexedTask) -> [String: Any] {
        [
            "id": task.id,
            "objectId": task.objectID.uuidString.lowercased(),
            "objectTitle": task.objectTitle,
            "type": task.objectTypeID.rawValue,
            "relativePath": task.relativePath,
            "blockIndex": task.blockIndex,
            "itemIndex": task.itemIndex,
            "text": task.text,
            "completed": task.isCompleted,
        ]
    }
}
