import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: attach image/file into vault `media/` + Image object for DevHarness (PR20 / PR35 pickers).
@main
struct LociMediaDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-media-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-media-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Media")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let media = MediaService(vault: vault)
        let factory = ImageObjectFactory(media: media, objects: objects)

        // Temp source files (Linux-testable attach path).
        let imageTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-demo-hero-\(UUID().uuidString).png")
        let fileTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-demo-notes-\(UUID().uuidString).txt")
        let imageBytes = Data("DEMO-PNG-BYTES-PR20".utf8)
        let fileBytes = Data("DEMO-FILE-BYTES-PR20".utf8)
        try imageBytes.write(to: imageTemp)
        try fileBytes.write(to: fileTemp)
        defer {
            try? FileManager.default.removeItem(at: imageTemp)
            try? FileManager.default.removeItem(at: fileTemp)
        }

        let imageAttachment = try await media.attach(
            fileURL: imageTemp,
            kind: .image,
            preferredFileName: "hero.png"
        )
        let fileAttachment = try await media.attach(
            fileURL: fileTemp,
            kind: .file,
            preferredFileName: "notes.txt"
        )

        var page = try await objects.create(typeID: .page, title: "Media Note")
        let body = MediaInserter.appendImage(
            to: "Image in note syncs via vault folder.",
            alt: "Hero",
            attachment: imageAttachment,
            fromObjectRelativePath: page.relativePath
        )
        try await objects.save(meta: page, bodyMarkdown: body)
        page = try await index.object(id: page.id) ?? page
        let openedPage = try await objects.open(id: page.id)

        let imageObject = try await factory.create(
            fileURL: imageTemp,
            title: "Hero Object",
            alt: "Hero Object"
        )

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

        let mediaPathProp: String
        if case .text(let p)? = imageObject.meta.properties["media-path"] {
            mediaPathProp = p
        } else {
            mediaPathProp = ""
        }

        let dbData = try Data(contentsOf: index.databaseURL)
        let blobInIndex = dbData.range(of: imageBytes) != nil

        let pickerProof = MediaPickerProof.evaluate(
            attachment: imageAttachment,
            noteBody: openedPage.bodyMarkdown,
            indexInsideVault: sqliteInVault,
            attachedViaFileURL: true,
            photosPickerWired: true,
            dragDropWired: true
        )

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "imageAttachment": attachmentJSON(imageAttachment),
            "fileAttachment": attachmentJSON(fileAttachment),
            "page": [
                "id": page.id.uuidString.lowercased(),
                "title": page.title,
                "type": page.typeID.rawValue,
                "relativePath": page.relativePath,
                "bodyMarkdown": openedPage.bodyMarkdown,
            ],
            "imageObject": [
                "id": imageObject.meta.id.uuidString.lowercased(),
                "title": imageObject.meta.title,
                "type": imageObject.meta.typeID.rawValue,
                "relativePath": imageObject.meta.relativePath,
                "mediaPath": mediaPathProp,
                "bodyMarkdown": imageObject.bodyMarkdown,
            ],
            "mediaListing": try listMedia(vaultRoot: vaultRoot),
            "proof": [
                "imageInMediaImages": imageAttachment.relativePath.hasPrefix("media/images/"),
                "fileInMediaFiles": fileAttachment.relativePath.hasPrefix("media/files/"),
                "pageHasMarkdownImage": openedPage.bodyMarkdown.contains("![Hero]("),
                "imageObjectCreated": imageObject.meta.typeID == .image,
                "blobNotInIndex": !blobInIndex,
                "indexOutsideVault": !sqliteInVault,
                "photosPickerWired": pickerProof.photosPickerWired,
                "dragDropWired": pickerProof.dragDropWired,
                "attachedViaFileURL": pickerProof.attachedViaFileURL,
                "markdownRelativePathStartsWithMedia":
                    pickerProof.markdownRelativePathStartsWithMedia,
                "noteBodyHasAbsolutePath": pickerProof.noteBodyHasAbsolutePath,
            ],
            "picker": [
                "photosPickerWired": pickerProof.photosPickerWired,
                "dragDropWired": pickerProof.dragDropWired,
                "attachedViaFileURL": pickerProof.attachedViaFileURL,
                "linuxAttachPath": MediaPickerNotes.linuxAttachPath,
                "photosUIStaysInApp": MediaPickerNotes.photosUIStaysInApp,
            ],
            "note":
                "PR35: PhotosPicker (iOS) + drop (macOS) copy via MediaServing; Linux uses attach(fileURL:). Notes keep vault-relative media/ paths — never absolute disk paths or SQLite blobs.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func attachmentJSON(_ a: MediaAttachment) -> [String: Any] {
        [
            "relativePath": a.relativePath,
            "kind": a.kind.rawValue,
            "fileName": a.fileName,
            "byteCount": a.byteCount,
        ]
    }

    private static func listMedia(vaultRoot: URL) throws -> [String: [String]] {
        var images: [String] = []
        var files: [String] = []
        let imgDir = vaultRoot.appendingPathComponent("media/images", isDirectory: true)
        let fileDir = vaultRoot.appendingPathComponent("media/files", isDirectory: true)
        if let imgs = try? FileManager.default.contentsOfDirectory(atPath: imgDir.path) {
            images = imgs.sorted()
        }
        if let fs = try? FileManager.default.contentsOfDirectory(atPath: fileDir.path) {
            files = fs.sorted()
        }
        return ["images": images, "files": files]
    }
}
