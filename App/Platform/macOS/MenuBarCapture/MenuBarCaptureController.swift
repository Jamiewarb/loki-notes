import Foundation
import LociCore

#if os(macOS)
import AppKit
import LociVault

/// macOS menu bar quick capture (PR38).
///
/// Status-item UI: Quick capture → `CaptureServing.appendToToday` when the main
/// app stack is ready, otherwise `CaptureInboxWriter` enqueue (vault-only).
/// Open today → `Navigating` / `loci://daily/today`. Linux keeps the stub enum.
@MainActor
final class MenuBarCaptureController: NSObject {
    private var statusItem: NSStatusItem?
    private var captureProvider: (() -> (any CaptureServing)?)?
    private var vaultProvider: (() -> (any VaultServing)?)?
    private var openTodayHandler: (() -> Void)?
    private let onCapture: (String) -> Void

    init(onCapture: @escaping (String) -> Void = { _ in }) {
        self.onCapture = onCapture
    }

    /// Install the status item once. Call from `LociApp` launch (`#if os(macOS)`).
    func install(
        capture: @escaping () -> (any CaptureServing)? = { nil },
        vault: @escaping () -> (any VaultServing)? = { nil },
        onOpenToday: @escaping () -> Void = {
            NSWorkspace.shared.open(LociDeepLink.dailyTodayURL)
        }
    ) {
        captureProvider = capture
        vaultProvider = vault
        openTodayHandler = onOpenToday
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Loci"
        item.button?.toolTip = "Loci quick capture"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quick capture…",
            action: #selector(quickCapture),
            keyEquivalent: "n"
        ))
        menu.addItem(NSMenuItem(
            title: "Open today",
            action: #selector(openToday),
            keyEquivalent: "t"
        ))
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func quickCapture() {
        guard let text = promptForCapture() else { return }
        onCapture(text)
        Task { await Self.captureLine(text, capture: captureProvider?(), vault: vaultProvider?()) }
    }

    @objc private func openToday() {
        if let openTodayHandler {
            openTodayHandler()
        } else {
            NSWorkspace.shared.open(LociDeepLink.dailyTodayURL)
        }
    }

    /// Shared capture helper: append when `CaptureServing` is ready; else inbox.
    @discardableResult
    static func captureLine(
        _ text: String,
        capture: (any CaptureServing)?,
        vault: (any VaultServing)?,
        calendar: Calendar = .current
    ) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch MenuBarCaptureFactory.route(hasCapture: capture != nil, hasVault: vault != nil) {
        case .appendToToday:
            guard let capture else { return nil }
            return try? await appendLine(trimmed, capture: capture, calendar: calendar)
                .relativePath
        case .enqueueInbox:
            guard let vault else { return nil }
            let item = MenuBarCaptureFactory.inboxItem(text: trimmed)
            return try? await CaptureInboxWriter.enqueue(item, vault: vault)
        case .unavailable:
            return nil
        }
    }

    /// Shared capture helper for menu bar → vault (callable from App composition).
    static func appendLine(
        _ text: String,
        capture: any CaptureServing,
        calendar: Calendar = .current
    ) async throws -> CaptureResult {
        try await capture.appendToToday(
            text,
            sourceURL: nil,
            source: .menuBar,
            calendar: calendar
        )
    }

    private func promptForCapture() -> String? {
        let alert = NSAlert()
        alert.messageText = "Quick capture"
        alert.informativeText = "Add a line to today’s daily note."
        alert.addButton(withTitle: "Capture")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "Note…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
#else
/// Non-macOS stub documenting the menu bar surface.
public enum MenuBarCaptureStub {
    public static let actions = ["quickCapture", "openToday"]
    public static let openTodayURL = LociDeepLink.dailyTodayAbsoluteString
}
#endif
