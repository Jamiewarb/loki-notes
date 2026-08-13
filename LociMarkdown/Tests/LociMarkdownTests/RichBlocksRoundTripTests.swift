import XCTest
import LociCore
@testable import LociMarkdown

final class RichBlocksRoundTripTests: XCTestCase {
    func testGFMTableRoundTrip() throws {
        let md = """
            | Name | Rating |
            | :--- | ---: |
            | Deep Work | 5 |
            | Atomic Habits | 4 |

            """
        let doc = try MarkdownParser().parse(md)
        guard case .table(let headers, let alignments, let rows) = doc.blocks.first else {
            return XCTFail("expected table, got \(doc.blocks)")
        }
        XCTAssertEqual(headers, ["Name", "Rating"])
        XCTAssertEqual(alignments, [.left, .right])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0], ["Deep Work", "5"])

        let serialized = MarkdownSerializer().serialize(doc)
        let again = try MarkdownParser().parse(serialized)
        XCTAssertEqual(again, doc)
        XCTAssertEqual(MarkdownSerializer().serialize(again), serialized)
    }

    func testToggleDetailsRoundTrip() throws {
        let md = """
            <details>
            <summary>Chapter notes</summary>

            Hidden paragraph with [[slug]] and #focus.

            </details>

            """
        let doc = try MarkdownParser().parse(md)
        guard case .toggle(let summary, let children, _) = doc.blocks.first else {
            return XCTFail("expected toggle")
        }
        XCTAssertEqual(MarkdownSerializer().serializeInlines(summary), "Chapter notes")
        XCTAssertFalse(children.isEmpty)

        let serialized = MarkdownSerializer().serialize(doc)
        let again = try MarkdownParser().parse(serialized)
        XCTAssertEqual(again, doc)
    }

    func testCalloutRoundTrip() throws {
        let md = """
            > [!warning] Watch this
            > Body of the callout
            > with a second line

            """
        let doc = try MarkdownParser().parse(md)
        guard case .callout(let kind, let title, let children) = doc.blocks.first else {
            return XCTFail("expected callout, got \(doc.blocks)")
        }
        XCTAssertEqual(kind, .warning)
        XCTAssertEqual(MarkdownSerializer().serializeInlines(title), "Watch this")
        XCTAssertFalse(children.isEmpty)

        let serialized = MarkdownSerializer().serialize(doc)
        let again = try MarkdownParser().parse(serialized)
        XCTAssertEqual(again, doc)
    }

    func testCalloutWithoutTitleUsesKind() throws {
        let md = "> [!TIP]\n> Helpful tip\n"
        let doc = try MarkdownParser().parse(md)
        guard case .callout(let kind, let title, _) = doc.blocks.first else {
            return XCTFail("expected callout")
        }
        XCTAssertEqual(kind, .tip)
        XCTAssertEqual(MarkdownSerializer().serializeInlines(title), "Tip")
    }

    func testSlashKindsMakeRichBlocks() throws {
        XCTAssertTrue(SlashBlockKind.table.matches(query: "ta"))
        XCTAssertTrue(SlashBlockKind.toggle.matches(query: "tog"))
        XCTAssertTrue(SlashBlockKind.callout.matches(query: "call"))
        XCTAssertTrue(SlashBlockKind.mermaid.matches(query: "mer"))

        guard case .table = SlashBlockKind.table.makeBlock(plainText: "A") else {
            return XCTFail("table")
        }
        guard case .toggle = SlashBlockKind.toggle.makeBlock() else {
            return XCTFail("toggle")
        }
        guard case .callout(let kind, _, _) = SlashBlockKind.callout.makeBlock() else {
            return XCTFail("callout")
        }
        XCTAssertEqual(kind, .note)
        guard case .codeBlock(let lang, _) = SlashBlockKind.mermaid.makeBlock() else {
            return XCTFail("mermaid")
        }
        XCTAssertEqual(lang, "mermaid")
    }

    func testEditorSessionRichInsertAndObjectLink() throws {
        let session = EditorSession(blocks: [.paragraph([.text("Deep Work")])])
        session.applyLocalEdit(.insertBlock(at: 1, kind: .table, text: "Col"))
        session.applyLocalEdit(.insertBlock(at: 2, kind: .toggle, text: "More"))
        session.applyLocalEdit(.insertBlock(at: 3, kind: .callout, text: "Note"))
        session.applyLocalEdit(.insertBlock(at: 4, kind: .mermaid, text: "flowchart LR\n  A --> B"))

        let body = session.serializeBody()
        XCTAssertTrue(body.contains("| Col |"))
        XCTAssertTrue(body.contains("<details>"))
        XCTAssertTrue(body.contains("[!note]"))
        XCTAssertTrue(body.contains("```mermaid"))

        let roundTrip = try MarkdownParser().parse(body)
        let again = MarkdownSerializer().serializeBlocks(roundTrip.blocks)
        XCTAssertEqual(
            again.trimmingCharacters(in: .newlines),
            body.trimmingCharacters(in: .newlines)
        )

        let id = ObjectID(uuidString: "cccccccc-2222-4222-8222-cccccccccccc")!
        XCTAssertEqual(session.objectTitleCandidate(at: 0), "Deep Work")
        XCTAssertTrue(session.replaceBlockWithObjectLink(blockIndex: 0, objectID: id, title: "Deep Work"))
        guard case .paragraph(let inlines) = session.blocks[0],
            case .wikiLink(let link) = inlines.first
        else {
            return XCTFail("expected wiki-link paragraph")
        }
        XCTAssertEqual(link.target, id.frontMatterIDString)
        XCTAssertEqual(link.label, "Deep Work")
        XCTAssertTrue(session.serializeBody().contains("[[\(id.frontMatterIDString)|Deep Work]]"))
    }

    func testHTMLRendersRichBlocksAndHighlight() {
        let blocks: [BlockNode] = [
            .table(headers: ["A", "B"], alignments: [.none, .none], rows: [["1", "2"]]),
            .toggle(summary: [.text("Open me")], children: [.paragraph([.text("Hi")])], collapsed: true),
            .callout(kind: .info, title: [.text("Info")], children: [.paragraph([.text("Body")])]),
            .codeBlock(language: "swift", code: "let x = 1"),
            .codeBlock(language: "mermaid", code: "flowchart LR\n  A --> B"),
        ]
        let html = BlockASTHTML.render(blocks)
        XCTAssertTrue(html.contains("data-harness=\"table\""))
        XCTAssertTrue(html.contains("data-harness=\"toggle\""))
        XCTAssertTrue(html.contains("data-harness=\"callout\""))
        XCTAssertTrue(html.contains("data-callout=\"info\""))
        XCTAssertTrue(html.contains("tok-keyword"))
        XCTAssertTrue(html.contains("data-harness=\"mermaid-stub\""))
        XCTAssertTrue(html.contains("data-harness=\"code-highlight\""))
    }

    func testOrdinaryQuoteStillParsesAsBlockQuote() throws {
        let md = "> Just a quote\n> second line\n"
        let doc = try MarkdownParser().parse(md)
        guard case .blockQuote = doc.blocks.first else {
            return XCTFail("expected blockQuote, got \(doc.blocks)")
        }
    }
}
