import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: write sample pages via VaultService, rebuild index, emit JSON for DevHarness Search panel.
@main
struct LociIndexDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-index-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-index-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        try await vault.ensureSkeleton(spaceName: "Demo Index")

        let pages: [(UUID, String, String, String)] = [
            (
                UUID(uuidString: "8f3c2a1e-1111-4111-8111-000000000001")!,
                "Hello Loci",
                "objects/page/hello-loci.md",
                "This is a simple page with a [[8f3c2a1e-2222-4222-8222-000000000002|related note]] and a #focus tag."
            ),
            (
                UUID(uuidString: "8f3c2a1e-2222-4222-8222-000000000002")!,
                "Related Note",
                "objects/page/related-note.md",
                "Deep work notes about attention and #focus rituals."
            ),
            (
                UUID(uuidString: "8f3c2a1e-3333-4333-8333-000000000003")!,
                "Daily seed",
                "daily/2026-08-13.md",
                "Created today checklist."
            ),
        ]

        let created = ISO8601DateFormatter().date(from: "2026-08-13T09:12:00Z")!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        for (id, title, path, body) in pages {
            let type = path.hasPrefix("daily/") ? "daily" : "page"
            let md = """
                ---
                id: \(id.uuidString.lowercased())
                type: \(type)
                title: \(title)
                created: \(iso.string(from: created))
                updated: \(iso.string(from: created))
                tags: [demo]
                ---

                \(body)
                """
            try await vault.writeFile(Data(md.utf8), atRelativePath: path)
        }

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        try await index.rebuild()

        let vaultRoot = try await vault.vaultRootURL
        let searchHits = try await index.search(query: "focus")
        let createdHits = try await index.created(on: created)
        let pagesList = try await index.objects(typeID: .page)

        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let payload: [String: Any] = [
            "moduleVersion": LociIndexModule.version,
            "sqliteEngine": "GRDB",
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "vaultID": index.vaultID,
            "indexInsideVault": sqliteInVault,
            "objectCount": pagesList.count,
            "searchQuery": "focus",
            "searchHits": searchHits.map { metaJSON($0) },
            "createdOn": iso.string(from: created),
            "createdHits": createdHits.map { metaJSON($0) },
            "pages": pagesList.map { metaJSON($0) },
            "note": "index.sqlite must never live inside the vault (Application Support / temp only).",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }

        // Cleanup demo temps (optional — leave if CI wants inspection)
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
