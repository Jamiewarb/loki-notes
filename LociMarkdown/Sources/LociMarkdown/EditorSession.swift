import Foundation
import LociCore

/// In-memory single-writer session for an open object's BlockAST (PLAN 13.5 / PR09).
///
/// - Owns dirty state and revision tokens.
/// - `applyLocalEdit` never awaits vault or index — typing stays local.
/// - Persist via `serializeBody()` → `ObjectServing.save` (debounced by the UI host).
/// - `proposeRemoteReload` never auto-clobbers when dirty.
public final class EditorSession: @unchecked Sendable {
    public private(set) var objectID: ObjectID?
    public private(set) var relativePath: String?
    public private(set) var blocks: [BlockNode]
    public private(set) var isDirty: Bool
    public private(set) var revisionToken: UInt64

    public init(
        blocks: [BlockNode] = [.paragraph([])],
        objectID: ObjectID? = nil,
        relativePath: String? = nil,
        revisionToken: UInt64 = 0,
        isDirty: Bool = false
    ) {
        self.blocks = blocks.isEmpty ? [.paragraph([])] : blocks
        self.objectID = objectID
        self.relativePath = relativePath
        self.revisionToken = revisionToken
        self.isDirty = isDirty
    }

    /// Parse body markdown into blocks (no frontmatter expected in body).
    public convenience init(
        bodyMarkdown: String,
        objectID: ObjectID? = nil,
        relativePath: String? = nil
    ) throws {
        let doc = try MarkdownParser().parse(bodyMarkdown)
        self.init(
            blocks: doc.blocks,
            objectID: objectID,
            relativePath: relativePath,
            revisionToken: 0,
            isDirty: false
        )
    }

    // MARK: - Mutations

    public func applyLocalEdit(_ edit: BlockEdit) {
        switch edit {
        case .setPlainText(let index, let text):
            guard blocks.indices.contains(index) else { return }
            blocks[index] = Self.withPlainText(blocks[index], text: text)
            markDirty()
        case .convertBlock(let index, let kind):
            guard blocks.indices.contains(index) else { return }
            let plain = Self.plainText(of: blocks[index])
            blocks[index] = kind.makeBlock(plainText: plain)
            markDirty()
        case .insertBlock(let index, let kind, let text):
            let clamped = min(max(index, 0), blocks.count)
            blocks.insert(kind.makeBlock(plainText: text), at: clamped)
            markDirty()
        case .deleteBlock(let index):
            guard blocks.indices.contains(index) else { return }
            blocks.remove(at: index)
            if blocks.isEmpty {
                blocks = [.paragraph([])]
            }
            markDirty()
        case .splitBlock(let index, let before, let after):
            guard blocks.indices.contains(index) else { return }
            blocks[index] = Self.withPlainText(blocks[index], text: before)
            let insertAt = index + 1
            blocks.insert(SlashBlockKind.paragraph.makeBlock(plainText: after), at: insertAt)
            markDirty()
        case .toggleTask(let blockIndex, let itemIndex):
            guard blocks.indices.contains(blockIndex) else { return }
            switch blocks[blockIndex] {
            case .bulletList(var items):
                guard items.indices.contains(itemIndex), let checked = items[itemIndex].checked
                else { return }
                items[itemIndex].checked = !checked
                blocks[blockIndex] = .bulletList(items)
                markDirty()
            default:
                return
            }
        case .pasteMarkdown(let index, let markdown):
            let parsed: [BlockNode]
            do {
                let doc = try MarkdownParser().parse(markdown)
                parsed = doc.blocks
            } catch {
                parsed = [.paragraph([.text(markdown)])]
            }
            guard !parsed.isEmpty else { return }
            let clamped = min(max(index, 0), blocks.count)
            blocks.insert(contentsOf: parsed, at: clamped)
            markDirty()
        case .replaceBlocks(let next):
            blocks = next.isEmpty ? [.paragraph([])] : next
            markDirty()
        }
    }

    /// Apply a slash command: if the current block is only `/query`, convert it; else insert below.
    public func applySlashCommand(
        blockIndex: Int,
        kind: SlashBlockKind,
        queryText: String
    ) {
        guard blocks.indices.contains(blockIndex) else { return }
        let plain = Self.plainText(of: blocks[blockIndex])
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/") {
            // Convert in place; drop the slash query text.
            blocks[blockIndex] = kind.makeBlock(plainText: "")
            markDirty()
        } else {
            applyLocalEdit(.insertBlock(at: blockIndex + 1, kind: kind, text: ""))
            _ = queryText
        }
    }

    /// Replace an `@` / `[[` trigger in the focused block with a serialized wiki-link.
    /// Prefer ObjectID as `target` (LinkResolver identity-first).
    @discardableResult
    public func insertWikiLink(
        blockIndex: Int,
        target: String,
        label: String? = nil,
        trigger: WikiLinkTrigger? = nil
    ) -> Bool {
        guard blocks.indices.contains(blockIndex) else { return false }
        let plain = Self.plainText(of: blocks[blockIndex])
        let resolvedTrigger = trigger ?? WikiLinkTriggerDetector.detect(in: plain)
        let link = WikiLink(target: target, label: label)
        let markdown = link.markdown

        let next: String
        if let resolvedTrigger {
            let start = plain.index(plain.startIndex, offsetBy: resolvedTrigger.replaceStartOffset)
            let prefix = String(plain[..<start])
            next = prefix + markdown
        } else if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next = markdown
        } else {
            next = plain + markdown
        }

        applyLocalEdit(.setPlainText(blockIndex: blockIndex, text: next))
        return true
    }

    /// Replace an incomplete `#…` trigger with a completed `#tag` (trailing space for continued typing).
    @discardableResult
    public func insertTag(
        blockIndex: Int,
        tag: String,
        trigger: TagTrigger? = nil,
        trailingSpace: Bool = true
    ) -> Bool {
        guard blocks.indices.contains(blockIndex) else { return false }
        let plain = Self.plainText(of: blocks[blockIndex])
        let resolvedTrigger = trigger ?? TagTriggerDetector.detect(in: plain)
        let markdown = TagSyntax.markdown(tag) + (trailingSpace ? " " : "")

        let next: String
        if let resolvedTrigger {
            let start = plain.index(plain.startIndex, offsetBy: resolvedTrigger.replaceStartOffset)
            let prefix = String(plain[..<start])
            next = prefix + markdown
        } else if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next = markdown
        } else {
            next = plain + markdown
        }

        applyLocalEdit(.setPlainText(blockIndex: blockIndex, text: next))
        return true
    }

    public func markSaved(revision: UInt64? = nil) {
        isDirty = false
        if let revision {
            revisionToken = revision
        } else {
            revisionToken &+= 1
        }
    }

    /// Propose reloading from vault bytes. Returns `false` (and does nothing) when dirty.
    @discardableResult
    public func proposeRemoteReload(bodyMarkdown: String) throws -> Bool {
        guard !isDirty else { return false }
        let doc = try MarkdownParser().parse(bodyMarkdown)
        blocks = doc.blocks.isEmpty ? [.paragraph([])] : doc.blocks
        revisionToken &+= 1
        return true
    }

    public func serializeBody() -> String {
        MarkdownSerializer().serializeBlocks(blocks)
    }

    // MARK: - Plain text helpers

    public static func plainText(of block: BlockNode) -> String {
        let serializer = MarkdownSerializer()
        switch block {
        case .paragraph(let inlines), .heading(_, let inlines):
            return serializer.serializeInlines(inlines)
        case .bulletList(let items), .numberedList(_, let items):
            guard let first = items.first else { return "" }
            return serializer.serializeInlines(first.inlines)
        case .blockQuote(let children):
            guard let first = children.first else { return "" }
            return plainText(of: first)
        case .codeBlock(_, let code):
            return code
        case .image(let alt, _, _):
            return alt
        case .thematicBreak:
            return ""
        }
    }

    public static func withPlainText(_ block: BlockNode, text: String) -> BlockNode {
        let inlines: [InlineNode] = text.isEmpty ? [] : [.text(text)]
        switch block {
        case .paragraph:
            return .paragraph(inlines)
        case .heading(let level, _):
            return .heading(level: level, inlines: inlines)
        case .bulletList(let items):
            var next = items
            if next.isEmpty {
                next = [ListItem(inlines: inlines)]
            } else {
                let checked = next[0].checked
                next[0] = ListItem(checked: checked, inlines: inlines)
            }
            return .bulletList(next)
        case .numberedList(let start, let items):
            var next = items
            if next.isEmpty {
                next = [ListItem(inlines: inlines)]
            } else {
                let checked = next[0].checked
                next[0] = ListItem(checked: checked, inlines: inlines)
            }
            return .numberedList(start: start, items: next)
        case .blockQuote:
            return .blockQuote([.paragraph(inlines)])
        case .codeBlock(let language, _):
            return .codeBlock(language: language, code: text)
        case .image(_, let url, let title):
            return .image(alt: text, url: url, title: title)
        case .thematicBreak:
            return .thematicBreak
        }
    }

    private func markDirty() {
        isDirty = true
    }
}
