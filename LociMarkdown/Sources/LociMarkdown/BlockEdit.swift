import Foundation

/// Slash-menu / insertable block kinds for the MVP editor (PR09).
public enum SlashBlockKind: String, Sendable, Hashable, CaseIterable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case heading4
    case bulletList
    case numberedList
    case taskList
    case quote
    case code

    public var title: String {
        switch self {
        case .paragraph: return "Paragraph"
        case .heading1: return "Heading 1"
        case .heading2: return "Heading 2"
        case .heading3: return "Heading 3"
        case .heading4: return "Heading 4"
        case .bulletList: return "Bullet list"
        case .numberedList: return "Numbered list"
        case .taskList: return "Task list"
        case .quote: return "Quote"
        case .code: return "Code"
        }
    }

    public var slashToken: String {
        switch self {
        case .paragraph: return "paragraph"
        case .heading1: return "h1"
        case .heading2: return "h2"
        case .heading3: return "h3"
        case .heading4: return "h4"
        case .bulletList: return "bullet"
        case .numberedList: return "number"
        case .taskList: return "task"
        case .quote: return "quote"
        case .code: return "code"
        }
    }

    /// Match slash query (case-insensitive prefix on title or token).
    public func matches(query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return true }
        return title.lowercased().hasPrefix(q) || slashToken.hasPrefix(q)
    }

    /// Build an empty-ish starter block for insertion / conversion.
    public func makeBlock(plainText: String = "") -> BlockNode {
        let inlines: [InlineNode] = plainText.isEmpty ? [] : [.text(plainText)]
        switch self {
        case .paragraph:
            return .paragraph(inlines)
        case .heading1:
            return .heading(level: 1, inlines: inlines)
        case .heading2:
            return .heading(level: 2, inlines: inlines)
        case .heading3:
            return .heading(level: 3, inlines: inlines)
        case .heading4:
            return .heading(level: 4, inlines: inlines)
        case .bulletList:
            return .bulletList([ListItem(inlines: inlines.isEmpty ? [.text("")] : inlines)])
        case .numberedList:
            return .numberedList(
                start: 1,
                items: [ListItem(inlines: inlines.isEmpty ? [.text("")] : inlines)]
            )
        case .taskList:
            return .bulletList([
                ListItem(checked: false, inlines: inlines.isEmpty ? [.text("")] : inlines)
            ])
        case .quote:
            return .blockQuote([.paragraph(inlines)])
        case .code:
            return .codeBlock(language: nil, code: plainText)
        }
    }
}

/// Local edits applied to an `EditorSession` BlockAST. Never touches vault or index.
public enum BlockEdit: Sendable, Equatable {
    /// Replace the plain-text content of a block (paragraph / heading / list first item / code / quote).
    case setPlainText(blockIndex: Int, text: String)
    /// Convert the block at index to a slash kind, preserving plain text when possible.
    case convertBlock(blockIndex: Int, to: SlashBlockKind)
    /// Insert a new block before `index` (or append if index == count).
    case insertBlock(at: Int, kind: SlashBlockKind, text: String)
    /// Remove a block (keeps at least one empty paragraph).
    case deleteBlock(at: Int)
    /// Enter/split: leave `before` in place, insert `after` as a new paragraph below.
    case splitBlock(blockIndex: Int, before: String, after: String)
    /// Toggle a task checkbox when the block is a task list.
    case toggleTask(blockIndex: Int, itemIndex: Int)
    /// Paste markdown at/after index — parsed into blocks and inserted.
    case pasteMarkdown(at: Int, markdown: String)
    /// Replace the entire document body AST.
    case replaceBlocks([BlockNode])
}
