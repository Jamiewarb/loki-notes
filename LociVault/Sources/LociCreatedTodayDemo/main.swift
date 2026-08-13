import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: ensure daily, create Page, prove daily bytes unchanged, export created-today fixture (PR11).
@main
struct LociCreatedTodayDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-created-today-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-created-today-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Created Today")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let daily = DailyNoteService(vault: vault, index: index)
        let objects = ObjectService(vault: vault, index: index)

        let todayNote = try await daily.ensure(for: today, calendar: calendar)
        try await objects.save(
            meta: todayNote.meta,
            bodyMarkdown: """
                ## Inbox

                Morning capture — created-today stays in the inspector.

                - [ ] Review yesterday
                - [x] Land PR11

                #daily
                """
        )

        let dailyPath = todayNote.meta.relativePath
        let beforeData = try await vault.readFile(atRelativePath: dailyPath)
        let beforeHash = contentFingerprint(beforeData)
        let beforeMod = try await modificationDate(vault: vault, relativePath: dailyPath)

        let page = try await objects.create(typeID: .page, title: "Deep Work Notes")
        try await objects.save(
            meta: page,
            bodyMarkdown: "Created today — linked from Daily inspector only.\n\n#focus"
        )
        // Re-fetch after save so tags/path stay accurate in fixture.
        let pageIndexed = try await index.object(id: page.id) ?? page
        let page2 = try await objects.create(typeID: .page, title: "Second Capture")

        let afterData = try await vault.readFile(atRelativePath: dailyPath)
        let afterHash = contentFingerprint(afterData)
        let afterMod = try await modificationDate(vault: vault, relativePath: dailyPath)
        let dailyUnchanged = beforeHash == afterHash && beforeData == afterData && beforeMod == afterMod

        let createdRaw = try await index.created(on: today)
        let panelItems = createdRaw.filter { $0.typeID != .daily }

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

        let todayMarkdown = String(data: afterData, encoding: .utf8) ?? ""

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "day": DailyNoteIdentity.title(for: today, calendar: calendar),
            "daily": [
                "id": todayNote.meta.id.frontMatterIDString,
                "uuid": todayNote.meta.id.uuidString.lowercased(),
                "relativePath": dailyPath,
                "title": todayNote.meta.title,
            ],
            "proof": [
                "dailyUnchanged": dailyUnchanged,
                "beforeHash": beforeHash,
                "afterHash": afterHash,
                "beforeMtime": ISO8601DateFormatter().string(from: beforeMod),
                "afterMtime": ISO8601DateFormatter().string(from: afterMod),
                "note":
                    "ObjectService.create Page does not rewrite daily .md (fingerprint + mtime + bytes).",
            ],
            "createdToday": panelItems.map { metaJSON($0) },
            "createdTodayRawCount": createdRaw.count,
            "excludeDailyFromPanel": true,
            "pagesCreated": [metaJSON(pageIndexed), metaJSON(page2)],
            "markdown": todayMarkdown,
            "note":
                "Created-today is IndexQuerying.created(on:) UI only. Daily type excluded from panel. Never rewrite daily.md on create.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }

        try? FileManager.default.removeItem(at: vaultParent)
        try? FileManager.default.removeItem(at: indexParent)
    }

    private static func metaJSON(_ meta: LociObjectMeta) -> [String: Any] {
        [
            "id": meta.id.uuidString.lowercased(),
            "type": meta.typeID.rawValue,
            "title": meta.title,
            "relativePath": meta.relativePath,
            "tags": meta.tags,
        ]
    }

    /// Deterministic fingerprint without CryptoKit (Linux CI).
    private static func contentFingerprint(_ data: Data) -> String {
        "len=\(data.count);hex=\(data.map { String(format: "%02x", $0) }.joined())"
    }

    private static func modificationDate(vault: VaultService, relativePath: String) async throws -> Date {
        let root = try await vault.vaultRootURL
        let url = root.appendingPathComponent(relativePath)
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let date = values.contentModificationDate else {
            throw LociError.fileNotFound(relativePath)
        }
        return date
    }
}
