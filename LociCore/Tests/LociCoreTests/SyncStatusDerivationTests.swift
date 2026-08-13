import XCTest
import LociCore

final class SyncStatusDerivationTests: XCTestCase {
    func testLocalDocumentsYieldsLocalOnly() {
        let status = SyncStatusDerivation.derive(rootKind: .localDocuments)
        XCTAssertEqual(status, .localOnly)
    }

    func testICloudAvailableWhenOnlineAndIdle() {
        let status = SyncStatusDerivation.derive(
            rootKind: .iCloudUbiquity,
            isNetworkAvailable: true,
            isSyncing: false
        )
        XCTAssertEqual(status, .iCloudAvailable)
    }

    func testSyncingTakesPrecedenceOverAvailable() {
        let status = SyncStatusDerivation.derive(
            rootKind: .iCloudUbiquity,
            isNetworkAvailable: true,
            isSyncing: true
        )
        XCTAssertEqual(status, .syncing)
    }

    func testOfflineWhenNetworkUnavailable() {
        let status = SyncStatusDerivation.derive(
            rootKind: .iCloudUbiquity,
            isNetworkAvailable: false
        )
        XCTAssertEqual(status, .offline)
    }

    func testConflictOverridesSyncing() {
        let status = SyncStatusDerivation.derive(
            rootKind: .iCloudUbiquity,
            isSyncing: true,
            hasConflicts: true
        )
        XCTAssertEqual(status, .conflict)
    }

    func testErrorHighestPriority() {
        let status = SyncStatusDerivation.derive(
            rootKind: .localDocuments,
            hasConflicts: true,
            hasError: true
        )
        XCTAssertEqual(status, .error)
    }

    func testSimulatedOverrideWins() {
        let status = SyncStatusDerivation.derive(
            rootKind: .localDocuments,
            hasError: true,
            simulatedOverride: .syncing
        )
        XCTAssertEqual(status, .syncing)
    }

    func testConflictKindInference() {
        XCTAssertEqual(SyncConflictKind.infer(fromRelativePath: "objects/page/a.md"), .markdown)
        XCTAssertEqual(
            SyncConflictKind.infer(fromRelativePath: "media/images/hero (Conflicted copy).png"),
            .media
        )
        XCTAssertEqual(SyncConflictKind.infer(fromRelativePath: "notes.txt"), .other)
    }

    func testDisplayLabels() {
        XCTAssertEqual(SyncStatus.localOnly.displayLabel, "Local only")
        XCTAssertEqual(SyncStatus.iCloudAvailable.displayLabel, "iCloud available")
        XCTAssertFalse(SyncStatus.allCases.isEmpty)
    }
}
