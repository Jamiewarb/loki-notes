import Foundation
import LociCore
import LociVault

#if os(macOS)
import SafariServices

/// Safari App Extension stub (PR32) — Apple-only; Linux builds skip via project.yml excludes.
///
/// Documents `SFSafariExtensionHandler` entry. Writes staging JSON under `.loci/inbox/`
/// via `CaptureInboxWriter` / `SafariClipFactory`. Does **not** touch SQLite.
@objc(SafariClipperExtension)
final class SafariClipperExtension: SFSafariExtensionHandler {
    override func messageReceived(
        withName messageName: String,
        from page: SFSafariPage,
        userInfo: [String: Any]?
    ) {
        // Stub: real extension extracts selection/URL from the page then calls enqueueClip.
        _ = messageName
        _ = page
        _ = userInfo
    }

    /// Shared helper used by the extension target once vault root is resolved.
    static func enqueueClip(_ clip: SafariClip, vault: any VaultServing) async throws -> String {
        let item = SafariClipFactory.inboxItem(from: clip)
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }
}
#else
/// Linux / non-macOS stub documenting the Safari extension enqueue path (PR32).
enum SafariClipperExtension {
    static func enqueueClip(_ clip: SafariClip, vault: any VaultServing) async throws -> String {
        let item = SafariClipFactory.inboxItem(from: clip)
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }
}
#endif
