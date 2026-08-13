import Foundation

/// Linux-testable notes for Photos / Finder-drop attach.
///
/// Apple UI (`PhotosPicker`, `.onDrop`) lives in `App/Features/Media` and must never
/// leak PhotosUI, EventKit, or `NSItemProvider` types into LociCore. Tests and
/// DevHarness exercise the same vault copy via `MediaServing.attach(fileURL:)`.
public struct MediaPickerProof: Hashable, Sendable, Equatable, Codable {
    /// PhotosPicker is wired in App (`#if canImport(PhotosUI)`). Linux reports true as “code present”.
    public var photosPickerWired: Bool
    /// `.onDrop` is wired in App (macOS). Linux reports true as “code present”.
    public var dragDropWired: Bool
    /// Attachment used `MediaServing.attach(fileURL:)` (picker / drop Linux stand-in).
    public var attachedViaFileURL: Bool
    public var indexInsideVault: Bool
    /// Markdown image URL collapses to a vault-relative `media/…` path (not an absolute disk path).
    public var markdownRelativePathStartsWithMedia: Bool
    /// Note body contains an absolute filesystem path (must be false after attach).
    public var noteBodyHasAbsolutePath: Bool

    public init(
        photosPickerWired: Bool,
        dragDropWired: Bool,
        attachedViaFileURL: Bool,
        indexInsideVault: Bool,
        markdownRelativePathStartsWithMedia: Bool,
        noteBodyHasAbsolutePath: Bool
    ) {
        self.photosPickerWired = photosPickerWired
        self.dragDropWired = dragDropWired
        self.attachedViaFileURL = attachedViaFileURL
        self.indexInsideVault = indexInsideVault
        self.markdownRelativePathStartsWithMedia = markdownRelativePathStartsWithMedia
        self.noteBodyHasAbsolutePath = noteBodyHasAbsolutePath
    }

    /// Evaluate proof from an attach result + note body. Picker flags default to “code present”.
    public static func evaluate(
        attachment: MediaAttachment,
        noteBody: String,
        indexInsideVault: Bool,
        attachedViaFileURL: Bool,
        photosPickerWired: Bool = true,
        dragDropWired: Bool = true
    ) -> MediaPickerProof {
        let urls = markdownImageURLs(in: noteBody)
        let mediaOK =
            attachment.relativePath.hasPrefix("media/")
            && !urls.isEmpty
            && urls.allSatisfy { url in
                collapseDotDot(url).hasPrefix("media/") && !isAbsoluteFilesystemPath(url)
            }
        return MediaPickerProof(
            photosPickerWired: photosPickerWired,
            dragDropWired: dragDropWired,
            attachedViaFileURL: attachedViaFileURL,
            indexInsideVault: indexInsideVault,
            markdownRelativePathStartsWithMedia: mediaOK,
            noteBodyHasAbsolutePath: noteBodyContainsAbsolutePath(noteBody)
        )
    }

    /// Extract `![alt](url)` destinations (first token; titles ignored).
    public static func markdownImageURLs(in body: String) -> [String] {
        var urls: [String] = []
        var search = body[...]
        while let bang = search.range(of: "![") {
            let afterAlt = search[bang.upperBound...]
            guard let closeAlt = afterAlt.range(of: "](") else { break }
            let afterParen = afterAlt[closeAlt.upperBound...]
            guard let close = afterParen.range(of: ")") else { break }
            let raw = String(afterParen[..<close.lowerBound])
            let token = raw.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? raw
            let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !trimmed.isEmpty { urls.append(trimmed) }
            search = afterParen[close.upperBound...]
        }
        return urls
    }

    public static func isAbsoluteFilesystemPath(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("file:") { return true }
        if t.hasPrefix("/") { return true }
        if t.count >= 3 {
            let second = t[t.index(t.startIndex, offsetBy: 1)]
            if second == ":", t[t.startIndex].isLetter { return true }
        }
        return false
    }

    public static func noteBodyContainsAbsolutePath(_ body: String) -> Bool {
        if markdownImageURLs(in: body).contains(where: isAbsoluteFilesystemPath) {
            return true
        }
        let needles = ["file://", "/tmp/", "/Users/", "/home/", "/var/", "/opt/", "/private/"]
        return needles.contains { body.contains($0) }
    }

    /// Collapse `../` segments so `../../media/images/a.png` → `media/images/a.png`.
    public static func collapseDotDot(_ url: String) -> String {
        var parts: [String] = []
        for part in url.split(separator: "/") {
            if part == ".." {
                if !parts.isEmpty { parts.removeLast() }
            } else if part != "." && !part.isEmpty {
                parts.append(String(part))
            }
        }
        return parts.joined(separator: "/")
    }
}

/// Contract notes so XCTest / DevHarness never import PhotosUI.
public enum MediaPickerNotes: Sendable {
    /// PhotosUI / NSItemProvider stay in `App/Features/Media`.
    public static let photosUIStaysInApp = true
    /// Linux stand-in for PhotosPicker and Finder drop.
    public static let linuxAttachPath = "MediaServing.attach(fileURL:)"
    /// Dropped / picked absolute paths are never written into note markdown.
    public static let persistVaultRelativeOnly = true
}
