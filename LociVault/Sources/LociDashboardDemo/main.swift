import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Books dashboard filter / sort / group proofs (PR41).
@main
struct LociDashboardDemo {
    struct BookInfo: Encodable {
        var id: String
        var title: String
        var relativePath: String
        var status: String
        var bodyMarkdown: String
    }

    struct SectionInfo: Encodable {
        var key: String
        var titles: [String]
    }

    struct DashboardInfo: Encodable {
        var defaultSort: String?
        var defaultGroupBy: String?
        var defaultFilterKey: String?
        var defaultFilterText: String?
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
        var typeSchemaChanged: Bool
        var proof: DashboardViewProof
        var dashboard: DashboardInfo
        var books: [BookInfo]
        var filteredTitles: [String]
        var sections: [SectionInfo]
        var unfilteredSectionKeys: [String]
        var typeSchemaSnippet: String
        var note: String
    }

    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
            of: ":",
            with: "-"
        )
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-dashboard-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-dashboard-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Dashboard")

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
        for (title, status, body) in seeded {
            var meta = try await objects.create(typeID: books.id, title: title)
            meta.properties["status"] = .select(status)
            try await objects.save(meta: meta, bodyMarkdown: body)
            let opened = try await objects.open(id: meta.id)
            bookMetas.append(opened.meta)
            bodiesBefore[opened.meta.id] = opened.bodyMarkdown
        }

        let definition = DashboardQuery.definition(
            typeID: books.id,
            filterKey: "status",
            filterText: "Reading",
            sort: .titleAsc
        )
        let hits = try await index.execute(definition)
        let grouped = DashboardGrouping.sections(objects: hits, groupBy: "status")
        let allHits = try await index.execute(
            QueryDefinition(typeID: books.id, sort: .titleAsc)
        )
        let unfilteredSections = DashboardGrouping.sections(objects: allHits, groupBy: "status")

        var type = try await schema.loadType(books.id)
        type.dashboard.defaultSort = QuerySort.titleAsc.rawValue
        type.dashboard.defaultGroupBy = "status"
        type.dashboard.defaultFilterKey = "status"
        type.dashboard.defaultFilterText = "Reading"
        try await schema.saveType(type)

        var objectMarkdownUnchanged = true
        var bookInfos: [BookInfo] = []
        for meta in bookMetas {
            let opened = try await objects.open(id: meta.id)
            if opened.bodyMarkdown != bodiesBefore[meta.id] {
                objectMarkdownUnchanged = false
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
            saved.dashboard.defaultSort == "titleAsc"
            && saved.dashboard.defaultGroupBy == "status"
            && saved.dashboard.defaultFilterKey == "status"
            && saved.dashboard.defaultFilterText == "Reading"

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

        let proof = DashboardViewProof.evaluate(
            filteredTitles: hits.map(\.title),
            expectedFilteredTitles: ["Deep Work", "Range"],
            sortedTitles: hits.map(\.title),
            expectedSortedTitles: ["Deep Work", "Range"],
            sectionKeys: grouped.map(\.key),
            expectedSectionKey: "Reading",
            objectMarkdownUnchanged: objectMarkdownUnchanged,
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
            objectMarkdownUnchanged: objectMarkdownUnchanged,
            typeSchemaChanged: typeSchemaChanged,
            proof: proof,
            dashboard: DashboardInfo(
                defaultSort: saved.dashboard.defaultSort,
                defaultGroupBy: saved.dashboard.defaultGroupBy,
                defaultFilterKey: saved.dashboard.defaultFilterKey,
                defaultFilterText: saved.dashboard.defaultFilterText,
                relativePath: typePath
            ),
            books: bookInfos.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending },
            filteredTitles: hits.map(\.title),
            sections: grouped.map { SectionInfo(key: $0.key, titles: $0.objects.map(\.title)) },
            unfilteredSectionKeys: unfilteredSections.map(\.key),
            typeSchemaSnippet: typeJSON,
            note:
                "PR41: type dashboard uses QueryEngine for filter/sort. Group-by is derived UI. Only .loci/types/<slug>.json dashboard fields change — object YAML and daily notes stay put. Index never in vault."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
