import XCTest
@testable import LociIndex

final class LociIndexStubTests: XCTestCase {
    func testStubVersionPresent() {
        XCTAssertFalse(LociIndexModule.stubVersion.isEmpty)
    }

    func testIndexLivesOutsideVaultConvention() {
        // Guardrail reminder: index path is Application Support, not vault.
        XCTAssertEqual(LociIndexModule.applicationSupportSubdirectory, "Loci")
    }
}
