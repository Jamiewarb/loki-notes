import Foundation
import LociCore
import LociVault

/// Tiny CLI demo: create a vault under a temp (or `$LOCI_VAULT_PARENT`) directory,
/// write `.loci/space.json`, print layout. Used by `scripts/demo-vault.sh`.
@main
enum LociVaultDemo {
    static func main() async throws {
        let parent: URL
        if let env = ProcessInfo.processInfo.environment["LOCI_VAULT_PARENT"], !env.isEmpty {
            parent = URL(fileURLWithPath: env, isDirectory: true)
        } else {
            parent = FileManager.default.temporaryDirectory
                .appendingPathComponent("loci-vault-demo-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        let service = try VaultService(preferredLocalDirectory: parent, forceLocal: true)
        try await service.ensureSkeleton(spaceName: "Loci Demo")
        let sample = Data("---\nid: demo\ntitle: Hello\n---\n\nFrom loci-vault-demo.\n".utf8)
        try await service.writeFile(sample, atRelativePath: "daily/2026-08-13.md")

        let root = try await service.vaultRootURL
        let kind = await service.rootKind
        let space = try await service.readFile(atRelativePath: VaultLayout.spaceJSON)

        print("LociVault demo \(LociVaultModule.version)")
        print("rootKind: \(kind.rawValue)")
        print("vaultRoot: \(root.path)")
        print("space.json: \(String(data: space, encoding: .utf8) ?? "")")
        print("skeleton:")
        for dir in VaultLayout.requiredDirectories {
            let url = try await service.absoluteURL(forRelativePath: dir)
            print("  ✓ \(dir) → \(url.path)")
        }
        print("sample: daily/2026-08-13.md written")
        print("note: index.sqlite must never live inside this vault (Application Support only).")
    }
}
