import Foundation
import LociCore
import LociVault

#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

/// iOS Share extension entry (PR26) — Apple-only; Linux builds skip this file via project.yml.
///
/// Writes staging JSON under `.loci/inbox/` via `CaptureInboxWriter`. The main app drains
/// on foreground into today’s daily or a typed object. Does **not** touch SQLite.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Stub: real share sheet extracts text/URL then calls CaptureInboxWriter.enqueue.
        // Full NSExtension plumbing lives in the Xcode Share target (see Info.plist).
    }

    /// Shared helper used by the extension target once vault root is resolved.
    static func enqueueSharedText(
        _ text: String,
        sourceURL: String?,
        vault: any VaultServing,
        asObject: Bool
    ) async throws -> String {
        let item: CaptureInboxItem
        if asObject {
            item = .createTyped(
                typeID: .page,
                title: nil,
                text: text,
                source: .share,
                sourceURL: sourceURL
            )
        } else {
            item = .appendLine(text, source: .share, sourceURL: sourceURL)
        }
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }
}
#endif
