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
///
/// Safari App Extension JS payload (`messageReceived` `userInfo` keys — no SafariServices):
/// ```
/// safari.extension.dispatchMessage("clip", {
///   url: document.URL,
///   title: document.title,
///   selection: window.getSelection().toString(),
///   destination: "appendToToday" | "weblinkObject"   // optional
/// });
/// ```
public enum SafariClipFactory: Sendable {
    public static let userInfoURLKey = "url"
    public static let userInfoTitleKey = "title"
    public static let userInfoSelectionKey = "selection"
    public static let userInfoDestinationKey = "destination"

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

    /// Map Safari `userInfo` (`url` / `title` / `selection`) → `SafariClip`.
    ///
    /// Accepts `[String: Any]` so the extension can pass `SFSafariPage` userInfo
    /// without importing SafariServices here. Missing keys become empty strings;
    /// `destination` defaults to `.appendToToday`.
    public static func clip(fromUserInfo userInfo: [String: Any]?) -> SafariClip {
        let url = stringValue(userInfo, key: userInfoURLKey) ?? ""
        let title = stringValue(userInfo, key: userInfoTitleKey)
        let selection = stringValue(userInfo, key: userInfoSelectionKey) ?? ""
        let destRaw = stringValue(userInfo, key: userInfoDestinationKey)
        let destination = destRaw.flatMap(SafariClipDestination.init(rawValue:)) ?? .appendToToday
        let resolvedTitle: String? = {
            guard let title else { return nil }
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        return SafariClip(
            pageURL: url,
            pageTitle: resolvedTitle,
            selection: selection,
            destination: destination
        )
    }

    /// Map Safari `userInfo` → staging inbox item (same `.loci/inbox/` as Share).
    public static func inboxItem(fromUserInfo userInfo: [String: Any]?) -> CaptureInboxItem {
        inboxItem(from: clip(fromUserInfo: userInfo))
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

    /// Coerce a userInfo value to a trimmed string (`String`, `URL`, or description).
    public static func stringValue(_ userInfo: [String: Any]?, key: String) -> String? {
        guard let raw = userInfo?[key] else { return nil }
        let text: String
        if let string = raw as? String {
            text = string
        } else if let url = raw as? URL {
            text = url.absoluteString
        } else {
            text = String(describing: raw)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
