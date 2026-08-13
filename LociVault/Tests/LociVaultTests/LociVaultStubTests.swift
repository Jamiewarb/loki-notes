import XCTest
@testable import LociVault

final class LociVaultStubTests: XCTestCase {
    func testStubVersionPresent() {
        XCTAssertFalse(LociVaultModule.stubVersion.isEmpty)
    }
}
