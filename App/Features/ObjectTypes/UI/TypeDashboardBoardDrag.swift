import SwiftUI
import LociCore
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Optional Apple-only drag payload for a kanban card. Linux / a11y use “Move to …”.
struct KanbanCardDragModifier: ViewModifier {
    let objectID: ObjectID

    func body(content: Content) -> some View {
        #if os(iOS) || os(macOS)
        content.onDrag {
            NSItemProvider(object: objectID.frontMatterIDString as NSString)
        }
        #else
        content
        #endif
    }
}

/// Optional Apple-only drop target for a kanban column.
struct KanbanColumnDropModifier: ViewModifier {
    let destinationKey: String
    let isBusy: Bool
    var onMove: (ObjectID, String) async -> Void

    func body(content: Content) -> some View {
        #if (os(iOS) || os(macOS)) && canImport(UniformTypeIdentifiers)
        content.onDrop(of: [.text, .utf8PlainText], isTargeted: nil) { providers in
            guard !isBusy, let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let ns = object as? NSString else { return }
                let raw = ns.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let id = ObjectID(parsing: raw) else { return }
                Task { await onMove(id, destinationKey) }
            }
            return true
        }
        #else
        content
        #endif
    }
}
