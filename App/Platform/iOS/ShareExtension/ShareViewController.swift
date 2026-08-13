import Foundation
import LociCore
import LociVault

#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

/// iOS Share extension (PR37) — Apple-only; Linux builds skip this file via project.yml.
///
/// Extracts `public.plain-text` / `public.url` from `NSExtensionItem`, maps via
/// `ShareInboxFactory`, writes `.loci/inbox/*.json` with `CaptureInboxWriter`.
/// Does **not** touch SQLite. Vault resolve matches the main app (ubiquity, then
/// local Documents). Missing vault shows a short error — never crashes.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureStatusLabel()
        setStatus("Saving to Loci…", isError: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await extractAndEnqueue() }
    }

    /// Shared helper used by the extension target once vault root is resolved.
    static func enqueueShared(
        text: String?,
        sourceURL: String?,
        vault: any VaultServing
    ) async throws -> String {
        let item = ShareInboxFactory.inboxItem(text: text, url: sourceURL, source: .share)
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }

    /// Resolve vault the same way as `AppServices` / `CaptureVaultResolver`.
    static func resolveVault() -> VaultService? {
        CaptureVaultResolver.resolve()
    }

    // MARK: - Pipeline

    private func extractAndEnqueue() async {
        let extracted = await extractShareItems()
        let item = ShareInboxFactory.inboxItem(
            text: extracted.text,
            url: extracted.url,
            source: .share
        )

        guard let vault = Self.resolveVault() else {
            showError(
                "Loci vault is unavailable. Open the Loci app once to create a local vault."
            )
            return
        }

        do {
            _ = try await CaptureInboxWriter.enqueue(item, vault: vault)
            setStatus("Saved to Loci inbox.", isError: false)
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            showError("Could not save share.")
        }
    }

    /// UIKit extraction — stays in this file (no UIKit types in LociCore).
    func extractShareItems() async -> (text: String?, url: String?) {
        var text: String?
        var urlString: String?
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return (nil, nil)
        }
        for item in items {
            if text == nil, let attributed = item.attributedContentText?.string {
                let trimmed = attributed.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { text = trimmed }
            }
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if urlString == nil,
                    provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                {
                    urlString = await loadURL(from: provider)
                }
                if text == nil,
                    provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
                {
                    text = await loadPlainText(from: provider)
                }
            }
        }
        return (text, urlString)
    }

    private func loadURL(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) {
                item,
                _ in
                if let url = item as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url.absoluteString)
                } else if let string = item as? String, ShareInboxFactory.looksLikeWebURL(string) {
                    continuation.resume(returning: string.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadPlainText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) {
                item,
                _ in
                if let string = item as? String {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: trimmed.isEmpty ? nil : trimmed)
                } else if let data = item as? Data, let string = String(data: data, encoding: .utf8)
                {
                    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: trimmed.isEmpty ? nil : trimmed)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Status UI

    private func configureStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .label
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .label
    }

    private func showError(_ message: String) {
        setStatus(message, isError: true)
    }
}
#endif
