import XCTest
import LociCore
import LociIndex
import LociMarkdown
@testable import LociVault

final class ImportSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var media: MediaService!
    private var importer: ImportService!

    override func setUpWithError() throws {
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-import-vault-\(UUID().uuidString)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-import-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Import Tests")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        media = MediaService(vault: vault)
        importer = ImportService(vault: vault, index: index, schema: schema, media: media)
    }

    private func fixture(_ relative: String) -> URL {
        let base = Bundle.module.resourceURL!
            .appendingPathComponent("Fixtures/import", isDirectory: true)
        return base.appendingPathComponent(relative, isDirectory: true)
    }

    func testDetectMarkdownFolder() async throws {
        try await boot()
        let kind = try await importer.detectKind(atSourceRoot: fixture("markdown-folder"))
        XCTAssertEqual(kind, .markdownFolder)
    }

    func testDetectObsidianVault() async throws {
        try await boot()
        let kind = try await importer.detectKind(atSourceRoot: fixture("obsidian-vault"))
        XCTAssertEqual(kind, .obsidianVault)
    }

    func testDetectCapacitiesExport() async throws {
        try await boot()
        let kind = try await importer.detectKind(atSourceRoot: fixture("capacities-export"))
        XCTAssertEqual(kind, .capacitiesExport)
    }

    func testMarkdownFolderDryRunAndApply() async throws {
        try await boot()
        let root = fixture("markdown-folder")
        let summary = try await importer.dryRun(
            sourceRoot: root,
            kind: .markdownFolder,
            conflictPolicy: .skip
        )
        XCTAssertEqual(summary.sourceKind, .markdownFolder)
        XCTAssertGreaterThanOrEqual(summary.items.count, 2)
        XCTAssertEqual(summary.skipCount, 0)
        XCTAssertFalse(summary.media.isEmpty)

        let result = try await importer.apply(summary: summary, conflictPolicy: .skip)
        XCTAssertEqual(result.writtenCount, summary.items.count)
        XCTAssertFalse(result.mediaCopied.isEmpty)

        // Hello World should land under objects/page/
        let hello = result.written.first { $0.title == "Hello World" }
        XCTAssertNotNil(hello)
        XCTAssertTrue(hello!.destinationRelativePath.hasPrefix("objects/page/"))
        let exists = try await vault.fileExists(atRelativePath: hello!.destinationRelativePath)
        XCTAssertTrue(exists)

        // Index must not live in vault
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
        XCTAssertFalse(sqliteInVault)
    }

    func testObsidianPreservesDailyPathAndRewritesWikiLinks() async throws {
        try await boot()
        let root = fixture("obsidian-vault")
        let summary = try await importer.dryRun(
            sourceRoot: root,
            kind: .obsidianVault,
            conflictPolicy: .skip
        )
        XCTAssertEqual(summary.sourceKind, .obsidianVault)
        let daily = summary.items.first { $0.isDaily }
        XCTAssertNotNil(daily)
        XCTAssertEqual(daily?.destinationRelativePath, "daily/2026-08-01.md")
        XCTAssertEqual(daily?.objectID.frontMatterIDString, "daily-2026-08-01")
        XCTAssertTrue(daily?.preservedObjectID == true)

        let result = try await importer.apply(summary: summary, conflictPolicy: .skip)
        XCTAssertGreaterThanOrEqual(result.writtenCount, 3)

        let dailyData = try await vault.readFile(atRelativePath: "daily/2026-08-01.md")
        let dailyText = String(data: dailyData, encoding: .utf8) ?? ""
        XCTAssertTrue(dailyText.contains("id: daily-2026-08-01"))
        // Wiki-link to Welcome should be rewritten toward slug/id
        XCTAssertTrue(
            dailyText.contains("[[welcome") || dailyText.contains("[[Welcome"),
            "expected wiki-link rewrite in daily body: \(dailyText)"
        )

        // Obsidian embed → markdown image under media/
        let welcome = result.written.first { $0.title == "Welcome" }
        XCTAssertNotNil(welcome)
        let welcomeData = try await vault.readFile(atRelativePath: welcome!.destinationRelativePath)
        let welcomeText = String(data: welcomeData, encoding: .utf8) ?? ""
        XCTAssertTrue(
            welcomeText.contains("](") && welcomeText.contains("media/"),
            "expected media image ref: \(welcomeText)"
        )
    }

    func testCapacitiesPreservesObjectIDAndMapsBookType() async throws {
        try await boot()
        let root = fixture("capacities-export")
        let summary = try await importer.dryRun(
            sourceRoot: root,
            kind: .capacitiesExport,
            conflictPolicy: .skip
        )
        XCTAssertEqual(summary.sourceKind, .capacitiesExport)

        let page = summary.items.first { $0.title == "My Page" }
        XCTAssertNotNil(page)
        XCTAssertTrue(page!.preservedObjectID)
        XCTAssertEqual(
            page!.objectID.uuidString.lowercased(),
            "11111111-2222-4333-8444-555555555555"
        )

        let book = summary.items.first { $0.title == "Deep Work" }
        XCTAssertNotNil(book)
        XCTAssertEqual(book!.typeID, ObjectTypeID("book"))

        let result = try await importer.apply(summary: summary, conflictPolicy: .skip)
        XCTAssertEqual(result.writtenCount, 2)

        // Custom Book type should exist in schema
        let types = try await schema.knownTypeIDs()
        XCTAssertTrue(types.contains(ObjectTypeID("book")))

        let openedMeta = try await index.object(id: page!.objectID)
        XCTAssertNotNil(openedMeta)
        XCTAssertEqual(openedMeta?.title, "My Page")
    }

    func testConflictSkipDoesNotOverwrite() async throws {
        try await boot()
        let root = fixture("markdown-folder")
        let first = try await importer.importFrom(
            sourceRoot: root,
            kind: .markdownFolder,
            conflictPolicy: .skip
        )
        XCTAssertGreaterThan(first.writtenCount, 0)

        let secondSummary = try await importer.dryRun(
            sourceRoot: root,
            kind: .markdownFolder,
            conflictPolicy: .skip
        )
        XCTAssertEqual(secondSummary.skipCount, secondSummary.items.count)

        let second = try await importer.apply(summary: secondSummary, conflictPolicy: .skip)
        XCTAssertEqual(second.writtenCount, 0)
        XCTAssertEqual(second.skippedCount, secondSummary.items.count)
    }

    func testModuleVersionMentionsPR27() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr27") || LociVaultModule.version.contains("pr28") || LociVaultModule.version.contains("pr29") || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34"),
            LociVaultModule.version
        )
    }
}
