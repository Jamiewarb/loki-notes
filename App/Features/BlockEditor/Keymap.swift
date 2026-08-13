#if canImport(SwiftUI)
import SwiftUI
import LociMarkdown

/// macOS keyboard shortcuts for block conversion (PR09).
struct BlockEditorKeymapModifier: ViewModifier {
    var session: EditorSessionBridge

    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .background {
                Group {
                    Button("") { convert(.heading1) }
                        .keyboardShortcut("1", modifiers: [.command, .option])
                    Button("") { convert(.heading2) }
                        .keyboardShortcut("2", modifiers: [.command, .option])
                    Button("") { convert(.heading3) }
                        .keyboardShortcut("3", modifiers: [.command, .option])
                    Button("") { convert(.bulletList) }
                        .keyboardShortcut("8", modifiers: [.command, .shift])
                    Button("") { convert(.numberedList) }
                        .keyboardShortcut("7", modifiers: [.command, .shift])
                    Button("") { convert(.taskList) }
                        .keyboardShortcut("t", modifiers: [.command, .shift])
                    Button("") { convert(.quote) }
                        .keyboardShortcut("'", modifiers: [.command, .shift])
                    Button("") { convert(.code) }
                        .keyboardShortcut("c", modifiers: [.command, .option])
                }
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
            }
            #endif
    }

    private func convert(_ kind: SlashBlockKind) {
        session.applyEdit(.convertBlock(blockIndex: session.focusedBlockIndex, to: kind))
    }
}
#endif

/// Documented shortcut map (Linux-readable; used by harness notes / help).
enum BlockEditorKeymap {
    static let shortcuts: [(label: String, keys: String, kind: String)] = [
        ("Heading 1", "⌘⌥1", "heading1"),
        ("Heading 2", "⌘⌥2", "heading2"),
        ("Heading 3", "⌘⌥3", "heading3"),
        ("Bullet list", "⌘⇧8", "bulletList"),
        ("Numbered list", "⌘⇧7", "numberedList"),
        ("Task list", "⌘⇧T", "taskList"),
        ("Quote", "⌘⇧'", "quote"),
        ("Code", "⌘⌥C", "code"),
    ]
}
