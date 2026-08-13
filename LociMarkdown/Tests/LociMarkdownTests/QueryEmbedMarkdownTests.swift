import XCTest
import Foundation
import LociCore
import LociMarkdown

final class QueryEmbedMarkdownTests: XCTestCase {
    func testQueryFenceRoundTrip() throws {
        let md = """
            Before

            ```query
            reading-books
            ```

            After
            """
        let doc = try MarkdownParser().parse(md)
        XCTAssertEqual(doc.blocks.count, 3)
        guard case .queryEmbed(let id) = doc.blocks[1] else {
            return XCTFail("expected queryEmbed, got \(doc.blocks[1])")
        }
        XCTAssertEqual(id, "reading-books")
        let out = MarkdownSerializer().serializeBlocks(doc.blocks)
        XCTAssertTrue(out.contains("```query\nreading-books\n```"))
        XCTAssertFalse(out.contains("Deep Work")) // no live results in body
        let again = try MarkdownParser().parse(out)
        guard case .queryEmbed(let id2) = again.blocks[1] else {
            return XCTFail("round-trip lost queryEmbed")
        }
        XCTAssertEqual(id2, "reading-books")
    }

    func testSlashQueryInsertsEmbed() {
        let session = EditorSession(blocks: [.paragraph([.text("/query")])])
        session.applySlashCommand(blockIndex: 0, kind: .query, queryText: "query")
        guard case .queryEmbed(let id) = session.blocks[0] else {
            return XCTFail("slash /query should convert to queryEmbed")
        }
        XCTAssertEqual(id, "query")
        XCTAssertTrue(SlashBlockKind.query.matches(query: "que"))
        XCTAssertEqual(SlashBlockKind.query.slashToken, "query")
    }

    func testQueryEmbedHTMLPlaceholder() {
        let html = BlockASTHTML.render([.queryEmbed(queryID: "reading-books")])
        XCTAssertTrue(html.contains("data-query-id=\"reading-books\""))
        XCTAssertTrue(html.contains("query-embed"))
        XCTAssertTrue(html.contains("live results"))
    }
}
