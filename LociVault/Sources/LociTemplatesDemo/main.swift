import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Book default template prefills headings; daily uses daily template (PR14).
@main
struct LociTemplatesDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-templates-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-templates-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Templates")

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
            ]
        )

        let bookTemplate = try await schema.createTemplate(
            typeID: books.id,
            name: "Default Book",
            bodyMarkdown: """
            ## Summary

            ## Quotes

            ## Notes
            """,
            defaultProperties: [
                "status": .select("To Read"),
                "rating": .number(0),
            ],
            slug: "default",
            makeDefault: true
        )

        let dailyTemplate = try await schema.createTemplate(
            typeID: .daily,
            name: "Daily Default",
            bodyMarkdown: """
            ## Morning

            ## Evening
            """,
            defaultProperties: [:],
            slug: "default",
            makeDefault: true
        )

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        let deepWork = try await objects.create(typeID: books.id, title: "Deep Work")
        let openedBook = try await objects.open(id: deepWork.id)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = cal.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: cal)

        let bookPrefill =
            openedBook.bodyMarkdown.contains("## Summary")
            && openedBook.bodyMarkdown.contains("## Quotes")
            && openedBook.bodyMarkdown.contains("## Notes")
            && openedBook.meta.properties["status"] == .select("To Read")

        let dailyPrefill =
            openedDaily.bodyMarkdown.contains("## Morning")
            && openedDaily.bodyMarkdown.contains("## Evening")

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

        let bookType = try await schema.loadType(books.id)
        let dailyType = try await schema.loadType(.daily)
        let bookTplPath = SchemaStore.templateRelativePath(for: bookTemplate.id)
        let dailyTplPath = SchemaStore.templateRelativePath(for: dailyTemplate.id)
        let bookTplExists = try await vault.fileExists(atRelativePath: bookTplPath)
        let dailyTplExists = try await vault.fileExists(atRelativePath: dailyTplPath)

        let bookMD = try await vault.readFile(atRelativePath: openedBook.meta.relativePath)
        let bookText = String(data: bookMD, encoding: .utf8) ?? ""
        let dailyMD = try await vault.readFile(atRelativePath: openedDaily.meta.relativePath)
        let dailyText = String(data: dailyMD, encoding: .utf8) ?? ""

        let propDisplay: [String: String] = Dictionary(
            uniqueKeysWithValues: openedBook.meta.properties.map {
                ($0.key, PropertyValueFormatting.displayString($0.value))
            }
        )

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "bookTemplate": [
                "id": bookTemplate.id,
                "name": bookTemplate.name,
                "path": bookTplPath,
                "exists": bookTplExists,
                "bodyPreview": bookTemplate.bodyMarkdown,
                "defaultProperties": [
                    "status": "To Read",
                    "rating": "0",
                ],
            ],
            "dailyTemplate": [
                "id": dailyTemplate.id,
                "name": dailyTemplate.name,
                "path": dailyTplPath,
                "exists": dailyTplExists,
                "bodyPreview": dailyTemplate.bodyMarkdown,
            ],
            "bookType": [
                "id": bookType.id.rawValue,
                "name": bookType.name,
                "defaultTemplateID": bookType.defaultTemplateID as Any,
                "templateIDs": bookType.templateIDs,
                "properties": bookType.properties.map { def -> [String: Any] in
                    [
                        "id": def.id,
                        "name": def.name,
                        "kind": def.kind.rawValue,
                        "options": def.options,
                    ]
                },
            ],
            "dailyType": [
                "id": dailyType.id.rawValue,
                "defaultTemplateID": dailyType.defaultTemplateID as Any,
                "templateIDs": dailyType.templateIDs,
            ],
            "bookObject": [
                "id": openedBook.meta.id.uuidString.lowercased(),
                "title": openedBook.meta.title,
                "relativePath": openedBook.meta.relativePath,
                "properties": propDisplay,
                "bodyMarkdown": openedBook.bodyMarkdown,
                "prefilledHeadings": bookPrefill,
            ],
            "dailyObject": [
                "id": openedDaily.meta.id.dailyDateKey as Any,
                "title": openedDaily.meta.title,
                "relativePath": openedDaily.meta.relativePath,
                "bodyMarkdown": openedDaily.bodyMarkdown,
                "prefilledHeadings": dailyPrefill,
            ],
            "bookPrefill": bookPrefill,
            "dailyPrefill": dailyPrefill,
            "frontmatterSnippet": frontmatterSnippet(bookText),
            "dailyFrontmatterSnippet": frontmatterSnippet(dailyText),
            "note":
                "Default Book template prefills headings + status; new daily uses daily template (PR14).",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
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
