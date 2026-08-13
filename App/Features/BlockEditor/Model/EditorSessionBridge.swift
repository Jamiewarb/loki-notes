#if canImport(SwiftUI)
import Foundation
import Observation
import LociCore
import LociMarkdown

/// Apple-side bridge: owns `EditorSession` BlockAST + title + debounced `ObjectServing.save`.
///
/// Typing calls `applyLocalEdit` synchronously — never awaits index. Flush runs after idle debounce
/// (500ms) and serializes via `LociMarkdown` before `ObjectServing.save`.
@Observable
@MainActor
final class EditorSessionBridge {
    var title: String
    var relativePath: String
    var objectID: ObjectID
    var lastError: String?
    var isSaving: Bool = false
    var focusedBlockIndex: Int = 0
    var slashQuery: String?
    var linkTrigger: WikiLinkTrigger?
    /// Incomplete `#tag` trigger (PR17).
    var tagTrigger: TagTrigger?
    /// Per-block resolved/broken wiki-link styles (PR16).
    var wikiLinkStylesByBlock: [Int: [WikiLinkStyle]] = [:]
    /// Bumped on each local edit so SwiftUI re-reads block text.
    private(set) var editEpoch: UInt64 = 0

    /// Debounce idle interval before autosave (UI-side).
    var debounceNanoseconds: UInt64 = 500_000_000
    /// Max interval between flushes while continuously typing (5s).
    var maxDirtyNanoseconds: UInt64 = 5_000_000_000

    let editor: EditorSession
    private var meta: LociObjectMeta
    private var saveGeneration: UInt64 = 0
    private var firstDirtyDate: Date?
    private var propertiesDirty = false
    private var tagsDirty = false
    private let objects: any ObjectServing

    var isDirty: Bool { editor.isDirty || title != meta.title || propertiesDirty || tagsDirty }
    var blocks: [BlockNode] { editor.blocks }
    var currentProperties: [String: PropertyValue] { meta.properties }
    var currentTags: [String] { meta.tags }

    init(opened: OpenedObject, objects: any ObjectServing) throws {
        self.objectID = opened.meta.id
        self.relativePath = opened.meta.relativePath
        self.title = opened.meta.title
        self.meta = opened.meta
        self.objects = objects
        self.editor = try EditorSession(
            bodyMarkdown: opened.bodyMarkdown,
            objectID: opened.meta.id,
            relativePath: opened.meta.relativePath
        )
    }

    func applyTitle(_ value: String) {
        title = value
        scheduleSave()
    }

    /// Update frontmatter properties (inspector). Values persist on next flush.
    func applyProperties(_ values: [String: PropertyValue]) {
        meta.properties = values
        propertiesDirty = true
        scheduleSave()
    }

    /// Update object-level frontmatter tags (inspector). Values persist on next flush.
    func applyTags(_ values: [String]) {
        meta.tags = TagNormalization.uniquing(values)
        tagsDirty = true
        scheduleSave()
    }

    func applyEdit(_ edit: BlockEdit) {
        editor.applyLocalEdit(edit)
        editEpoch &+= 1
        noteDirtyClock()
        scheduleSave()
        updateSlashQueryIfNeeded()
        updateLinkTriggerIfNeeded()
        updateTagTriggerIfNeeded()
    }

    func applySlash(kind: SlashBlockKind) {
        editor.applySlashCommand(
            blockIndex: focusedBlockIndex,
            kind: kind,
            queryText: slashQuery ?? ""
        )
        slashQuery = nil
        linkTrigger = nil
        tagTrigger = nil
        editEpoch &+= 1
        noteDirtyClock()
        scheduleSave()
    }

    /// Insert `[[id|title]]` replacing the active `@` / `[[` trigger.
    func insertWikiLink(to meta: LociObjectMeta) {
        let target = meta.id.frontMatterIDString
        let label = meta.title.isEmpty ? nil : meta.title
        _ = editor.insertWikiLink(
            blockIndex: focusedBlockIndex,
            target: target,
            label: label,
            trigger: linkTrigger
        )
        slashQuery = nil
        linkTrigger = nil
        tagTrigger = nil
        editEpoch &+= 1
        noteDirtyClock()
        scheduleSave()
    }

    /// Insert `#tag` replacing the active `#` trigger.
    func insertTag(_ summary: TagSummary) {
        _ = editor.insertTag(
            blockIndex: focusedBlockIndex,
            tag: summary.tag,
            trigger: tagTrigger
        )
        slashQuery = nil
        linkTrigger = nil
        tagTrigger = nil
        editEpoch &+= 1
        noteDirtyClock()
        scheduleSave()
    }

    func plainText(at index: Int) -> String {
        guard editor.blocks.indices.contains(index) else { return "" }
        return EditorSession.plainText(of: editor.blocks[index])
    }

    func setPlainText(at index: Int, text: String) {
        applyEdit(.setPlainText(blockIndex: index, text: text))
        focusedBlockIndex = index
    }

    /// Resolve wiki-links in each block for broken-link styling chips.
    func refreshWikiLinkStyles(using services: AppServices?) async {
        guard let services else {
            wikiLinkStylesByBlock = [:]
            return
        }
        do {
            let index = try await services.ensureIndex()
            var map: [Int: [WikiLinkStyle]] = [:]
            for (i, _) in editor.blocks.enumerated() {
                let plain = plainText(at: i)
                let links = WikiLinkSyntax.extract(from: plain)
                guard !links.isEmpty else { continue }
                var titles: [String: String] = [:]
                for link in links {
                    if let meta = try await index.resolve(wikiTarget: link.target) {
                        titles[link.target] = meta.title
                        titles[link.target.lowercased()] = meta.title
                    }
                }
                map[i] = WikiLinkStyle.classify(links: links, resolvedTitlesByTarget: titles)
            }
            wikiLinkStylesByBlock = map
        } catch {
            wikiLinkStylesByBlock = [:]
        }
    }

    func scheduleSave() {
        saveGeneration &+= 1
        let generation = saveGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard generation == saveGeneration else { return }
            await flushSave()
        }
        if let firstDirtyDate {
            let elapsed = Date().timeIntervalSince(firstDirtyDate)
            if elapsed >= Double(maxDirtyNanoseconds) / 1_000_000_000 {
                Task { @MainActor in
                    await flushSave()
                }
            }
        }
    }

    func flushSave() async {
        guard isDirty else { return }
        isSaving = true
        defer { isSaving = false }
        var next = meta
        next.title = title
        next.updated = Date()
        let body = editor.serializeBody()
        do {
            try await objects.save(meta: next, bodyMarkdown: body)
            meta = next
            editor.markSaved()
            propertiesDirty = false
            tagsDirty = false
            firstDirtyDate = nil
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func proposeRemoteReload(opened: OpenedObject) {
        guard !isDirty else { return }
        meta = opened.meta
        title = opened.meta.title
        relativePath = opened.meta.relativePath
        try? editor.proposeRemoteReload(bodyMarkdown: opened.bodyMarkdown)
        editEpoch &+= 1
    }

    private func noteDirtyClock() {
        if firstDirtyDate == nil {
            firstDirtyDate = Date()
        }
    }

    private func updateSlashQueryIfNeeded() {
        let text = plainText(at: focusedBlockIndex)
        // Slash menu only when `/` leads the block (link / tag triggers take precedence otherwise).
        if text.hasPrefix("/"),
            WikiLinkTriggerDetector.detect(in: text) == nil,
            TagTriggerDetector.detect(in: text) == nil
        {
            slashQuery = String(text.dropFirst())
        } else {
            slashQuery = nil
        }
    }

    private func updateLinkTriggerIfNeeded() {
        let text = plainText(at: focusedBlockIndex)
        if text.hasPrefix("/") {
            linkTrigger = nil
            return
        }
        linkTrigger = WikiLinkTriggerDetector.detect(in: text)
    }

    private func updateTagTriggerIfNeeded() {
        let text = plainText(at: focusedBlockIndex)
        // Prefer wiki-link / slash over tag when both could match.
        if text.hasPrefix("/") || WikiLinkTriggerDetector.detect(in: text) != nil {
            tagTrigger = nil
            return
        }
        tagTrigger = TagTriggerDetector.detect(in: text)
    }
}
#endif
