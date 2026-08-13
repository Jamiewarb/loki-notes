import Foundation
import LociCore

/// Concrete `SafariClipServing` — Safari clips via Capture inbox / ObjectServing (PR32).
///
/// Extensions call `enqueue` (vault inbox JSON only). The main app calls `drain` /
/// `clip` so daily / Weblink writes go through CaptureServing + ObjectServing and
/// the local index updates asynchronously.
public final class SafariClipService: SafariClipServing, @unchecked Sendable {
    private let vault: any VaultServing
    private let capture: any CaptureServing
    private let objects: any ObjectServing

    public init(
        vault: any VaultServing,
        capture: any CaptureServing,
        objects: any ObjectServing
    ) {
        self.vault = vault
        self.capture = capture
        self.objects = objects
    }

    // MARK: - SafariClipServing

    @discardableResult
    public func enqueue(_ clip: SafariClip) async throws -> String {
        let item = SafariClipFactory.inboxItem(from: clip)
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }

    @discardableResult
    public func drain(calendar: Calendar = .current) async throws -> [CaptureResult] {
        try await capture.drainInbox(calendar: calendar)
    }

    @discardableResult
    public func clip(
        _ clip: SafariClip,
        calendar: Calendar = .current
    ) async throws -> CaptureResult {
        switch clip.destination {
        case .appendToToday:
            let item = SafariClipFactory.inboxItem(from: clip)
            return try await capture.appendToToday(
                item.text,
                sourceURL: item.sourceURL,
                source: .safari,
                calendar: calendar
            )
        case .weblinkObject:
            return try await createWeblink(from: clip)
        }
    }

    // MARK: - Internals

    private func createWeblink(from clip: SafariClip) async throws -> CaptureResult {
        let url = clip.pageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String = {
            if let t = clip.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                return t
            }
            let sel = clip.selection.trimmingCharacters(in: .whitespacesAndNewlines)
            return CaptureLineFormatter.inferredTitle(
                from: sel.isEmpty ? url : sel,
                fallback: "Weblink"
            )
        }()
        var meta = try await objects.create(typeID: .weblink, title: title)
        for (key, value) in SafariClipFactory.weblinkProperties(
            url: url,
            pageTitle: clip.pageTitle
        ) {
            meta.properties[key] = value
        }
        meta.updated = Date()
        let body = SafariClipFactory.weblinkBody(selection: clip.selection, url: url)
        try await objects.save(meta: meta, bodyMarkdown: body)
        return CaptureResult(
            kind: .createObject,
            objectID: meta.id,
            relativePath: meta.relativePath,
            inboxRelativePath: nil,
            appendedLine: nil
        )
    }
}
