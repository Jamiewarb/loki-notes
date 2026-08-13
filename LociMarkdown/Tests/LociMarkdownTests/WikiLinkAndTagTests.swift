import XCTest
@testable import LociMarkdown

final class WikiLinkAndTagTests: XCTestCase {
    func testWikiLinkParseAndMarkdown() {
        let plain = WikiLink.parse("[[projects/q3]]")
        XCTAssertEqual(plain?.target, "projects/q3")
        XCTAssertNil(plain?.label)
        XCTAssertEqual(plain?.markdown, "[[projects/q3]]")

        let labeled = WikiLink.parse("[[id-1|Hello]]")
        XCTAssertEqual(labeled?.target, "id-1")
        XCTAssertEqual(labeled?.label, "Hello")
        XCTAssertEqual(labeled?.markdown, "[[id-1|Hello]]")
        XCTAssertEqual(labeled?.displayText, "Hello")
    }

    func testWikiLinkExtract() {
        let text = "See [[a]] and [[b|Bee]] end"
        let links = WikiLinkSyntax.extract(from: text)
        XCTAssertEqual(links.map(\.target), ["a", "b"])
        XCTAssertEqual(links[1].label, "Bee")
    }

    func testTagExtractAndNormalize() {
        XCTAssertEqual(TagSyntax.normalize("#Focus"), "Focus")
        XCTAssertEqual(TagSyntax.markdown("daily"), "#daily")
        XCTAssertTrue(TagSyntax.isValidTagBody("focus"))
        XCTAssertTrue(TagSyntax.isValidTagBody("a/b"))
        XCTAssertFalse(TagSyntax.isValidTagBody("1bad"))

        let tags = TagSyntax.extract(from: "hello #focus and #career/now!")
        XCTAssertEqual(tags, ["focus", "career/now"])
    }

    func testInlineParserWikiAndTag() {
        let nodes = InlineParser.parse("Go [[x|Y]] for #ship now")
        XCTAssertEqual(nodes.count, 5)
        guard case .wikiLink(let link) = nodes[1] else {
            return XCTFail("expected wikiLink")
        }
        XCTAssertEqual(link.target, "x")
        XCTAssertEqual(link.label, "Y")
        guard case .tag(let tag) = nodes[3] else {
            return XCTFail("expected tag")
        }
        XCTAssertEqual(tag, "ship")
    }

    func testBodyMarkdownStripsFrontMatter() throws {
        let md = """
            ---
            title: Notes
            ---

            I read Deep Work yesterday
            """
        let body = try MarkdownParser.bodyMarkdown(from: md)
        XCTAssertTrue(body.contains("I read Deep Work yesterday"))
        XCTAssertFalse(body.contains("title: Notes"))
    }
}
