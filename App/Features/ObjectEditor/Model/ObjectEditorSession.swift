import Foundation
import Observation
import LociCore

/// In-memory working copy for the ObjectEditor (PR08 stub; full BlockAST session is PR09).
///
/// ## Debounced save design
/// - Editor owns `isDirty` / title / body; keystrokes never await vault or index.
/// - `scheduleSave` starts a debounce (default 500ms idle). A max-interval flush (5s)
///   can be added in PR09 alongside BlockEditor.
/// - When the timer fires, call `ObjectServing.save` once; index updates run async
///   inside ObjectService after the vault write.
/// - PR08: debounce is wired; the flush currently saves immediately when the timer
///   fires (service save is synchronous w.r.t. vault I/O, not per-keystroke).
@Observable
@MainActor
final class ObjectEditorSession {
    var objectID: ObjectID
    var relativePath: String
    var title: String
    var bodyMarkdown: String
    var isDirty: Bool = false
    var lastError: String?
    var isSaving: Bool = false

    /// Debounce idle interval before autosave (UI-side).
    var debounceNanoseconds: UInt64 = 500_000_000

    private var meta: LociObjectMeta
    private var saveGeneration: UInt64 = 0
    private let objects: any ObjectServing

    init(opened: OpenedObject, objects: any ObjectServing) {
        self.objectID = opened.meta.id
        self.relativePath = opened.meta.relativePath
        self.title = opened.meta.title
        self.bodyMarkdown = opened.bodyMarkdown
        self.meta = opened.meta
        self.objects = objects
    }

    func applyTitle(_ value: String) {
        title = value
        isDirty = true
        scheduleSave()
    }

    func applyBody(_ value: String) {
        bodyMarkdown = value
        isDirty = true
        scheduleSave()
    }

    /// Debounce: cancel prior pending save, wait, then flush.
    func scheduleSave() {
        saveGeneration &+= 1
        let generation = saveGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard generation == saveGeneration else { return }
            await flushSave()
        }
    }

    /// Immediate save (toolbar / navigation leave).
    func flushSave() async {
        guard isDirty else { return }
        isSaving = true
        defer { isSaving = false }
        var next = meta
        next.title = title
        next.updated = Date()
        do {
            try await objects.save(meta: next, bodyMarkdown: bodyMarkdown)
            meta = next
            meta.title = title
            isDirty = false
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func proposeRemoteReload(opened: OpenedObject) {
        guard !isDirty else { return }
        meta = opened.meta
        title = opened.meta.title
        bodyMarkdown = opened.bodyMarkdown
        relativePath = opened.meta.relativePath
    }
}
