import XCTest
import LociCore
import LociIndex
import LociMarkdown
@testable import LociVault

final class MediaSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var media: MediaService!

    override func setUpWithError() throws {
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-media-vault-\(UUID().uuidString)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-media-db-\(UUID().uuidString)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "Media Tests")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        media = MediaService(vault: vault)
    }

    func testAttachCopiesTempFileIntoMediaImages() async throws {
        try await boot()
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-src-\(UUID().uuidString).png")
        let payload = Data("fake-png-bytes".utf8)
        try payload.write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let attachment = try await media.attach(fileURL: temp, kind: nil, preferredFileName: nil)
        XCTAssertEqual(attachment.kind, .image)
        XCTAssertTrue(attachment.relativePath.hasPrefix("media/images/"))
        XCTAssertEqual(attachment.byteCount, payload.count)

        let exists = try await vault.fileExists(atRelativePath: attachment.relativePath)
        XCTAssertTrue(exists)
        let read = try await vault.readFile(atRelativePath: attachment.relativePath)
        XCTAssertEqual(read, payload)
    }

    func testAttachFileGoesToMediaFilesAndCollisionRenames() async throws {
        try await boot()
        let first = try await media.attach(
            data: Data("one".utf8),
            kind: .file,
            preferredFileName: "readme.txt"
        )
        let second = try await media.attach(
            data: Data("two".utf8),
            kind: .file,
            preferredFileName: "readme.txt"
        )
        XCTAssertEqual(first.relativePath, "media/files/readme.txt")
        XCTAssertTrue(second.relativePath.hasPrefix("media/files/readme-"))
        XCTAssertNotEqual(first.relativePath, second.relativePath)
    }

    func testImageObjectFactoryWritesBlobAndMarkdownNotSQLite() async throws {
        try await boot()
        let factory = ImageObjectFactory(media: media, objects: objects)
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("hero-\(UUID().uuidString).png")
        try Data("hero-bytes".utf8).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let opened = try await factory.create(fileURL: temp, title: "Hero Shot")
        XCTAssertEqual(opened.meta.typeID, .image)
        XCTAssertEqual(opened.meta.title, "Hero Shot")
        guard case .text(let path)? = opened.meta.properties["media-path"] else {
            return XCTFail("expected media-path property")
        }
        XCTAssertTrue(path.hasPrefix("media/images/"))
        XCTAssertTrue(opened.bodyMarkdown.contains("![Hero Shot]("))
        XCTAssertTrue(opened.bodyMarkdown.contains("media/images/"))

        let blobExists = try await vault.fileExists(atRelativePath: path)
        XCTAssertTrue(blobExists)

        let indexed = try await index.object(id: opened.meta.id)
        XCTAssertEqual(indexed?.title, "Hero Shot")

        // Blobs must never live in SQLite — only vault `media/` holds bytes.
        let dbData = try Data(contentsOf: index.databaseURL)
        XCTAssertNil(
            dbData.range(of: Data("hero-bytes".utf8)),
            "media payload must not be stored in the index database"
        )

        var sqliteInVault = false
        let vaultRoot = try await vault.vaultRootURL
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.pathExtension == "sqlite" { sqliteInVault = true }
            }
        }
        XCTAssertFalse(sqliteInVault)
    }

    func testAppendImageIntoPageNote() async throws {
        try await boot()
        let page = try await objects.create(typeID: .page, title: "With Image")
        let attachment = try await media.attach(
            data: Data("pic".utf8),
            kind: .image,
            preferredFileName: "pic.png"
        )
        let body = MediaInserter.appendImage(
            to: "Intro paragraph",
            alt: "pic",
            attachment: attachment,
            fromObjectRelativePath: page.relativePath
        )
        try await objects.save(meta: page, bodyMarkdown: body)
        let opened = try await objects.open(id: page.id)
        XCTAssertTrue(opened.bodyMarkdown.contains("![pic](../../media/images/pic.png)"))

        let doc = try MarkdownParser().parse(opened.bodyMarkdown)
        let hasImage = doc.blocks.contains {
            if case .image = $0 { return true }
            return false
        }
        XCTAssertTrue(hasImage)
    }

    func testSkeletonSeedsImageType() async throws {
        try await boot()
        let imageType = try await schema.loadType(.image)
        XCTAssertTrue(imageType.isBuiltIn)
        let exists = try await vault.fileExists(
            atRelativePath: SchemaStore.typeRelativePath(for: .image)
        )
        XCTAssertTrue(exists)
    }

    func testModuleVersionsPR20() {
        XCTAssertTrue(LociVaultModule.version.contains("pr22") || LociVaultModule.version.contains("pr23") || LociVaultModule.version.contains("pr24") || LociVaultModule.version.contains("pr25") || LociVaultModule.version.contains("pr26") || LociVaultModule.version.contains("pr27") || LociVaultModule.version.contains("pr28") || LociVaultModule.version.contains("pr29") || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31"))
        XCTAssertTrue(LociIndexModule.version.contains("pr22") || LociIndexModule.version.contains("pr23") || LociIndexModule.version.contains("pr24") || LociIndexModule.version.contains("pr25") || LociIndexModule.version.contains("pr26") || LociIndexModule.version.contains("pr27") || LociIndexModule.version.contains("pr28") || LociIndexModule.version.contains("pr29") || LociIndexModule.version.contains("pr30"))
        XCTAssertTrue(LociMarkdownModule.version.contains("pr22") || LociMarkdownModule.version.contains("pr23") || LociMarkdownModule.version.contains("pr24") || LociMarkdownModule.version.contains("pr25") || LociMarkdownModule.version.contains("pr26") || LociMarkdownModule.version.contains("pr27") || LociMarkdownModule.version.contains("pr28") || LociMarkdownModule.version.contains("pr29") || LociMarkdownModule.version.contains("pr30"))
    }
}
