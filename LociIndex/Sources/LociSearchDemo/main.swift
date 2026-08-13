import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: FTS title + body hits, grouped by type, for DevHarness Search panel (PR18).
///
/// Set `LOCI_SEARCH_BULK=1000` to also seed filler pages (optional stress fixture).
@main
struct LociSearchDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-search-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-search-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Search")
        _ = try await schema.createType(name: "Book", icon: "book", color: "moss", slug: "book")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        // Title hit (page)
        var titlePage = try await objects.create(typeID: .page, title: "Focus Rituals")
        try await objects.save(
            meta: titlePage,
            bodyMarkdown: "Morning pages and attention hygiene."
        )
        titlePage = try await index.object(id: titlePage.id) ?? titlePage

        // Body hit (page) — title does not contain query
        var bodyPage = try await objects.create(typeID: .page, title: "Weekend Notes")
        try await objects.save(
            meta: bodyPage,
            bodyMarkdown: "A long walk, then deep focus on the essay draft."
        )
        bodyPage = try await index.object(id: bodyPage.id) ?? bodyPage

        // Body hit on another type (book) for grouping
        var book = try await objects.create(typeID: ObjectTypeID("book"), title: "Deep Work")
        try await objects.save(
            meta: book,
            bodyMarkdown: "Cal Newport on focus and distraction."
        )
        book = try await index.object(id: book.id) ?? book

        // Decoy that should not match "focus"
        _ = try await objects.create(typeID: .page, title: "Grocery List")

        let bulk = Int(ProcessInfo.processInfo.environment["LOCI_SEARCH_BULK"] ?? "") ?? 0
        if bulk > 0 {
            for i in 1...bulk {
                let meta = try await objects.create(
                    typeID: .page,
                    title: String(format: "Filler %04d", i)
                )
                try await objects.save(
                    meta: meta,
                    bodyMarkdown: "Padding object \(i) without the keyword."
                )
            }
        }

        try await index.rebuild()

        let query = "focus"
        let rawHits = try await index.search(query: query)
        let ranked = SearchRanking.preferTitleMatches(rawHits, query: query)
        let groups = SearchGrouping.byType(ranked)

        let titleHitIDs = Set(
            ranked.filter { SearchRanking.titleMatches($0.title, query: query) }.map {
                $0.id.uuidString.lowercased()
            }
        )
        let bodyOnlyIDs = Set(
            ranked.filter { !SearchRanking.titleMatches($0.title, query: query) }.map {
                $0.id.uuidString.lowercased()
            }
        )

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

        let allPages = try await index.objects(typeID: .page)
        let allBooks = try await index.objects(typeID: ObjectTypeID("book"))
        let objectCount = allPages.count + allBooks.count

        let payload: [String: Any] = [
            "moduleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "vaultModuleVersion": LociVaultModule.version,
            "sqliteEngine": "GRDB",
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "vaultID": index.vaultID,
            "indexInsideVault": sqliteInVault,
            "objectCount": objectCount,
            "bulkSeeded": bulk,
            "searchQuery": query,
            "ftsMatch": SearchQuery.ftsMatchQuery(query),
            "searchHits": ranked.map { metaJSON($0) },
            "grouped": groups.map { group in
                [
                    "type": group.typeID.rawValue,
                    "title": group.title,
                    "items": group.items.map { metaJSON($0) },
                ] as [String: Any]
            },
            "titleHits": ranked.filter { SearchRanking.titleMatches($0.title, query: query) }
                .map { metaJSON($0) },
            "bodyHits": ranked.filter { !SearchRanking.titleMatches($0.title, query: query) }
                .map { metaJSON($0) },
            "proof": [
                "titleHit": titleHitIDs.contains(titlePage.id.uuidString.lowercased()),
                "bodyHit": bodyOnlyIDs.contains(bodyPage.id.uuidString.lowercased()),
                "bookBodyHit": bodyOnlyIDs.contains(book.id.uuidString.lowercased())
                    || titleHitIDs.contains(book.id.uuidString.lowercased()),
                "groupedByType": Set(groups.map(\.typeID.rawValue)) == Set(["page", "book"]),
                "groupCount": groups.count,
                "hitCount": ranked.count,
                "titleFirst": ranked.first?.title == "Focus Rituals",
                "indexOutsideVault": !sqliteInVault,
                "objectCount": objectCount,
            ],
            "note":
                "PR18: IndexQuerying.search FTS5 — title + body hits, grouped by type. ⌘K / SearchView reads index only.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func metaJSON(_ meta: LociObjectMeta) -> [String: Any] {
        [
            "id": meta.id.uuidString.lowercased(),
            "type": meta.typeID.rawValue,
            "title": meta.title,
            "relativePath": meta.relativePath,
            "tags": meta.tags,
            "titleMatch": SearchRanking.titleMatches(meta.title, query: "focus"),
        ]
    }
}
