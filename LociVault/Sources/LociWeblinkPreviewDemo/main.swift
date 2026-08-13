import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: weblink object + OG preview cache proofs (PR43).
@main
struct LociWeblinkPreviewDemo {
    struct Payload: Encodable {
        var moduleVersion: String
        var indexModuleVersion: String
        var vaultRoot: String
        var indexPath: String
        var cachePath: String
        var cacheInsideVault: Bool
        var indexInsideVault: Bool
        var dailyUnchanged: Bool
        var dailyPath: String
        var weblinkPath: String
        var weblinkURL: String
        var previewTitle: String?
        var previewDescription: String?
        var previewImageURL: String?
        var yamlContainsOgTitle: Bool
        var fetchCountAfterOpen: Int
        var fetchCountAfterTypingSave: Int
        var proof: LinkPreviewProof
        var note: String
    }

    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
            of: ":",
            with: "-"
        )
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-weblink-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-weblink-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Weblink Preview")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)
        let fetcher = FakeLinkPreviewFetcher.withOpenGraphFixtures()
        let cacheDir = index.databaseURL.deletingLastPathComponent()
        let previews = LinkPreviewService(cacheDirectory: cacheDir, fetcher: fetcher)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: calendar)
        let dailyBefore = openedDaily.bodyMarkdown
        let dailyPath = openedDaily.meta.relativePath

        var meta = try await objects.create(typeID: .weblink, title: "Example Article")
        meta.properties["url"] = .url(OpenGraphFixtures.articleURLString)
        try await objects.save(meta: meta, bodyMarkdown: "Clipped from the page.\n")
        let opened = try await objects.open(id: meta.id)
        let url = WeblinkURL.from(opened.meta) ?? OpenGraphFixtures.articleURL

        let parsedDirect = OpenGraphHTMLParser.parse(
            OpenGraphFixtures.articleHTML,
            sourceURL: url
        )
        let preview = try await previews.preview(for: url)
        let fetchAfterOpen = fetcher.fetchCount

        try await objects.save(meta: opened.meta, bodyMarkdown: opened.bodyMarkdown)
        let fetchAfterType = fetcher.fetchCount

        let yamlData = try await vault.readFile(atRelativePath: opened.meta.relativePath)
        let yamlText = String(data: yamlData, encoding: .utf8) ?? ""
        let yamlContainsOgTitle = yamlText.contains("og:title")
            || yamlText.contains("og-title")
            || yamlText.contains("og-description")

        let dailyAfter = try await daily.open(date: day, calendar: calendar)
        let dailyUnchanged = dailyAfter.bodyMarkdown == dailyBefore

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        var previewInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let found as URL in enumerator {
                if found.lastPathComponent == "index.sqlite" { sqliteInVault = true }
                if found.lastPathComponent == "previews.json" { previewInVault = true }
            }
        }

        let cachePath = previews.cacheFileURL.path
        let cacheInsideVault = previewInVault || cachePath.hasPrefix(vaultRoot.path)

        let proof = LinkPreviewProof.evaluate(
            parsedTitle: parsedDirect.title ?? preview.title,
            expectedTitle: "Example Article",
            cachePath: cachePath,
            vaultRoot: vaultRoot.path,
            fetchCountAfterOpen: fetchAfterOpen,
            fetchCountAfterTypingSave: fetchAfterType,
            indexInsideVault: sqliteInVault
        )

        let payload = Payload(
            moduleVersion: LociVaultModule.version,
            indexModuleVersion: LociIndexModule.version,
            vaultRoot: vaultRoot.path,
            indexPath: index.databaseURL.path,
            cachePath: cachePath,
            cacheInsideVault: cacheInsideVault,
            indexInsideVault: sqliteInVault,
            dailyUnchanged: dailyUnchanged,
            dailyPath: dailyPath,
            weblinkPath: opened.meta.relativePath,
            weblinkURL: url.absoluteString,
            previewTitle: preview.title,
            previewDescription: preview.description,
            previewImageURL: preview.imageURL?.absoluteString,
            yamlContainsOgTitle: yamlContainsOgTitle,
            fetchCountAfterOpen: fetchAfterOpen,
            fetchCountAfterTypingSave: fetchAfterType,
            proof: proof,
            note:
                "PR43: Weblink url + fake OG fetch on fixture HTML. Cache is Application Support JSON next to the index, never in the vault. Typing save does not fetch. Daily markdown unchanged. OG is cache-only (not YAML)."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
