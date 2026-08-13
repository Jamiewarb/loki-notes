import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: create pages via ObjectService, export pages JSON for DevHarness Types/Page panel (PR08).
@main
struct LociObjectsDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-objects-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-objects-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Objects")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index)

        let hello = try await objects.create(typeID: .page, title: "Hello Loci")
        try await objects.save(
            meta: hello,
            bodyMarkdown: "First page from ObjectService.\n\nTag #demo and link later."
        )

        let second = try await objects.create(typeID: .page, title: "Second Note")
        try await objects.save(
            meta: second,
            bodyMarkdown: "Listed under Types → Page via IndexQuerying."
        )

        let opened = try await objects.open(id: hello.id)
        let pages = try await index.objects(typeID: .page)

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

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.objectCRUDVersion,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "pageCount": pages.count,
            "pages": pages.map { metaJSON($0) },
            "openedSample": [
                "id": opened.meta.id.uuidString.lowercased(),
                "title": opened.meta.title,
                "relativePath": opened.meta.relativePath,
                "bodyPreview": String(opened.bodyMarkdown.prefix(120)),
            ],
            "note":
                "ObjectService create→save→index→list. Pages listed from IndexQuerying; index never in vault.",
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

    private static func metaJSON(_ meta: LociObjectMeta) -> [String: Any] {
        [
            "id": meta.id.uuidString.lowercased(),
            "type": meta.typeID.rawValue,
            "title": meta.title,
            "relativePath": meta.relativePath,
            "tags": meta.tags,
        ]
    }
}
