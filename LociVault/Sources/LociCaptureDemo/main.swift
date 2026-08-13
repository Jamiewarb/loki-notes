import Foundation
import LociCore
import LociIndex
import LociVault

/// CLI: Capture inbox → daily / typed object fixtures for DevHarness (PR26).
@main
struct LociCaptureDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-capture-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-capture-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Capture")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)
        let capture = CaptureService(vault: vault, objects: objects, dailyNotes: daily)

        // Extension-style enqueue (no index): ShareInboxFactory maps (text, url).
        let appendItem = ShareInboxFactory.inboxItem(
            text: "Quick capture from share sheet",
            url: nil,
            source: .share
        )
        let appendPath = try await CaptureInboxWriter.enqueue(appendItem, vault: vault)

        let createItem = ShareInboxFactory.inboxItem(
            text: "Shared Page",
            url: "https://example.com/article"
        )
        let createPath = try await capture.enqueue(createItem)

        // Keep a URL-bearing append so daily still shows the classic share line.
        let urlAppend = CaptureInboxItem.appendLine(
            "Quick capture from share sheet",
            source: .share,
            sourceURL: "https://example.com/clip"
        )
        _ = try await CaptureInboxWriter.enqueue(urlAppend, vault: vault)

        let pendingBefore = try await capture.listPendingInbox()
        let drain = try await capture.drainInbox(calendar: calendar)
        let pendingAfter = try await capture.listPendingInbox()

        // Direct menu-bar style append
        let direct = try await capture.appendToToday(
            "Menu bar quick add",
            sourceURL: nil,
            source: .menuBar,
            calendar: calendar
        )

        let today = try await daily.ensureToday(calendar: calendar)
        let dayKey = DailyNoteIdentity.title(for: Date(), calendar: calendar)

        try await index.rebuild()

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let created = drain.first(where: { $0.kind == .createObject })
        let appended = drain.first(where: { $0.kind == .appendToToday })
        let shareProof = ShareWidgetProof.evaluate(
            appendItem: appendItem,
            createItem: createItem,
            inboxPath: appendPath,
            openTodayURL: LociDeepLink.dailyTodayAbsoluteString,
            indexInsideVault: sqliteInVault
        )

        func resultJSON(_ r: CaptureResult) -> [String: Any] {
            var d: [String: Any] = [
                "kind": r.kind.rawValue,
                "objectId": r.objectID.frontMatterIDString,
                "relativePath": r.relativePath,
            ]
            if let inbox = r.inboxRelativePath { d["inboxPath"] = inbox }
            if let line = r.appendedLine { d["appendedLine"] = line }
            return d
        }

        var createdObject: [String: Any] = [:]
        if let created {
            createdObject["path"] = created.relativePath
            createdObject["id"] = created.objectID.frontMatterIDString
        }

        var directJSON: [String: Any] = [
            "kind": direct.kind.rawValue,
            "relativePath": direct.relativePath,
        ]
        if let line = direct.appendedLine { directJSON["appendedLine"] = line }

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "indexInsideVault": sqliteInVault,
            "dayKey": dayKey,
            "dailyPath": today.meta.relativePath,
            "dailyBody": today.bodyMarkdown,
            "pendingBefore": pendingBefore,
            "pendingAfter": pendingAfter,
            "enqueue": [
                "appendPath": appendPath,
                "createPath": createPath,
            ],
            "drain": drain.map(resultJSON),
            "direct": directJSON,
            "createdObject": createdObject,
            "surfaces": [
                ["id": "share", "label": "iOS Share extension", "action": "extract text/URL → inbox"],
                [
                    "id": "widget",
                    "label": "Home Screen widget",
                    "action": "Open today \(LociDeepLink.dailyTodayAbsoluteString) / Quick add",
                ],
                ["id": "menubar", "label": "macOS menu bar", "action": "direct appendToToday"],
            ],
            "openTodayURL": LociDeepLink.dailyTodayAbsoluteString,
            "share": [
                "appendKind": appendItem.kind.rawValue,
                "createKind": createItem.kind.rawValue,
                "createType": createItem.typeID?.rawValue ?? "",
            ],
            "proof": [
                "inboxThenDrain": pendingBefore.count >= 2 && pendingAfter.isEmpty,
                "appendLandedInDaily": today.bodyMarkdown.contains("Quick capture from share sheet"),
                "directMenuBarInDaily": today.bodyMarkdown.contains("Menu bar quick add"),
                "createdTypedObject": created != nil
                    && (created?.relativePath.hasPrefix("objects/page/") ?? false),
                "appendResultPresent": appended != nil,
                "inboxStagingRemoved": pendingAfter.isEmpty,
                "dailyPathDeterministic": today.meta.relativePath
                    == DailyNoteIdentity.relativePath(for: Date(), calendar: calendar),
                "indexOutsideVault": !sqliteInVault,
                "shareExtractsText": shareProof.shareExtractsText,
                "widgetOpenToday": shareProof.widgetOpenToday,
                "inboxNotIndex": shareProof.inboxNotIndex,
                "indexInsideVault": shareProof.indexInsideVault,
            ],
            "note":
                "PR37: Share extracts text/URL via ShareInboxFactory → .loci/inbox/*.json. Widget Open today is loci://daily/today. Index on foreground only.",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
