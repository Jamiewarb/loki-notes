import Foundation

/// Pure mapping from Share-sheet (text, url) → `CaptureInboxItem` (PR37).
///
/// No UIKit. The iOS Share extension extracts `public.plain-text` / `public.url`
/// then calls this factory and `CaptureInboxWriter.enqueue`. Extensions never
/// touch the SQLite index.
public enum ShareInboxFactory: Sendable {
    /// Map extracted share payload to a staging inbox item.
    ///
    /// - Text only (no URL): append a line to today’s daily note.
    /// - URL present (optional title/text): create a typed Page.
    /// - Plain text that is itself an `http(s)` URL is treated as a URL share.
    public static func inboxItem(
        text: String?,
        url: String?,
        source: CaptureSource = .share
    ) -> CaptureInboxItem {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let explicitURL = url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let resolvedURL: String = {
            if !explicitURL.isEmpty { return explicitURL }
            if looksLikeWebURL(trimmedText) { return trimmedText }
            return ""
        }()
        let resolvedText: String = {
            if explicitURL.isEmpty, looksLikeWebURL(trimmedText) { return "" }
            return trimmedText
        }()

        if !resolvedURL.isEmpty {
            let title: String? = {
                if !resolvedText.isEmpty {
                    return CaptureLineFormatter.inferredTitle(from: resolvedText)
                }
                return CaptureLineFormatter.inferredTitle(from: resolvedURL, fallback: "Shared link")
            }()
            return CaptureInboxItem.createTyped(
                typeID: .page,
                title: title,
                text: resolvedText.isEmpty ? resolvedURL : resolvedText,
                source: source,
                sourceURL: resolvedURL
            )
        }

        return CaptureInboxItem.appendLine(resolvedText, source: source, sourceURL: nil)
    }

    /// Whether `text` is a single `http` / `https` URL (host required).
    public static func looksLikeWebURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace) else { return false }
        guard let parsed = URL(string: trimmed), let scheme = parsed.scheme?.lowercased()
        else { return false }
        return (scheme == "http" || scheme == "https") && parsed.host != nil
    }
}
