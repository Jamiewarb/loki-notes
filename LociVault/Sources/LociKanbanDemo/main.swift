import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Books kanban board + card move proofs (PR42).
@main
struct LociKanbanDemo {
    struct BookInfo: Encodable {
        var id: String
        var title: String
        var relativePath: String
        var status: String
        var bodyMarkdown: String
    }

    struct ColumnInfo: Encodable {
        var key: String
        var titles: [String]
    }

    struct DashboardInfo: Encodable {
        var defaultGroupBy: String?
        var defaultView: String
        var relativePath: String
    }

    struct Payload: Encodable {
        var moduleVersion: String
        var indexModuleVersion: String
        var vaultRoot: String
        var indexPath: String
        var indexInsideVault: Bool
        var dailyUnchanged: Bool
        var dailyPath: String
        var objectMarkdownUnchanged: Bool
        var movedTitle: String
        var movedFrom: String
        var movedTo: String
        var yamlSnippet: String
        var yamlStatusDone: Bool
        var typeSchemaChanged: Bool
        var proof: KanbanProof
        var dashboard: DashboardInfo
        var books: [BookInfo]
        var columns: [ColumnInfo]
        var typeSchemaSnippet: String
        var note: String
    }

    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
            of: ":",
            with: "-"
        )
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-kanban-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-kanban-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Kanban")

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

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: calendar)
        let dailyBefore = openedDaily.bodyMarkdown
        let dailyPath = openedDaily.meta.relativePath

        let seeded: [(String, String, String)] = [
            ("Deep Work", "Reading", "Focus is a skill.\n"),
            ("Atomic Habits", "Done", "Tiny changes.\n"),
            ("Range", "Reading", "Generalists.\n"),
            ("So Good They Can't Ignore You", "To Read", "Career capital.\n"),
        ]
        var bookMetas: [LociObjectMeta] = []
        var bodiesBefore: [ObjectID: String] = [:]
        var deepID: ObjectID?
        for (title, status, body) in seeded {
            var meta = try await objects.create(typeID: books.id, title: title)
            meta.properties["status"] = .select(status)
            try await objects.save(meta: meta, bodyMarkdown: body)
            let opened = try await objects.open(id: meta.id)
            bookMetas.append(opened.meta)
            bodiesBefore[opened.meta.id] = opened.bodyMarkdown
            if title == "Deep Work" { deepID = opened.meta.id }
        }

        guard let deepID else {
            throw LociError.objectNotFound(ObjectID())
        }

        let openedDeep = try await objects.open(id: deepID)
        let bodyBeforeMove = openedDeep.bodyMarkdown
        let next = KanbanMove.next(
            meta: openedDeep.meta,
            groupBy: "status",
            destinationKey: "Done",
            properties: [statusDef]
        )
        var movedMeta = openedDeep.meta
        movedMeta.properties = next.properties
        movedMeta.tags = next.tags
        try await objects.save(meta: movedMeta, bodyMarkdown: openedDeep.bodyMarkdown)

        let afterDeep = try await objects.open(id: deepID)
        let yamlData = try await vault.readFile(atRelativePath: afterDeep.meta.relativePath)
        let yamlText = String(data: yamlData, encoding: .utf8) ?? ""
        let yamlStatusDone: Bool
        if case .select(let value) = afterDeep.meta.properties["status"] {
            yamlStatusDone = value == "Done" && yamlText.contains("Done")
        } else {
            yamlStatusDone = false
        }
        let objectMarkdownUnchanged = afterDeep.bodyMarkdown == bodyBeforeMove
            && !KanbanProof.markdownLooksLikeBoardLayout(afterDeep.bodyMarkdown)

        let allHits = try await index.execute(
            QueryDefinition(typeID: books.id, sort: .titleAsc)
        )
        let columns = KanbanMove.columns(
            objects: allHits,
            groupBy: "status",
            properties: [statusDef]
        )

        var type = try await schema.loadType(books.id)
        type.dashboard.defaultGroupBy = "status"
        type.dashboard.defaultView = TypeDashboardConfig.boardView
        type.dashboard.defaultSort = QuerySort.titleAsc.rawValue
        try await schema.saveType(type)

        var bookInfos: [BookInfo] = []
        var allBodiesUnchanged = objectMarkdownUnchanged
        for meta in bookMetas {
            let opened = try await objects.open(id: meta.id)
            if opened.meta.id != deepID, opened.bodyMarkdown != bodiesBefore[meta.id] {
                allBodiesUnchanged = false
            }
            let status: String
            if case .select(let value) = opened.meta.properties["status"] {
                status = value
            } else {
                status = PropertyValueFormatting.displayString(
                    opened.meta.properties["status"] ?? .null
                )
            }
            bookInfos.append(
                BookInfo(
                    id: opened.meta.id.frontMatterIDString,
                    title: opened.meta.title,
                    relativePath: opened.meta.relativePath,
                    status: status,
                    bodyMarkdown: opened.bodyMarkdown
                )
            )
        }

        let dailyAfter = try await daily.open(date: day, calendar: calendar)
        let dailyUnchanged = dailyAfter.bodyMarkdown == dailyBefore

        let typePath = SchemaStore.typeRelativePath(for: books.id)
        let typeData = try await vault.readFile(atRelativePath: typePath)
        let typeJSON = String(data: typeData, encoding: .utf8) ?? ""
        let saved = try JSONDecoder().decode(ObjectType.self, from: typeData)
        let typeSchemaChanged =
            saved.dashboard.defaultView == TypeDashboardConfig.boardView
            && saved.dashboard.defaultGroupBy == "status"

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let proof = KanbanProof.evaluate(
            columnKeys: columns.map(\.key),
            expectedColumnKeys: ["To Read", "Reading", "Done"],
            yamlSnippet: yamlText,
            expectedYAMLValue: "Done",
            bodyBefore: bodyBeforeMove,
            bodyAfter: afterDeep.bodyMarkdown,
            dailyUnchanged: dailyUnchanged,
            indexInsideVault: sqliteInVault
        )

        let payload = Payload(
            moduleVersion: LociVaultModule.version,
            indexModuleVersion: LociIndexModule.version,
            vaultRoot: vaultRoot.path,
            indexPath: index.databaseURL.path,
            indexInsideVault: sqliteInVault,
            dailyUnchanged: dailyUnchanged,
            dailyPath: dailyPath,
            objectMarkdownUnchanged: allBodiesUnchanged,
            movedTitle: "Deep Work",
            movedFrom: "Reading",
            movedTo: "Done",
            yamlSnippet: yamlFrontMatter(yamlText),
            yamlStatusDone: yamlStatusDone,
            typeSchemaChanged: typeSchemaChanged,
            proof: proof,
            dashboard: DashboardInfo(
                defaultGroupBy: saved.dashboard.defaultGroupBy,
                defaultView: saved.dashboard.defaultView,
                relativePath: typePath
            ),
            books: bookInfos.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            },
            columns: columns.map { ColumnInfo(key: $0.key, titles: $0.objects.map(\.title)) },
            typeSchemaSnippet: typeJSON,
            note:
                "PR42: Board columns from DashboardGrouping (select option order). Moving Deep Work Reading→Done updates YAML status via ObjectServing.save. Body, daily notes, and board layout stay out of markdown. Index never in vault."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func yamlFrontMatter(_ markdown: String) -> String {
        guard markdown.hasPrefix("---") else { return String(markdown.prefix(400)) }
        let rest = markdown.dropFirst(3)
        if let end = rest.range(of: "\n---") {
            return String(rest[..<end.lowerBound])
        }
        return String(markdown.prefix(400))
    }
}
