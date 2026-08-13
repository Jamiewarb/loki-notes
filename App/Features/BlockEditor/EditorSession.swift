import LociMarkdown

/// PR09: BlockAST session implementation lives in `LociMarkdown.EditorSession`
/// so apply-edit + serialize round-trips are Linux-testable without SwiftUI.
///
/// Apple UI hosts the session through `EditorSessionBridge` (debounce + ObjectServing).
typealias BlockEditorSession = EditorSession
