import Foundation
import LociCore
import LociVault

#if os(macOS)
import SafariServices

/// Safari App Extension (PR38) — Apple-only; Linux builds skip via project.yml excludes.
///
/// JS payload (`SafariClipper.js`) sent via `safari.extension.dispatchMessage`:
/// ```
/// { url: document.URL, title: document.title, selection: window.getSelection().toString() }
/// ```
/// `messageReceived` maps those keys through `SafariClipFactory` →
/// `CaptureInboxWriter.enqueue` (`.loci/inbox/*.json`). Does **not** touch SQLite.
/// Missing vault is a no-op (no crash).
@objc(SafariClipperExtension)
final class SafariClipperExtension: SFSafariExtensionHandler {
    override func messageReceived(
        withName messageName: String,
        from page: SFSafariPage,
        userInfo: [String: Any]?
    ) {
        _ = page
        Task {
            _ = await Self.enqueueFromUserInfo(userInfo, messageName: messageName)
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {
        window.getActiveTab { tab in
            tab?.getActivePage { page in
                page?.dispatchMessageToScript(withName: "extract", userInfo: nil)
            }
        }
    }

    /// Shared helper used by the extension target once vault root is resolved.
    static func enqueueClip(_ clip: SafariClip, vault: any VaultServing) async throws -> String {
        let item = SafariClipFactory.inboxItem(from: clip)
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }

    /// Resolve vault the same way as Share / Widget (`CaptureVaultResolver`).
    static func resolveVault() -> VaultService? {
        CaptureVaultResolver.resolve()
    }

    /// userInfo → SafariClip → inbox. `nil` vault or empty URL is a no-op.
    @discardableResult
    static func enqueueFromUserInfo(
        _ userInfo: [String: Any]?,
        messageName: String = "clip",
        vault: (any VaultServing)? = SafariClipperExtension.resolveVault()
    ) async -> String? {
        guard messageName == "clip" || messageName == "safariClip" || messageName.isEmpty
        else { return nil }
        return await SafariClipInbox.enqueueFromUserInfo(userInfo, vault: vault)
    }
}
#else
/// Linux / non-macOS stub documenting the Safari extension enqueue path (PR38).
enum SafariClipperExtension {
    static func enqueueClip(_ clip: SafariClip, vault: any VaultServing) async throws -> String {
        let item = SafariClipFactory.inboxItem(from: clip)
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }

    /// Same pipeline as the Apple handler — tests never import SafariServices.
    @discardableResult
    static func enqueueFromUserInfo(
        _ userInfo: [String: Any]?,
        messageName: String = "clip",
        vault: (any VaultServing)?
    ) async -> String? {
        guard messageName == "clip" || messageName == "safariClip" || messageName.isEmpty
        else { return nil }
        return await SafariClipInbox.enqueueFromUserInfo(userInfo, vault: vault)
    }
}
#endif
