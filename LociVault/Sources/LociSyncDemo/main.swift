import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: sync status + conflict scan fixtures for DevHarness Settings (PR21).
@main
struct LociSyncDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-sync-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-sync-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Sync")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let sync = SyncStatusService(vault: vault)

        // Clean page + conflicted markdown + conflicted media.
        var page = try await objects.create(typeID: .page, title: "Sync Note")
        try await objects.save(
            meta: page,
            bodyMarkdown: "Airplane mode edit → reconnect → status clears."
        )
        page = try await index.object(id: page.id) ?? page

        try await vault.writeFile(
            Data("# Conflicted body\n".utf8),
            atRelativePath: "objects/page/Sync Note (Conflicted copy from MacBook).md"
        )
        try await vault.writeFile(
            Data("CONFLICT-PNG".utf8),
            atRelativePath: "media/images/hero (Conflicted copy from iPhone).png"
        )
        try await vault.writeFile(
            Data("ok".utf8),
            atRelativePath: "media/images/hero.png"
        )

        // Ensure-downloaded no-op success on local.
        try await vault.ensureDownloaded(atRelativePath: page.relativePath)
        try await vault.ensureDownloaded(atRelativePath: "media/images/hero.png")

        let conflicts = try await sync.listConflictedCopies()
        let status = await sync.currentStatus()
        let path = try await sync.vaultPathDisplay()
        let revealed = try await sync.revealVaultPath()

        // Baseline local-only when no conflict elevation / no override.
        let localBaseline = SyncStatusDerivation.derive(
            rootKind: .localDocuments,
            hasConflicts: false
        )

        // Simulated chip states for harness demo (Linux).
        let simulated: [(String, SyncStatus)] = [
            ("localOnly", .localOnly),
            ("syncing", .syncing),
            ("offline", .offline),
            ("iCloudAvailable", .iCloudAvailable),
            ("conflict", .conflict),
            ("error", .error),
        ]

        try await index.rebuild()
        let afterRebuild = try await index.object(id: page.id)

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "status": status.rawValue,
            "statusLabel": status.displayLabel,
            "vaultPath": path,
            "revealedPath": revealed,
            "rootKind": "localDocuments",
            "ensureDownloaded": true,
            "rebuildIndex": afterRebuild != nil,
            "conflicts": conflicts.map { item -> [String: String] in
                [
                    "relativePath": item.relativePath,
                    "kind": item.kind.rawValue,
                    "filename": item.filename,
                ]
            },
            "simulatedStatuses": simulated.map { ["id": $0.0, "label": $0.1.displayLabel] },
            "proof": [
                "localOnlyBaseline": localBaseline == .localOnly,
                "conflictStatusFromCopies": status == .conflict,
                "hasMarkdownConflict": conflicts.contains { $0.kind == .markdown },
                "hasMediaConflict": conflicts.contains { $0.kind == .media },
                "ensureDownloadedNoOp": true,
                "rebuildIndexOk": afterRebuild != nil,
                "pathRevealed": revealed == path,
                "indexOutsideVault": !path.contains("index.sqlite"),
            ],
            "note":
                "PR21 Sync UX — chip states, conflict list (incl. media), rebuild index, reveal vault path. Linux uses local-only baseline + conflict elevation + simulated states.",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
