import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Tag Page + Book with `#health`; tag page lists both (PR17).
@main
struct LociTagsDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tags-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tags-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Tags")
        _ = try await schema.createType(name: "Book", icon: "book", color: "moss", slug: "book")

        // Alias wellness → health in space.json
        var space = try await schema.loadSpaceSettings()
        space.tagAliases = ["health": ["wellness"]]
        try await schema.saveSpaceSettings(space)

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        var page = try await objects.create(typeID: .page, title: "Morning walk")
        page.tags = ["health"]
        try await objects.save(meta: page, bodyMarkdown: "Steps outside.")

        let book = try await objects.create(typeID: ObjectTypeID("book"), title: "Atomic Habits")
        // Body #health via editor insertTag (completer path).
        let session = try EditorSession(bodyMarkdown: "Building systems #hea")
        let trigger = TagTriggerDetector.detect(in: EditorSession.plainText(of: session.blocks[0]))
        _ = session.insertTag(blockIndex: 0, tag: "health", trigger: trigger)
        try await objects.save(meta: book, bodyMarkdown: session.serializeBody())

        try await index.rebuild()

        let aliases = (try await schema.loadSpaceSettings()).tagAliasTable
        let healthHits = try await index.objects(tagged: "health", typeID: nil, aliases: aliases)
        let aliasHits = try await index.objects(tagged: "wellness", typeID: nil, aliases: aliases)
        let summaries = try await index.allTags(aliases: aliases, limit: 20)
        let candidates = try await index.tagCandidates(matching: "hea", aliases: aliases, limit: 8)

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

        let types = Set(healthHits.map(\.typeID.rawValue))
        let payload: [String: Any] = [
            "moduleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "vaultModuleVersion": LociVaultModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "aliases": space.tagAliases,
            "page": [
                "id": page.id.uuidString.lowercased(),
                "title": page.title,
                "type": page.typeID.rawValue,
                "tags": page.tags,
                "relativePath": page.relativePath,
            ],
            "book": [
                "id": book.id.uuidString.lowercased(),
                "title": book.title,
                "type": book.typeID.rawValue,
                "relativePath": book.relativePath,
                "bodyMarkdown": session.serializeBody(),
            ],
            "healthObjects": healthHits.map { meta in
                [
                    "id": meta.id.uuidString.lowercased(),
                    "title": meta.title,
                    "type": meta.typeID.rawValue,
                    "tags": meta.tags,
                ] as [String: Any]
            },
            "tagSummaries": summaries.map { s in
                [
                    "tag": s.tag,
                    "canonical": s.canonical,
                    "count": s.count,
                    "display": s.display,
                ] as [String: Any]
            },
            "completer": candidates.map { s in
                ["tag": s.tag, "count": s.count] as [String: Any]
            },
            "proof": [
                "healthCount": healthHits.count,
                "types": Array(types).sorted(),
                "crossType": types == Set(["page", "book"]),
                "aliasWellnessMatches": aliasHits.count == healthHits.count,
                "completerHasHealth": candidates.contains { $0.tag == "health" },
                "bodyHasHashHealth": session.serializeBody().contains("#health"),
            ],
            "note":
                "PR17: Page (frontmatter tags) + Book (body #health) both appear on #health tag page. Aliases expand wellness→health.",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
