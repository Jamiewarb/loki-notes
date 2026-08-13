import XCTest
@testable import LociMarkdown

final class LociMarkdownStubTests: XCTestCase {
    func testStubVersionPresent() {
        XCTAssertFalse(LociMarkdownModule.stubVersion.isEmpty)
    }
}
