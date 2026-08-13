import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Book type + status/rating → Deep Work values → reload + properties_idx (PR13).
@main
struct LociPropertiesDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-properties-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-properties-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Properties")

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
                PropertyDef(id: "rating", name: "Rating", kind: .number),
                PropertyDef(id: "url", name: "URL", kind: .url),
                PropertyDef(id: "finished", name: "Finished", kind: .checkbox),
            ]
        )

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index)

        var deepWork = try await objects.create(typeID: books.id, title: "Deep Work")
        deepWork.properties = [
            "status": .select("Reading"),
            "rating": .number(5),
            "url": .url("https://www.calnewport.com/books/deep-work/"),
            "finished": .bool(false),
        ]
        try await objects.save(
            meta: deepWork,
            bodyMarkdown: "Cal Newport — focus is a skill.\n\n#books"
        )

        // Survive reload with a fresh ObjectService.
        let objects2 = ObjectService(vault: vault, index: index)
        let reopened = try await objects2.open(id: deepWork.id)
        let survived =
            reopened.meta.properties["status"] == .select("Reading")
            && reopened.meta.properties["rating"] == .number(5)

        let idxRows = try await index.propertyIndex(objectID: deepWork.id)
        let statusRow = idxRows.first { $0.key == "status" }
        let ratingRow = idxRows.first { $0.key == "rating" }
        let filterHits = try await index.objects(
            typeID: books.id,
            propertyKey: "status",
            equalsText: "Reading"
        )

        let bookType = try await schema.loadType(books.id)
        let vaultRoot = try await vault.vaultRootURL
        let mdData = try await vault.readFile(atRelativePath: reopened.meta.relativePath)
        let mdText = String(data: mdData, encoding: .utf8) ?? ""

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

        let propDisplay: [String: String] = Dictionary(
            uniqueKeysWithValues: reopened.meta.properties.map {
                ($0.key, PropertyValueFormatting.displayString($0.value))
            }
        )

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "bookType": [
                "id": bookType.id.rawValue,
                "name": bookType.name,
                "icon": bookType.icon,
                "color": bookType.color,
                "isBuiltIn": bookType.isBuiltIn,
                "properties": bookType.properties.map { def -> [String: Any] in
                    [
                        "id": def.id,
                        "name": def.name,
                        "kind": def.kind.rawValue,
                        "options": def.options,
                        "required": def.required,
                    ]
                },
            ],
            "object": [
                "id": reopened.meta.id.uuidString.lowercased(),
                "type": reopened.meta.typeID.rawValue,
                "title": reopened.meta.title,
                "relativePath": reopened.meta.relativePath,
                "properties": propDisplay,
                "tags": reopened.meta.tags,
            ],
            "frontmatterSnippet": frontmatterSnippet(mdText),
            "survivedReload": survived,
            "propertiesIdx": idxRows.map { row -> [String: Any] in
                var m: [String: Any] = ["key": row.key]
                if let t = row.valueText { m["valueText"] = t }
                if let n = row.valueNumber { m["valueNumber"] = n }
                if let b = row.valueBool { m["valueBool"] = b }
                return m
            },
            "filterStatusReadingCount": filterHits.count,
            "statusIndexed": statusRow?.valueText == "Reading",
            "ratingIndexed": ratingRow?.valueNumber == 5,
            "note":
                "Book type gets status + rating; values in YAML frontmatter; properties_idx updated on save (PR13).",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func frontmatterSnippet(_ markdown: String) -> String {
        guard markdown.hasPrefix("---") else { return "" }
        let parts = markdown.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return String(markdown.prefix(400)) }
        return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
