import Foundation

/// Where a Safari clip should land (PR32).
public enum SafariClipDestination: String, Sendable, Hashable, Codable, Equatable {
    /// Append a formatted line to today’s daily note.
    case appendToToday
    /// Create a Weblink object under `objects/weblink/`.
    case weblinkObject
}

/// Payload from the Safari App Extension (or harness) before inbox / clip apply.
public struct SafariClip: Hashable, Sendable, Codable, Equatable {
    public var pageURL: String
    public var pageTitle: String?
    public var selection: String
    public var destination: SafariClipDestination

    public init(
        pageURL: String,
        pageTitle: String? = nil,
        selection: String,
        destination: SafariClipDestination
    ) {
        self.pageURL = pageURL
        self.pageTitle = pageTitle
        self.selection = selection
        self.destination = destination
    }
}

/// Pure helpers mapping Safari clips → Capture inbox / Weblink body + properties.
public enum SafariClipFactory: Sendable {
    /// Map a clip to a staging `CaptureInboxItem` (extension path — vault JSON only).
    public static func inboxItem(from clip: SafariClip) -> CaptureInboxItem {
        let url = clip.pageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = clip.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let selection = clip.selection.trimmingCharacters(in: .whitespacesAndNewlines)
        switch clip.destination {
        case .appendToToday:
            let text = selection.isEmpty ? (title ?? url) : selection
            return CaptureInboxItem.appendLine(text, source: .safari, sourceURL: url)
        case .weblinkObject:
            let body = weblinkBody(selection: selection, url: url)
            let resolvedTitle: String? = {
                if let title, !title.isEmpty { return title }
                return CaptureLineFormatter.inferredTitle(
                    from: selection.isEmpty ? url : selection,
                    fallback: "Weblink"
                )
            }()
            return CaptureInboxItem.createTyped(
                typeID: .weblink,
                title: resolvedTitle,
                text: body,
                source: .safari,
                sourceURL: url
            )
        }
    }

    /// Markdown body for a Weblink object — quoted selection + source URL.
    public static func weblinkBody(selection: String, url: String) -> String {
        let trimmedSel = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if !trimmedSel.isEmpty {
            let quoted = trimmedSel
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line -> String in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    return t.isEmpty ? ">" : "> \(t)"
                }
                .joined(separator: "\n")
            parts.append(quoted)
        }
        if !trimmedURL.isEmpty {
            parts.append("Source: \(trimmedURL)")
        }
        if parts.isEmpty { return "" }
        return parts.joined(separator: "\n\n") + "\n"
    }

    /// Frontmatter properties for a Weblink (`url` required; `clipped-from` = page title).
    public static func weblinkProperties(
        url: String,
        pageTitle: String?
    ) -> [String: PropertyValue] {
        var props: [String: PropertyValue] = [:]
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedURL.isEmpty {
            props["url"] = .url(trimmedURL)
        }
        if let title = pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            props["clipped-from"] = .text(title)
        }
        return props
    }
}
