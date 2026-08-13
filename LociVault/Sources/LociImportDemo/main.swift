import Foundation
import LociCore
import LociVault
import LociIndex

/// CLI: Import dry-run + apply fixtures for DevHarness (PR27).
@main
struct LociImportDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-import-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-import-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Import")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let media = MediaService(vault: vault)
        let importer = ImportService(vault: vault, index: index, schema: schema, media: media)

        let fixturesRoot = packageFixturesRoot()
        let sources: [(String, ImportSourceKind, URL)] = [
            ("markdown", .markdownFolder, fixturesRoot.appendingPathComponent("markdown-folder")),
            ("obsidian", .obsidianVault, fixturesRoot.appendingPathComponent("obsidian-vault")),
            ("capacities", .capacitiesExport, fixturesRoot.appendingPathComponent("capacities-export")),
        ]

        var runs: [[String: Any]] = []
        var allProof: [String: Bool] = [:]

        for (name, kind, url) in sources {
            let detected = try await importer.detectKind(atSourceRoot: url)
            let summary = try await importer.dryRun(
                sourceRoot: url,
                kind: kind,
                conflictPolicy: .skip
            )
            let result = try await importer.apply(summary: summary, conflictPolicy: .skip)

            let dailyItem = result.written.first { $0.isDaily }
            let preserved = result.written.filter(\.preservedObjectID).count

            var run: [String: Any] = [
                "name": name,
                "kind": kind.rawValue,
                "detected": detected.rawValue,
                "dryRun": [
                    "items": summary.items.count,
                    "media": summary.media.count,
                    "create": summary.createCount,
                    "skip": summary.skipCount,
                    "daily": summary.dailyCount,
                    "preservedIDs": summary.preservedIDCount,
                    "warnings": summary.warnings,
                ],
                "apply": [
                    "written": result.writtenCount,
                    "skipped": result.skippedCount,
                    "mediaCopied": result.mediaCopied.count,
                    "preservedIDs": preserved,
                ],
                "samplePaths": result.written.prefix(5).map(\.destinationRelativePath),
            ]
            if let dailyItem {
                run["dailyPath"] = dailyItem.destinationRelativePath
                run["dailyID"] = dailyItem.objectID.frontMatterIDString
            }
            runs.append(run)

            allProof["\(name)Detected"] = detected == kind
            allProof["\(name)Wrote"] = result.writtenCount > 0
            if name == "obsidian" {
                allProof["obsidianDailyPath"] =
                    dailyItem?.destinationRelativePath == "daily/2026-08-01.md"
                allProof["obsidianDailyID"] =
                    dailyItem?.objectID.frontMatterIDString == "daily-2026-08-01"
            }
            if name == "capacities" {
                let page = result.written.first { $0.title == "My Page" }
                allProof["capacitiesPreservedID"] = page?.preservedObjectID == true
                    && page?.objectID.uuidString.lowercased()
                        == "11111111-2222-4333-8444-555555555555"
                let book = result.written.first { $0.title == "Deep Work" }
                allProof["capacitiesBookType"] = book?.typeID == ObjectTypeID("book")
            }
            if name == "markdown" {
                allProof["markdownMediaCopied"] = result.mediaCopied.count >= 1
            }
        }

        try await index.rebuild()

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
        allProof["indexOutsideVault"] = !sqliteInVault
        allProof["dryRunBeforeApply"] = true

        // Conflict skip on second markdown import into same vault
        let mdRoot = fixturesRoot.appendingPathComponent("markdown-folder")
        let second = try await importer.dryRun(
            sourceRoot: mdRoot,
            kind: .markdownFolder,
            conflictPolicy: .skip
        )
        allProof["conflictSkip"] = second.skipCount == second.items.count && second.items.count > 0

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": "see LociMarkdown",
            "indexInsideVault": sqliteInVault,
            "runs": runs,
            "proof": allProof,
            "importers": [
                ["id": "markdownFolder", "label": "Generic markdown folder"],
                ["id": "obsidianVault", "label": "Obsidian vault (wiki-links best-effort)"],
                ["id": "capacitiesExport", "label": "Capacities-style export"],
            ],
            "note":
                "PR27: Dry-run summary → apply writes objects/daily/media; preserves ObjectID + daily/YYYY-MM-DD when detectable. Index never in vault.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func packageFixturesRoot() -> URL {
        // …/LociVault/Sources/LociImportDemo/main.swift → package root
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return packageRoot
            .appendingPathComponent("LociVault/Tests/LociVaultTests/Fixtures/import", isDirectory: true)
    }
}
