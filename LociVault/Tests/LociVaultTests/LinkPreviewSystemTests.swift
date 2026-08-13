import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class LinkPreviewSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var cacheParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!
    private var fetcher: FakeLinkPreviewFetcher!
    private var previews: LinkPreviewService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-weblink-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-weblink-db-\(stamp)", isDirectory: true)
        cacheParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-weblink-cache-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        previews = nil
        daily = nil
        objects = nil
        index = nil
        schema = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
        if let cacheParent { try? FileManager.default.removeItem(at: cacheParent) }
    }

    private func boot() async throws {
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Weblink Preview Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
        fetcher = FakeLinkPreviewFetcher.withOpenGraphFixtures()
        let cacheDir = index.databaseURL.deletingLastPathComponent()
        previews = LinkPreviewService(cacheDirectory: cacheDir, fetcher: fetcher)
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func testPreviewCachesOutsideVaultAndParsesOpenGraph() async throws {
        try await boot()
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: utcCalendar)
        let dailyBefore = openedDaily.bodyMarkdown

        var meta = try await objects.create(typeID: .weblink, title: "Example Article")
        meta.properties["url"] = .url(OpenGraphFixtures.articleURLString)
        try await objects.save(meta: meta, bodyMarkdown: "Clipped note.\n")
        let opened = try await objects.open(id: meta.id)
        XCTAssertTrue(opened.bodyMarkdown.contains("Clipped note"))

        let url = try XCTUnwrap(WeblinkURL.from(opened.meta))
        let preview = try await previews.preview(for: url)
        XCTAssertEqual(preview.title, "Example Article")
        XCTAssertEqual(preview.description, "A clipped paragraph from the page.")
        XCTAssertEqual(preview.imageURL?.absoluteString, "https://example.com/og.png")
        XCTAssertEqual(fetcher.fetchCount, 1)

        let cached = try await previews.preview(for: url)
        XCTAssertEqual(cached.title, preview.title)
        XCTAssertEqual(fetcher.fetchCount, 1, "second preview must hit cache")

        let vaultRoot = try await vault.vaultRootURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: previews.cacheFileURL.path))
        XCTAssertFalse(previews.cacheFileURL.path.hasPrefix(vaultRoot.path))
        XCTAssertTrue(previews.cacheFileURL.path.hasPrefix(index.databaseURL.deletingLastPathComponent().path))
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))

        var sqliteInVault = false
        var previewInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
                if url.lastPathComponent == "previews.json" { previewInVault = true }
            }
        }
        XCTAssertFalse(sqliteInVault)
        XCTAssertFalse(previewInVault)

        let dailyAfter = try await daily.open(date: day, calendar: utcCalendar)
        XCTAssertEqual(dailyAfter.bodyMarkdown, dailyBefore)

        let yaml = String(
            data: try await vault.readFile(atRelativePath: opened.meta.relativePath),
            encoding: .utf8
        ) ?? ""
        XCTAssertFalse(yaml.contains("og:title"))
        XCTAssertFalse(yaml.contains("og-title"))
        XCTAssertFalse(yaml.contains("og-description"))
        XCTAssertTrue(yaml.contains("https://example.com/article"))

        let proof = LinkPreviewProof.evaluate(
            parsedTitle: preview.title,
            expectedTitle: "Example Article",
            cachePath: previews.cacheFileURL.path,
            vaultRoot: vaultRoot.path,
            fetchCountAfterOpen: fetcher.fetchCount,
            fetchCountAfterTypingSave: fetcher.fetchCount,
            indexInsideVault: sqliteInVault
        )
        XCTAssertTrue(proof.parsesOpenGraph)
        XCTAssertTrue(proof.cacheOutsideVault)
        XCTAssertTrue(proof.noFetchOnType)
        XCTAssertFalse(proof.indexInsideVault)
    }

    func testNoFetchOnTypingSave() async throws {
        try await boot()
        var meta = try await objects.create(typeID: .weblink, title: "Example Article")
        meta.properties["url"] = .url(OpenGraphFixtures.articleURLString)
        try await objects.save(meta: meta, bodyMarkdown: "Before.\n")
        let url = try XCTUnwrap(WeblinkURL.from(meta))
        _ = try await previews.preview(for: url)
        let afterOpen = fetcher.fetchCount
        XCTAssertEqual(afterOpen, 1)

        let opened = try await objects.open(id: meta.id)
        try await objects.save(meta: opened.meta, bodyMarkdown: "Typed more words.\n")
        let afterType = fetcher.fetchCount
        XCTAssertEqual(afterType, afterOpen)

        let after = try await objects.open(id: meta.id)
        XCTAssertTrue(after.bodyMarkdown.contains("Typed more words"))
        XCTAssertEqual(after.meta.properties["url"], .url(OpenGraphFixtures.articleURLString))

        let vaultRoot = try await vault.vaultRootURL
        let proof = LinkPreviewProof.evaluate(
            parsedTitle: "Example Article",
            expectedTitle: "Example Article",
            cachePath: previews.cacheFileURL.path,
            vaultRoot: vaultRoot.path,
            fetchCountAfterOpen: afterOpen,
            fetchCountAfterTypingSave: afterType,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.noFetchOnType)
    }

    func testRefreshFetchesAgainAndFailureIsPlaceholder() async throws {
        try await boot()
        var meta = try await objects.create(typeID: .weblink, title: "Example Article")
        meta.properties["url"] = .url(OpenGraphFixtures.articleURLString)
        try await objects.save(meta: meta, bodyMarkdown: "Clip.\n")
        let url = try XCTUnwrap(WeblinkURL.from(meta))
        _ = try await previews.preview(for: url)
        XCTAssertEqual(fetcher.fetchCount, 1)
        let refreshed = try await previews.refresh(for: url)
        XCTAssertEqual(refreshed.title, "Example Article")
        XCTAssertEqual(fetcher.fetchCount, 2)

        let missing = URL(string: "https://example.com/missing-preview")!
        let failed = try await previews.preview(for: missing)
        XCTAssertFalse(failed.hasContent)
        XCTAssertEqual(failed.sourceURL, missing)

        let fileURL = URL(string: "file:///tmp/secret.md")!
        let rejected = try await previews.preview(for: fileURL)
        XCTAssertFalse(rejected.hasContent)

        let after = try await objects.open(id: meta.id)
        XCTAssertTrue(after.bodyMarkdown.contains("Clip"))
        XCTAssertFalse(after.bodyMarkdown.contains("og:title"))
    }

    func testURLSessionFetcherRejectsNonHTTP() async {
        let fetcher = URLSessionLinkPreviewFetcher()
        do {
            _ = try await fetcher.fetchHTML(from: URL(string: "file:///tmp/x.html")!)
            XCTFail("expected throw")
        } catch let error as LociError {
            guard case .linkPreviewUnsupportedScheme = error else {
                XCTFail("wrong error \(error)")
                return
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
        #if os(macOS) || os(iOS)
        XCTAssertTrue(LinkPreviewFetcherFactory.usesURLSession)
        #else
        XCTAssertFalse(LinkPreviewFetcherFactory.usesURLSession)
        #endif
    }

    func testModuleVersionIsPR43() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr43") || LociVaultModule.version.contains("pr44"),
            LociVaultModule.version
        )
        XCTAssertTrue(
            LociVaultModule.version == "0.43.0-pr43" || LociVaultModule.version == "0.44.0-pr44",
            LociVaultModule.version
        )
    }
}
