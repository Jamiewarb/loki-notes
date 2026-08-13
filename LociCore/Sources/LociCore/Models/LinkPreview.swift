import Foundation

/// Open Graph / HTML preview metadata for a Weblink URL (PR43).
///
/// Cached under Application Support next to the index — **never** written into
/// vault markdown/YAML (derived OG data must not churn iCloud).
public struct LinkPreview: Hashable, Sendable, Equatable, Codable {
    public var title: String?
    public var description: String?
    public var imageURL: URL?
    public var sourceURL: URL

    public init(
        title: String? = nil,
        description: String? = nil,
        imageURL: URL? = nil,
        sourceURL: URL
    ) {
        self.title = Self.trimmed(title)
        self.description = Self.trimmed(description)
        self.imageURL = imageURL
        self.sourceURL = sourceURL
    }

    public var hasContent: Bool {
        title != nil || description != nil || imageURL != nil
    }

    /// Empty placeholder shown when fetch/parse fails — never crashes the UI.
    public static func placeholder(sourceURL: URL) -> LinkPreview {
        LinkPreview(sourceURL: sourceURL)
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

/// Extract a http(s) URL from a weblink object's `url` property.
public enum WeblinkURL: Sendable {
    public static func from(_ meta: LociObjectMeta) -> URL? {
        guard meta.typeID == .weblink else { return nil }
        guard case .url(let raw) = meta.properties["url"] else { return nil }
        return parseHTTP(raw)
    }

    public static func parseHTTP(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        guard scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}

/// Shared HTML fixtures for XCTest / FakeLinkPreviewFetcher / demos (no live network).
public enum OpenGraphFixtures: Sendable {
    public static let articleURLString = "https://example.com/article"
    public static let weblinkURLString = "https://example.com/weblink"

    public static var articleURL: URL { URL(string: articleURLString)! }
    public static var weblinkURL: URL { URL(string: weblinkURLString)! }

    public static let articleHTML = """
        <!doctype html>
        <html>
        <head>
          <title>Fallback Title</title>
          <meta property="og:title" content="Example Article">
          <meta property="og:description" content="A clipped paragraph from the page.">
          <meta property="og:image" content="https://example.com/og.png">
        </head>
        <body><p>Body is ignored.</p></body>
        </html>
        """

    public static let titleOnlyHTML = """
        <html><head><title>Just a Title</title></head><body></body></html>
        """

    public static let reversedMetaHTML = """
        <html><head>
        <meta content="Reversed Title" property="og:title">
        <meta content="Reversed description." name="og:description">
        <meta content="/images/card.png" property="og:image">
        </head></html>
        """

    public static let entitiesHTML = """
        <html><head>
        <meta property="og:title" content="Hello &amp; World">
        <meta property="og:description" content="A &quot;quoted&quot; line">
        </head></html>
        """
}
