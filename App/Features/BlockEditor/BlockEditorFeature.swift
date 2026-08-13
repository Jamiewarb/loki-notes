#if canImport(SwiftUI)
import SwiftUI
import LociMarkdown

/// Public entry for BlockEditor feature (PR09). Composition hosts via ObjectEditor.
enum BlockEditorFeature {
    @MainActor
    static func editor(session: EditorSessionBridge) -> some View {
        BlockEditorView(session: session)
    }
}
#endif
