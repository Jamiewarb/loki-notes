import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: ensure today + yesterday daily notes; export fixture for DevHarness Daily panel (PR10).
@main
struct LociDailyDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-daily-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-daily-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Fixed “today” for reproducible harness fixtures.
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let yesterday = DailyNoteIdentity.previousDay(of: today, calendar: calendar)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Daily")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let daily = DailyNoteService(vault: vault, index: index)

        let todayNote = try await daily.ensure(for: today, calendar: calendar)
        // Idempotent second ensure — must not fork path/id.
        let todayAgain = try await daily.ensure(for: today, calendar: calendar)
        let yNote = try await daily.ensure(for: yesterday, calendar: calendar)

        let objects = ObjectService(vault: vault, index: index)
        var meta = todayNote.meta
        try await objects.save(
            meta: meta,
            bodyMarkdown: """
                ## Inbox

                Morning capture from DailyNoteService.

                - [ ] Review yesterday
                - [x] Land PR10

                #daily
                """
        )
        let reopened = try await daily.open(date: today, calendar: calendar)

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

        let todayData = try await vault.readFile(atRelativePath: todayNote.meta.relativePath)
        let todayMarkdown = String(data: todayData, encoding: .utf8) ?? ""

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "scheme": [
                "path": "daily/YYYY-MM-DD.md",
                "logicalId": "daily-YYYY-MM-DD",
                "examplePath": todayNote.meta.relativePath,
                "exampleId": todayNote.meta.id.frontMatterIDString,
                "exampleUUID": todayNote.meta.id.uuidString.lowercased(),
            ],
            "today": noteJSON(reopened),
            "yesterday": noteJSON(yNote),
            "idempotent": todayNote.meta.id == todayAgain.meta.id
                && todayNote.meta.relativePath == todayAgain.meta.relativePath,
            "markdown": todayMarkdown,
            "dayNav": [
                "prev": DailyNoteIdentity.title(for: yesterday, calendar: calendar),
                "today": DailyNoteIdentity.title(for: today, calendar: calendar),
                "next": DailyNoteIdentity.title(
                    for: DailyNoteIdentity.nextDay(of: today, calendar: calendar),
                    calendar: calendar
                ),
            ],
            "note":
                "DailyNoteService ensure today/yesterday; deterministic path+id; body via BlockEditor later. Created-today is PR11.",
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

    private static func noteJSON(_ opened: OpenedObject) -> [String: Any] {
        [
            "id": opened.meta.id.frontMatterIDString,
            "uuid": opened.meta.id.uuidString.lowercased(),
            "type": opened.meta.typeID.rawValue,
            "title": opened.meta.title,
            "relativePath": opened.meta.relativePath,
            "bodyPreview": String(opened.bodyMarkdown.prefix(160)),
        ]
    }
}
