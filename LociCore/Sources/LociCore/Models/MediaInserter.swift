import Foundation

/// Insert markdown image syntax into note bodies (PR20).
/// Pure string helpers — no I/O; vault copy happens via `MediaServing`.
public enum MediaInserter: Sendable {
    /// Single markdown image line for an attachment relative to an object path.
    public static func markdownLine(
        alt: String,
        attachment: MediaAttachment,
        fromObjectRelativePath objectPath: String,
        title: String? = nil
    ) -> String {
        MediaPath.markdownImage(
            alt: alt,
            mediaRelativePath: attachment.relativePath,
            fromObjectRelativePath: objectPath,
            title: title
        )
    }

    /// Append an image block (blank line + `![…](…)`) to body markdown.
    public static func appendImage(
        to bodyMarkdown: String,
        alt: String,
        attachment: MediaAttachment,
        fromObjectRelativePath objectPath: String
    ) -> String {
        let line = markdownLine(
            alt: alt,
            attachment: attachment,
            fromObjectRelativePath: objectPath
        )
        let trimmed = bodyMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return line + "\n" }
        if trimmed.hasSuffix("\n") {
            return trimmed + "\n" + line + "\n"
        }
        return trimmed + "\n\n" + line + "\n"
    }

    /// Replace body with a single image embed (used when creating Image objects).
    public static func imageOnlyBody(
        alt: String,
        attachment: MediaAttachment,
        fromObjectRelativePath objectPath: String
    ) -> String {
        markdownLine(
            alt: alt,
            attachment: attachment,
            fromObjectRelativePath: objectPath
        ) + "\n"
    }
}
