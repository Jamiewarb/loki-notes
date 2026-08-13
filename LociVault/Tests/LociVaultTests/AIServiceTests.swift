import XCTest
import LociCore
import LociIndex
import LociMarkdown
@testable import LociVault

final class AIServiceTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var aiParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var ai: AIService!
    private var credentials: AICredentialStore!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-ai-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-ai-db-\(stamp)", isDirectory: true)
        aiParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-ai-settings-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aiParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
        if let aiParent { try? FileManager.default.removeItem(at: aiParent) }
    }

    private func boot() async throws {
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "AI Tests")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        credentials = AICredentialStore(directory: aiParent)
        ai = AIService(settingsDirectory: aiParent, credentials: credentials, remote: nil)
    }

    func testRunHeuristicsWithoutNetwork() async throws {
        try await boot()
        let meta = try await objects.create(typeID: .page, title: "Hello world")
        try await objects.save(
            meta: meta,
            bodyMarkdown: "First sentence. Second sentence. Third.\n"
        )
        let opened = try await objects.open(id: meta.id)
        let proposal = try await ai.run(
            AIRequest(
                action: .summarize,
                objectID: opened.meta.id,
                title: opened.meta.title,
                bodyMarkdown: opened.bodyMarkdown
            )
        )
        XCTAssertEqual(proposal.provider, .onDeviceHeuristics)
        XCTAssertFalse(proposal.uploaded)
        XCTAssertNotNil(proposal.summary)
        XCTAssertTrue(proposal.summary!.hasPrefix("Summary: "))
    }

    func testUploadRefusedWithoutOptIn() async throws {
        try await boot()
        let meta = try await objects.create(typeID: .page, title: "Secret")
        var settings = AISettings(preferredProvider: .byok, uploadVaultOptIn: false)
        settings.byokProviderName = "openai"
        try await ai.saveSettings(settings)
        try credentials.setAPIKey("sk-test-fake-key", for: "openai")

        var req = AIRequest(
            action: .summarize,
            objectID: meta.id,
            title: meta.title,
            bodyMarkdown: "do not upload",
            allowRemoteUpload: true
        )
        do {
            _ = try await ai.run(req)
            XCTFail("expected aiUploadNotAllowed")
        } catch LociError.aiUploadNotAllowed {
            // expected
        }

        // BYOK preferred without allowRemoteUpload stays on-device (local assist never blocked).
        req.allowRemoteUpload = false
        let local = try await ai.run(req)
        XCTAssertEqual(local.provider, .onDeviceHeuristics)
        XCTAssertFalse(local.uploaded)
        XCTAssertNotNil(local.summary)
    }

    func testApplyUsesObjectServing() async throws {
        try await boot()
        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#0F6B5C",
            slug: "book"
        )
        try await schema.setProperties(
            book.id,
            properties: [
                PropertyDef(id: "url", name: "URL", kind: .url),
                PropertyDef(id: "status", name: "Status", kind: .select, options: ["Draft", "Read"]),
            ]
        )
        let meta = try await objects.create(typeID: book.id, title: "AI Book")
        try await objects.save(
            meta: meta,
            bodyMarkdown: "See https://example.com/book on 2024-01-02. Status Read.\n"
        )
        let opened = try await objects.open(id: meta.id)
        let type = try await schema.loadType(book.id)
        let proposal = try await ai.run(
            AIRequest(
                action: .autofillProperties,
                objectID: opened.meta.id,
                title: opened.meta.title,
                bodyMarkdown: opened.bodyMarkdown,
                propertyDefs: type.properties,
                existingProperties: opened.meta.properties
            )
        )
        XCTAssertNotNil(proposal.proposedProperties)
        let applied = try await ai.apply(proposal, using: objects)
        XCTAssertEqual(applied.meta.properties["url"], .url("https://example.com/book"))
        XCTAssertEqual(applied.meta.properties["status"], .select("Read"))
        XCTAssertTrue(applied.meta.relativePath.hasPrefix("objects/book/"))
        // File changed under objects/ via ObjectServing — not a direct vault.writeFile from AI.
        let vaultRoot = try await vault.vaultRootURL
        let objectURL = vaultRoot.appendingPathComponent(applied.meta.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: objectURL.path))
    }

    func testCredentialsAndSettingsOutsideVault() async throws {
        try await boot()
        try credentials.setAPIKey("sk-never-in-vault", for: "openai")
        try await ai.saveSettings(AISettings(preferredProvider: .onDeviceHeuristics))

        let vaultRoot = try await vault.vaultRootURL
        let vaultPath = vaultRoot.path
        XCTAssertFalse(credentials.credentialsFileURL.path.hasPrefix(vaultPath + "/"))
        XCTAssertFalse(ai.settingsFileURL.path.hasPrefix(vaultPath + "/"))
        XCTAssertTrue(credentials.credentialsFileURL.path.contains("loci-ai-settings-"))
        XCTAssertTrue(ai.settingsFileURL.path.contains("loci-ai-settings-"))

        // Scan vault for fake key string and index.sqlite
        var foundKey = false
        var foundIndex = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { foundIndex = true }
                if let data = try? Data(contentsOf: url),
                    let text = String(data: data, encoding: .utf8),
                    text.contains("sk-never-in-vault")
                {
                    foundKey = true
                }
            }
        }
        XCTAssertFalse(foundKey)
        XCTAssertFalse(foundIndex)
    }

    func testRewriteAndTranslateViaService() async throws {
        try await boot()
        let meta = try await objects.create(typeID: .page, title: "Page")
        let rewrite = try await ai.run(
            AIRequest(
                action: .rewrite,
                objectID: meta.id,
                title: meta.title,
                bodyMarkdown: "This is very really just fine.\n\n\n\nMore.\n"
            )
        )
        XCTAssertNotNil(rewrite.proposedBody)
        XCTAssertFalse(rewrite.uploaded)

        let translate = try await ai.run(
            AIRequest(
                action: .translate,
                objectID: meta.id,
                title: meta.title,
                bodyMarkdown: "hello world",
                targetLanguage: "es"
            )
        )
        XCTAssertTrue(translate.proposedBody?.contains("hola") == true)
        XCTAssertFalse(translate.uploaded)
    }
}
