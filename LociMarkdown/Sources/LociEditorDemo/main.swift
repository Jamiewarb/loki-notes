import Foundation
import LociMarkdown

/// CLI: EditorSession slash-insert simulation + BlockAST HTML for DevHarness (PR09).
@main
struct LociEditorDemo {
    static func main() throws {
        let fixture = """
            ## Editor MVP

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
            .insertBlock(at: session.blocks.count, kind: .code, text: "print(\"slash\")")
        )

        let serialized = session.serializeBody()
        let roundTrip = try MarkdownParser().parse(serialized)
        let stable =
            MarkdownSerializer().serializeBlocks(roundTrip.blocks)
            .trimmingCharacters(in: .newlines)
            == serialized.trimmingCharacters(in: .newlines)

        let html = BlockASTHTML.render(session.blocks)
        let blockSummary = session.blocks.map(describeBlock)

        let payload: [String: Any] = [
            "moduleVersion": LociMarkdownModule.version,
            "editorSession": "PR09",
            "blockCount": session.blocks.count,
            "blocks": blockSummary,
            "serialized": serialized,
            "html": html,
            "roundTripStable": stable,
            "isDirty": session.isDirty,
            "slashSimulated": ["h3", "task", "bullet", "code"],
            "note":
                "EditorSession owns BlockAST; serialize via LociMarkdown; typing never awaits index.",
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
        case .image: return "image"
        case .thematicBreak: return "thematicBreak"
        }
    }
}
