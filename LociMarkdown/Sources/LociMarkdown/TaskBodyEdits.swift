import Foundation

/// Toggle GFM task checkboxes in body markdown (PR19).
///
/// Used by the Tasks aggregation UI when the user checks a box outside the block editor.
/// Persistence still goes through `ObjectServing.save` — never writes the index directly.
public enum TaskBodyEdits: Sendable {
    /// Flip `checked` on the task at `(blockIndex, itemIndex)`. Throws if the block is not a task.
    public static func toggle(
        bodyMarkdown: String,
        blockIndex: Int,
        itemIndex: Int
    ) throws -> String {
        let parser = MarkdownParser()
        let doc = try parser.parse(bodyMarkdown)
        var blocks = doc.blocks
        guard blocks.indices.contains(blockIndex) else {
            throw TaskBodyEditError.blockOutOfRange
        }
        switch blocks[blockIndex] {
        case .bulletList(var items):
            guard items.indices.contains(itemIndex), items[itemIndex].checked != nil else {
                throw TaskBodyEditError.notATask
            }
            items[itemIndex].checked = !(items[itemIndex].checked ?? false)
            blocks[blockIndex] = .bulletList(items)
        default:
            throw TaskBodyEditError.notATask
        }
        // Body-only serialize (no frontmatter) — caller merges with meta on save.
        return MarkdownSerializer().serializeBlocks(blocks)
    }
}

public enum TaskBodyEditError: Error, Sendable, Equatable {
    case blockOutOfRange
    case notATask
}
