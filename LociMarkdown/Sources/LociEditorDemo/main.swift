import Foundation
import LociCore
import LociMarkdown

/// CLI: EditorSession slash-insert simulation + BlockAST HTML for DevHarness (PR09 + PR29).
@main
struct LociEditorDemo {
    static func main() throws {
        let fixture = """
            ## Editor rich

            Paragraph before slash inserts.

            - [ ] Capture tasks
            - [x] Land PR08

            1. First step
            2. Second step

            > Quotes survive round-trip

            ```swift
            let session = EditorSession()
            ```
            """

        let session = try EditorSession(bodyMarkdown: fixture)
        // Simulate slash menu: convert trailing empty paragraph / insert blocks.
        session.applyLocalEdit(.insertBlock(at: session.blocks.count, kind: .heading3, text: "Slash inserts"))
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .taskList, text: "Debounced save")
        )
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .bulletList, text: "Bullet from /bullet")
        )
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .code, text: "let x = 1 // highlight")
        )
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .table, text: "Title")
        )
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .toggle, text: "Details")
        )
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .callout, text: "Heads up")
        )
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .mermaid, text: "")
        )

        // Block → object conversion (wiki-link only; ObjectServing.create happens in UI host).
        session.applyLocalEdit(
            .insertBlock(at: session.blocks.count, kind: .paragraph, text: "Deep Work")
        )
        let bookIndex = session.blocks.count - 1
        let bookTitle = session.objectTitleCandidate(at: bookIndex)
        let fakeBookID = ObjectID(uuidString: "bbbbbbbb-1111-4111-8111-bbbbbbbbbbbb")!
        _ = session.replaceBlockWithObjectLink(
            blockIndex: bookIndex,
            objectID: fakeBookID,
            title: bookTitle
        )

        let serialized = session.serializeBody()
        let roundTrip = try MarkdownParser().parse(serialized)
        let stable =
            MarkdownSerializer().serializeBlocks(roundTrip.blocks)
            .trimmingCharacters(in: .newlines)
            == serialized.trimmingCharacters(in: .newlines)

        let html = BlockASTHTML.render(session.blocks)
        let blockSummary = session.blocks.map(describeBlock)

        let richKinds = ["table", "toggle", "callout", "mermaid", "codeHighlight"]
        let payload: [String: Any] = [
            "moduleVersion": LociMarkdownModule.version,
            "editorSession": "PR29",
            "blockCount": session.blocks.count,
            "blocks": blockSummary,
            "serialized": serialized,
            "html": html,
            "roundTripStable": stable,
            "isDirty": session.isDirty,
            "slashSimulated": [
                "h3", "task", "bullet", "code", "table", "toggle", "callout", "mermaid",
            ],
            "richBlocks": richKinds,
            "blockToObject": [
                "title": bookTitle,
                "typeID": "book",
                "wikiLink": WikiLink(
                    target: fakeBookID.frontMatterIDString,
                    label: bookTitle
                ).markdown,
            ],
            "note":
                "EditorSession owns BlockAST; serialize via LociMarkdown; typing never awaits index. PR29: tables/toggles/callouts + block→object wiki-link.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func describeBlock(_ block: BlockNode) -> String {
        switch block {
        case .paragraph: return "paragraph"
        case .heading(let level, _): return "heading(\(level))"
        case .bulletList(let items):
            let tasks = items.filter(\.isTask).count
            return tasks > 0 ? "bulletList(tasks:\(tasks))" : "bulletList(\(items.count))"
        case .numberedList(_, let items): return "numberedList(\(items.count))"
        case .blockQuote: return "blockQuote"
        case .codeBlock(let lang, _): return "codeBlock(\(lang ?? "-"))"
        case .queryEmbed(let id): return "queryEmbed(\(id))"
        case .table(let headers, _, let rows):
            return "table(\(headers.count)x\(rows.count))"
        case .toggle: return "toggle"
        case .callout(let kind, _, _): return "callout(\(kind.rawValue))"
        case .image: return "image"
        case .thematicBreak: return "thematicBreak"
        }
    }
}
