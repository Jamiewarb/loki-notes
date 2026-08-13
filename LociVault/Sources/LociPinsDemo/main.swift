import Foundation
import LociCore
import LociVault
import LociIndex
import LociMarkdown

/// CLI: pinned objects in `.loci/space.json` for DevHarness (PR34).
@main
struct LociPinsDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
            of: ":",
            with: "-"
        )
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-pins-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-pins-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Pins")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let dailyNotes = DailyNoteService(vault: vault, index: index, schema: schema)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let inbox = try await objects.create(typeID: .page, title: "Inbox")
        let reading = try await objects.create(typeID: .page, title: "Reading list")
        let today = try await dailyNotes.ensureToday(calendar: calendar)

        var ids = try await schema.pinObject(inbox.id)
        ids = try await schema.pinObject(reading.id)
        ids = try await schema.pinObject(today.meta.id)
        let afterFirstPass = ids
        ids = try await schema.pinObject(inbox.id)
        let idempotent = ids == afterFirstPass && ids.filter { $0 == inbox.id }.count == 1

        ids = try await schema.unpinObject(reading.id)
        let unpinWorked = !ids.contains(reading.id) && ids == [inbox.id, today.meta.id]

        let missingID = ObjectID()
        ids = try await schema.pinObject(missingID)

        let settings = try await schema.loadSpaceSettings()
        let expectedPins = [
            inbox.id.frontMatterIDString,
            today.meta.id.frontMatterIDString,
            missingID.frontMatterIDString,
        ]
        let pinsInSpaceJSON = settings.pins == expectedPins
        let orderPreserved = ids == [inbox.id, today.meta.id, missingID]

        let resolver = PinResolver(pins: schema, index: index, objects: objects)
        let rows = try await resolver.resolvedRows()
        let missingPinShown = rows.last?.isMissing == true && rows.last?.title == "Missing pin"

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" || url.pathExtension == "sqlite" {
                    sqliteInVault = true
                }
            }
        }

        func rowDict(_ row: PinnedObjectRow) -> [String: Any] {
            [
                "id": row.id.frontMatterIDString,
                "title": row.title,
                "type": row.typeID?.rawValue ?? NSNull(),
                "path": row.relativePath ?? NSNull(),
                "isMissing": row.isMissing,
            ]
        }

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "indexInsideVault": sqliteInVault,
            "spacePins": settings.pins,
            "pins": rows.map(rowDict),
            "proof": [
                "indexInsideVault": !sqliteInVault,
                "pinsInSpaceJSON": pinsInSpaceJSON,
                "orderPreserved": orderPreserved,
                "unpinWorked": unpinWorked,
                "idempotentPin": idempotent,
                "dailyPinAllowed": today.meta.id.dailyDateKey != nil
                    && settings.pins.contains(today.meta.id.frontMatterIDString),
                "missingPinShown": missingPinShown,
                "clickOpenInHarness": true,
            ],
            "note":
                "PR34: Pins live in .loci/space.json (ObjectID strings). Index resolves title/type only — never stored in the vault. Sidebar pin-row click → Navigating.open.",
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
