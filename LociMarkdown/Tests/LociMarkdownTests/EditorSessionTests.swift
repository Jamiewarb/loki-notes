import XCTest
import LociCore
@testable import LociMarkdown

final class EditorSessionTests: XCTestCase {
    func testApplyEditsAndSerializeRoundTrip() throws {
        let session = EditorSession(blocks: [.paragraph([.text("Hello")])])
        XCTAssertFalse(session.isDirty)

        session.applyLocalEdit(.setPlainText(blockIndex: 0, text: "Hello world"))
        XCTAssertTrue(session.isDirty)
        XCTAssertEqual(EditorSession.plainText(of: session.blocks[0]), "Hello world")

        session.applyLocalEdit(.convertBlock(blockIndex: 0, to: .heading2))
        guard case .heading(let level, _) = session.blocks[0] else {
            return XCTFail("expected heading")
        }
        XCTAssertEqual(level, 2)

        session.applyLocalEdit(.insertBlock(at: 1, kind: .bulletList, text: "Item A"))
        session.applyLocalEdit(.insertBlock(at: 2, kind: .taskList, text: "Ship PR09"))
        session.applyLocalEdit(.insertBlock(at: 3, kind: .quote, text: "Quoted"))
        session.applyLocalEdit(.insertBlock(at: 4, kind: .code, text: "let x = 1"))

        let body = session.serializeBody()
        XCTAssertTrue(body.contains("## Hello world"))
        XCTAssertTrue(body.contains("- Item A"))
        XCTAssertTrue(body.contains("- [ ] Ship PR09"))
        XCTAssertTrue(body.contains("> Quoted"))
        XCTAssertTrue(body.contains("```\nlet x = 1\n```"))

        let roundTrip = try MarkdownParser().parse(body)
        let again = MarkdownSerializer().serializeBlocks(roundTrip.blocks)
        XCTAssertEqual(again.trimmingCharacters(in: .newlines), body.trimmingCharacters(in: .newlines))

        session.markSaved()
        XCTAssertFalse(session.isDirty)
        XCTAssertEqual(session.revisionToken, 1)
    }

    func testSplitAndSlashConvert() {
        let session = EditorSession(blocks: [.paragraph([.text("alpha")])])
        session.applyLocalEdit(.splitBlock(blockIndex: 0, before: "alpha", after: "beta"))
        XCTAssertEqual(session.blocks.count, 2)
        XCTAssertEqual(EditorSession.plainText(of: session.blocks[0]), "alpha")
        XCTAssertEqual(EditorSession.plainText(of: session.blocks[1]), "beta")

        session.applyLocalEdit(.setPlainText(blockIndex: 1, text: "/h2"))
        session.applySlashCommand(blockIndex: 1, kind: .heading2, queryText: "h2")
        guard case .heading(let level, let inlines) = session.blocks[1] else {
            return XCTFail("slash should convert to heading")
        }
        XCTAssertEqual(level, 2)
        XCTAssertTrue(inlines.isEmpty)
    }

    func testToggleTaskAndPasteMarkdown() throws {
        let session = EditorSession(blocks: [
            SlashBlockKind.taskList.makeBlock(plainText: "Write tests")
        ])
        session.applyLocalEdit(.toggleTask(blockIndex: 0, itemIndex: 0))
        guard case .bulletList(let items) = session.blocks[0], let checked = items.first?.checked
        else {
            return XCTFail("expected task")
        }
        XCTAssertTrue(checked)

        session.applyLocalEdit(
            .pasteMarkdown(at: 1, markdown: "### Pasted\n\n- one\n- two\n")
        )
        XCTAssertGreaterThanOrEqual(session.blocks.count, 3)

        let body = session.serializeBody()
        let reloaded = try EditorSession(bodyMarkdown: body)
        XCTAssertEqual(reloaded.serializeBody().trimmingCharacters(in: .newlines),
                       body.trimmingCharacters(in: .newlines))
    }

    func testProposeRemoteReloadRespectsDirty() throws {
        let session = try EditorSession(bodyMarkdown: "Original\n")
        session.applyLocalEdit(.setPlainText(blockIndex: 0, text: "Local edit"))
        let rejected = try session.proposeRemoteReload(bodyMarkdown: "Remote\n")
        XCTAssertFalse(rejected)
        XCTAssertEqual(EditorSession.plainText(of: session.blocks[0]), "Local edit")

        session.markSaved()
        let accepted = try session.proposeRemoteReload(bodyMarkdown: "## Remote\n")
        XCTAssertTrue(accepted)
        guard case .heading = session.blocks[0] else {
            return XCTFail("reload should parse heading")
        }
    }

    func testSlashKindFiltering() {
        let hits = SlashBlockKind.allCases.filter { $0.matches(query: "ta") }
        XCTAssertTrue(hits.contains(.taskList))
        XCTAssertFalse(hits.contains(.quote))
    }

    func testHTMLRenderIncludesTasksAndHeadings() {
        let blocks: [BlockNode] = [
            .heading(level: 2, inlines: [.text("Notes")]),
            .bulletList([
                ListItem(checked: false, inlines: [.text("Open task")]),
                ListItem(checked: true, inlines: [.text("Done task")]),
            ]),
            .numberedList(start: 1, items: [ListItem(inlines: [.text("First")])]),
            .blockQuote([.paragraph([.text("Quote me")])]),
        ]
        let html = BlockASTHTML.render(blocks)
        XCTAssertTrue(html.contains("<h2>Notes</h2>"))
        XCTAssertTrue(html.contains("data-task=\"open\""))
        XCTAssertTrue(html.contains("data-task=\"done\""))
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<blockquote>"))
    }
}
