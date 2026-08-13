import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: create Books type → Deep Work object → export fixture for DevHarness (PR12).
@main
struct LociTypesDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-types-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-types-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Custom Types")

        let books = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index)

        let deepWork = try await objects.create(typeID: books.id, title: "Deep Work")
        try await objects.save(
            meta: deepWork,
            bodyMarkdown: "Cal Newport — focus is a skill.\n\n#books"
        )
        let indexed = try await index.object(id: deepWork.id) ?? deepWork

        // Prove isolation: Books object not listed under Page.
        let bookList = try await index.objects(typeID: books.id)
        let pageList = try await index.objects(typeID: .page)

        let allTypes = try await schema.allTypes()
        let vaultRoot = try await vault.vaultRootURL
        let objectsFolder = SchemaStore.objectsFolderRelativePath(for: books.id)
        var folderExists = false
        var isDir: ObjCBool = false
        let folderURL = vaultRoot.appendingPathComponent(objectsFolder, isDirectory: true)
        folderExists = FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDir)
            && isDir.boolValue

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

        // Delete-guard proof (built-ins refuse).
        var pageDeleteBlocked = false
        do {
            try await schema.deleteType(.page, force: true)
        } catch let error as LociError {
            if case .typeProtected = error { pageDeleteBlocked = true }
        }

        let typeJSON = try await vault.readFile(
            atRelativePath: SchemaStore.typeRelativePath(for: books.id)
        )
        let typeText = String(data: typeJSON, encoding: .utf8) ?? ""

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "space": [
                "name": "Demo Custom Types",
            ],
            "types": allTypes.map { typeMetaJSON($0) },
            "createdType": typeMetaJSON(books),
            "objectsFolder": objectsFolder,
            "objectsFolderExists": folderExists,
            "bookObject": metaJSON(indexed),
            "booksCount": bookList.count,
            "pagesCount": pageList.count,
            "appearsOnlyUnderBooks": bookList.count == 1 && pageList.isEmpty,
            "pageDeleteBlocked": pageDeleteBlocked,
            "typeJSONPreview": String(typeText.prefix(280)),
            "note":
                "Create Books → Deep Work under objects/book/. Appears only under Books index query. Built-in Page delete guarded.",
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

    private static func typeMetaJSON(_ type: ObjectType) -> [String: Any] {
        [
            "id": type.id.rawValue,
            "name": type.name,
            "icon": type.icon,
            "color": type.color,
            "isBuiltIn": type.isBuiltIn,
            "isDaily": type.isDaily,
            "properties": type.properties.map { ["id": $0.id, "name": $0.name, "kind": $0.kind.rawValue] },
        ]
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
