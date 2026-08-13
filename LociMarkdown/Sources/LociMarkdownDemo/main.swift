import Foundation
import LociMarkdown

/// Tiny CLI: round-trip a sample fixture and print JSON for DevHarness (PR06).
@main
struct LociMarkdownDemo {
    static func main() throws {
        let sample = """
            ---
            id: 8f3c2a1e-1111-4111-8111-000000000001
            type: page
            title: Hello Loci
            created: 2026-08-13T09:12:00Z
            updated: 2026-08-13T11:40:00Z
            tags: [welcome, demo]
            ---

            ## Notes

            This is a simple page with a [[8f3c2a1e-2222-4222-8222-000000000002|related note]] and a #focus tag.
            """

        let doc = try LociMarkdownModule.parse(sample)
        let output = LociMarkdownModule.serialize(doc)
        let blockSummary = doc.blocks.map(describeBlock)

        var fm: [String: Any] = [:]
        if let matter = doc.frontMatter {
            fm = [
                "id": matter.id.uuidString.lowercased(),
                "type": matter.typeID.rawValue,
                "title": matter.title,
                "tags": matter.tags,
            ]
        }

        let payload: [String: Any] = [
            "moduleVersion": LociMarkdownModule.version,
            "yamlChoice": "hand-rolled SimpleYAML (no SPM YAML dependency)",
            "input": sample,
            "output": output,
            "frontMatter": fm,
            "blocks": blockSummary,
            "roundTripStable": (try LociMarkdownModule.roundTrip(output)) == output,
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
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
