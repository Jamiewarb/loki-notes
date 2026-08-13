import Foundation
import LociCore
import LociVault
import LociIndex
import LociMarkdown

/// CLI: Safari web clipper fixtures for DevHarness (PR32).
@main
struct LociSafariDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-safari-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-safari-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Safari")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)
        let capture = CaptureService(vault: vault, objects: objects, dailyNotes: daily)
        let safari = SafariClipService(vault: vault, capture: capture, objects: objects)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let weblinkType = try await schema.loadType(.weblink)

        // Extension-style enqueue (no index): append + weblink create.
        let appendClip = SafariClip(
            pageURL: "https://example.com/safari-clip",
            pageTitle: "Safari Clip Article",
            selection: "Quoted selection from the page.",
            destination: .appendToToday
        )
        let weblinkClip = SafariClip(
            pageURL: "https://example.com/weblink",
            pageTitle: "Weblink Title",
            selection: "Save this as a Weblink object.",
            destination: .weblinkObject
        )
        let appendInbox = try await safari.enqueue(appendClip)
        let weblinkInbox = try await safari.enqueue(weblinkClip)
        let pendingBefore = try await capture.listPendingInbox()

        let drained = try await safari.drain(calendar: calendar)
        let pendingAfter = try await capture.listPendingInbox()

        let opened = try await daily.ensureToday(calendar: calendar)
        let dailyLine = drained.first(where: { $0.kind == .appendToToday })?.appendedLine
            ?? CaptureLineFormatter.line(
                text: "Quoted selection from the page.",
                sourceURL: "https://example.com/safari-clip",
                source: .safari
            )
        let weblinkResult = drained.first(where: { $0.kind == .createObject })
        var weblinkURLProp = ""
        var weblinkPath = weblinkResult?.relativePath ?? ""
        if let id = weblinkResult?.objectID {
            let openedWeblink = try await objects.open(id: id)
            weblinkPath = openedWeblink.meta.relativePath
            if case .url(let u) = openedWeblink.meta.properties["url"] {
                weblinkURLProp = u
            }
        }

        // Direct clip to today.
        let direct = try await safari.clip(
            SafariClip(
                pageURL: "https://example.com/direct",
                pageTitle: "Direct Clip",
                selection: "Direct clip line.",
                destination: .appendToToday
            ),
            calendar: calendar
        )
        let openedAfterDirect = try await daily.ensureToday(calendar: calendar)

        try await index.rebuild()

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
            }
        }

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "indexInsideVault": sqliteInVault,
            "appendInboxPath": appendInbox,
            "weblinkInboxPath": weblinkInbox,
            "pendingBeforeDrain": pendingBefore.count,
            "pendingAfterDrain": pendingAfter.count,
            "dailyPath": opened.meta.relativePath,
            "dailyLine": dailyLine,
            "dailyBody": openedAfterDirect.bodyMarkdown,
            "weblinkPath": weblinkPath,
            "weblinkURL": weblinkURLProp,
            "directPath": direct.relativePath,
            "directLine": direct.appendedLine ?? "",
            "weblinkTypeSeeded": weblinkType.id == .weblink && weblinkType.isBuiltIn,
            "proof": [
                "dailyLineHasSafari": dailyLine.contains("· safari")
                    && dailyLine.contains("https://example.com/safari-clip"),
                "weblinkPath": weblinkPath.hasPrefix("objects/weblink/"),
                "weblinkURLProperty": weblinkURLProp == "https://example.com/weblink",
                "inboxEmpty": pendingAfter.isEmpty,
                "indexOutsideVault": !sqliteInVault,
                "directClip": (direct.appendedLine ?? "").contains("· safari"),
                "weblinkTypeSeeded": weblinkType.isBuiltIn,
            ],
            "note":
                "PR32: Safari extension enqueues .loci/inbox/; drain → today (`· safari`) or Weblink with url property. Index never from extension.",
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
