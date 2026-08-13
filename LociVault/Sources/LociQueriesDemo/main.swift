import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Saved query + embed fixtures for DevHarness (PR23).
@main
struct LociQueriesDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-queries-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-queries-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Queries")

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
                ),
            ]
        )

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        var deepWork = try await objects.create(typeID: books.id, title: "Deep Work")
        deepWork.tags = ["focus"]
        deepWork.properties["status"] = .select("Reading")
        try await objects.save(meta: deepWork, bodyMarkdown: "Focus is a skill.\n")
        deepWork = try await index.object(id: deepWork.id) ?? deepWork

        var habits = try await objects.create(typeID: books.id, title: "Atomic Habits")
        habits.tags = ["habits"]
        habits.properties["status"] = .select("Done")
        try await objects.save(meta: habits, bodyMarkdown: "Tiny changes.\n")

        var range = try await objects.create(typeID: books.id, title: "Range")
        range.tags = ["focus"]
        range.properties["status"] = .select("Reading")
        try await objects.save(meta: range, bodyMarkdown: "Generalists.\n")
        range = try await index.object(id: range.id) ?? range

        let definition = QueryDefinition(
            typeID: books.id,
            tags: ["focus"],
            properties: [.equals("status", text: "Reading")],
            sort: .titleAsc
        )
        let saved = try await schema.createQuery(
            name: "Reading + focus",
            definition: definition,
            slug: "reading-focus",
            pinnedTypeID: books.id
        )

        let hits = try await index.execute(definition)
        let queryPath = SchemaStore.queryRelativePath(for: saved.id)
        let queryExists = try await vault.fileExists(atRelativePath: queryPath)
        let queryJSON = try await vault.readFile(atRelativePath: queryPath)
        let querySnippet = String(data: queryJSON, encoding: .utf8) ?? ""

        // Embed: slug only in markdown — results are live, not written into the body.
        let embedMD = """
            Notes

            ```query
            reading-focus
            ```
            """
        let embedDoc = try MarkdownParser().parse(embedMD)
        let embedHTML = BlockASTHTML.render(embedDoc.blocks)
        let serializedEmbed = MarkdownSerializer().serializeBlocks(embedDoc.blocks)
        let hasLiveResultsInBody = serializedEmbed.contains("Deep Work")

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let pinned = try await schema.listPinnedQueries(typeID: books.id)
        let allBooks = try await index.objects(typeID: books.id)

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "indexInsideVault": sqliteInVault,
            "queriesDirectory": VaultLayout.queriesDirectory,
            "bookType": [
                "id": books.id.rawValue,
                "name": books.name,
            ],
            "query": [
                "id": saved.id,
                "name": saved.name,
                "pinnedTypeID": saved.pinnedTypeID?.rawValue as Any,
                "relativePath": queryPath,
                "exists": queryExists,
                "definitionOnly": !querySnippet.contains("Deep Work"),
                "tags": definition.tags,
                "propertyEquals": "status=Reading",
            ],
            "results": hits.map { meta -> [String: Any] in
                [
                    "id": meta.id.frontMatterIDString,
                    "title": meta.title,
                    "tags": meta.tags,
                ]
            },
            "resultTitles": hits.map(\.title),
            "resultCount": hits.count,
            "pinnedQueryIDs": pinned.map(\.id),
            "allBooksCount": allBooks.count,
            "embed": [
                "serialized": serializedEmbed,
                "html": embedHTML,
                "queryID": "reading-focus",
                "storesResultsInBody": hasLiveResultsInBody,
                "roundTripKind": {
                    if let block = embedDoc.blocks.dropFirst().first,
                        case .queryEmbed(let id) = block
                    {
                        return id
                    }
                    return "missing"
                }(),
            ],
            "vaultFileSnippet": String(querySnippet.prefix(320)),
            "definitionIsVaultFile": queryExists && !sqliteInVault,
            "note":
                "PR23: QueryEngine DSL; saved defs in .loci/queries/<slug>.json; pin to type dashboard; /query embed stores slug only.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
