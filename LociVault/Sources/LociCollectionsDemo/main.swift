import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Book Favorites collection membership fixtures for DevHarness (PR22).
@main
struct LociCollectionsDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-collections-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-collections-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Collections")

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

        let deepWork = try await objects.create(typeID: books.id, title: "Deep Work")
        try await objects.save(
            meta: deepWork,
            bodyMarkdown: "Focus is a skill.\n"
        )
        var deepMeta = try await index.object(id: deepWork.id) ?? deepWork
        deepMeta.properties["status"] = .select("Reading")
        try await objects.save(meta: deepMeta, bodyMarkdown: "Focus is a skill.\n")
        deepMeta = try await index.object(id: deepWork.id) ?? deepMeta

        let habits = try await objects.create(typeID: books.id, title: "Atomic Habits")
        let range = try await objects.create(typeID: books.id, title: "Range")

        let favorites = try await schema.createCollection(
            typeID: books.id,
            name: "Favorites",
            slug: "favorites"
        )
        var collection = try await schema.addToCollection(favorites.id, objectID: deepMeta.id)
        collection = try await schema.addToCollection(favorites.id, objectID: habits.id)
        // Range stays only on All tab.

        let readingList = try await schema.createCollection(
            typeID: books.id,
            name: "Reading List",
            slug: "reading-list"
        )
        _ = try await schema.addToCollection(readingList.id, objectID: deepMeta.id)
        _ = try await schema.addToCollection(readingList.id, objectID: range.id)

        let listed = try await schema.listCollections(typeID: books.id)
        let allBooks = try await index.objects(typeID: books.id)

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

        let favoritesPath = SchemaStore.collectionRelativePath(for: favorites.id)
        let favoritesExists = try await vault.fileExists(atRelativePath: favoritesPath)
        let favoritesJSON = try await vault.readFile(atRelativePath: favoritesPath)
        let favoritesSnippet = String(data: favoritesJSON, encoding: .utf8) ?? ""

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "indexInsideVault": sqliteInVault,
            "collectionsDirectory": VaultLayout.collectionsDirectory,
            "bookType": [
                "id": books.id.rawValue,
                "name": books.name,
                "icon": books.icon,
            ],
            "collections": listed.map { col -> [String: Any] in
                [
                    "id": col.id,
                    "name": col.name,
                    "typeID": col.typeID.rawValue,
                    "memberCount": col.memberIDs.count,
                    "memberIDs": col.memberIDs.map(\.frontMatterIDString),
                    "relativePath": SchemaStore.collectionRelativePath(for: col.id),
                ]
            },
            "favorites": [
                "id": collection.id,
                "name": collection.name,
                "memberCount": collection.memberIDs.count,
                "memberTitles": [
                    deepMeta.title,
                    habits.title,
                ],
                "relativePath": favoritesPath,
                "exists": favoritesExists,
            ],
            "readingList": [
                "id": readingList.id,
                "name": readingList.name,
                "memberCount": 2,
            ],
            "allBooksCount": allBooks.count,
            "favoritesMemberCount": collection.memberIDs.count,
            "tabs": ["All", "Favorites", "Reading List"],
            "books": allBooks.map { meta -> [String: Any] in
                [
                    "id": meta.id.frontMatterIDString,
                    "title": meta.title,
                    "relativePath": meta.relativePath,
                    "inFavorites": collection.memberIDs.contains(meta.id),
                    "inReadingList": [deepMeta.id, range.id].contains(meta.id),
                ]
            },
            "vaultFileSnippet": String(favoritesSnippet.prefix(280)),
            "membershipIsVaultFile": favoritesExists && !sqliteInVault,
            "note":
                "PR22: Manual collections per type; membership in .loci/collections/<type>.<slug>.json; type dashboard tabs.",
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
