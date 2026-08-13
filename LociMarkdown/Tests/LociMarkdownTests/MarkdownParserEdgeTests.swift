import XCTest
@testable import LociMarkdown

final class MarkdownParserEdgeTests: XCTestCase {
    func testUnbalancedFenceThrows() {
        let md = "```swift\nlet x = 1\n"
        XCTAssertThrowsError(try MarkdownParser().parse(md)) { error in
            XCTAssertEqual(error as? MarkdownError, .unbalancedFence)
        }
    }

    func testHeadingLevelsAboveFourBecomeParagraph() throws {
        // Level 5 is outside Loci budget — treated as paragraph text.
        let doc = try MarkdownParser().parse("##### Too deep\n")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .paragraph(let inlines) = doc.blocks[0] else {
            return XCTFail("expected paragraph for h5")
        }
        XCTAssertEqual(MarkdownSerializer().serializeInlines(inlines), "##### Too deep")
    }

    func testModuleRoundTripHelper() throws {
        let md = "# Hi\n\nBody #tag\n"
        let out = try LociMarkdownModule.roundTrip(md)
        let doc = try LociMarkdownModule.parse(out)
        XCTAssertEqual(doc.blocks.first, .heading(level: 1, inlines: [.text("Hi")]))
        XCTAssertEqual(LociMarkdownModule.version, "0.2.0-pr24")
    }
}
