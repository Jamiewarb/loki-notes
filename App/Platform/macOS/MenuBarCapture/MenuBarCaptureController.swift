import Foundation
import LociCore

#if os(macOS)
import AppKit
import SwiftUI

/// macOS menu bar quick capture stub (PR26).
///
/// Status-item UI calls `CaptureServing.appendToToday` (or enqueue when vault-only).
/// Full `NSStatusItem` wiring is Apple-only; Linux keeps this as a source stub.
@MainActor
final class MenuBarCaptureController: NSObject {
    private var statusItem: NSStatusItem?
    private let onCapture: (String) -> Void

    init(onCapture: @escaping (String) -> Void = { _ in }) {
        self.onCapture = onCapture
    }

    func install() {
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
        // Stub: present a small text field; production wires CaptureServing.appendToToday.
        onCapture("")
    }

    @objc private func openToday() {
        // Stub: deep-link / Navigating.open daily via AppServices.ensureTodayDailyNote.
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
}
#else
/// Non-macOS stub documenting the menu bar surface.
public enum MenuBarCaptureStub {
    public static let actions = ["quickCapture", "openToday"]
}
#endif
