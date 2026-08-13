import XCTest
import LociCore
import LociVault

final class SyncConflictListingTests: XCTestCase {
    private var tempParent: URL!

    override func setUpWithError() throws {
        tempParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempParent)
    }

    func testListsMarkdownAndMediaConflicts() async throws {
        let vault = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await vault.ensureSkeleton(spaceName: "Sync")

        try await vault.writeFile(
            Data("# note".utf8),
            atRelativePath: "objects/page/Note (Conflicted copy from MacBook).md"
        )
        try await vault.writeFile(
            Data("png".utf8),
            atRelativePath: "media/images/hero (Conflicted copy from iPhone).png"
        )
        try await vault.writeFile(
            Data("# clean".utf8),
            atRelativePath: "objects/page/Clean.md"
        )

        let items = try await vault.listConflictedCopies()
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains { $0.kind == .markdown })
        XCTAssertTrue(items.contains { $0.kind == .media })
        XCTAssertFalse(items.contains { $0.relativePath.contains("Clean.md") })
    }

    func testEnsureDownloadedNoOpOnLocalRoot() async throws {
        let vault = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await vault.ensureSkeleton(spaceName: "Sync")
        try await vault.writeFile(Data("hi".utf8), atRelativePath: "daily/2026-08-13.md")
        try await vault.ensureDownloaded(atRelativePath: "daily/2026-08-13.md")
    }

    func testSyncStatusServiceLocalOnly() async throws {
        let vault = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        let sync = SyncStatusService(vault: vault)
        let status = await sync.currentStatus()
        XCTAssertEqual(status, .localOnly)

        sync.simulatedOverride = .offline
        let simulated = await sync.currentStatus()
        XCTAssertEqual(simulated, .offline)

        let path = try await sync.vaultPathDisplay()
        XCTAssertFalse(path.isEmpty)
        let revealed = try await sync.revealVaultPath()
        XCTAssertEqual(revealed, path)
    }

    func testConflictRaisesStatus() async throws {
        let vault = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await vault.ensureSkeleton(spaceName: "Sync")
        try await vault.writeFile(
            Data("x".utf8),
            atRelativePath: "media/files/notes (Conflicted copy from Mac).txt"
        )
        let sync = SyncStatusService(vault: vault)
        // Local root stays localOnly unless override — conflicts elevate when iCloud.
        // Force iCloud-like derivation via override clear + rootKind local → localOnly.
        // Conflict elevation applies when root is iCloud; on local we still list conflicts.
        let items = try await sync.listConflictedCopies()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].kind, .media)

        // Simulate iCloud + conflict via derivation helper (root still local for I/O).
        let derived = SyncStatusDerivation.derive(
            rootKind: .iCloudUbiquity,
            hasConflicts: !items.isEmpty
        )
        XCTAssertEqual(derived, .conflict)
    }

    func testModuleVersionPR22() {
        XCTAssertTrue(LociVaultModule.version.contains("pr22") || LociVaultModule.version.contains("pr23") || LociVaultModule.version.contains("pr24") || LociVaultModule.version.contains("pr25"))
    }
}
