import Foundation

/// Pure HTML → Open Graph preview. XCTest feeds fixture strings — no network.
///
/// Reads `og:title`, `og:description`, `og:image`; falls back to `<title>`.
public enum OpenGraphHTMLParser: Sendable {
    public static func parse(_ html: String, sourceURL: URL) -> LinkPreview {
        let ogTitle = metaContent(html, keys: ["og:title"])
        let ogDescription = metaContent(html, keys: ["og:description"])
        let ogImage = metaContent(html, keys: ["og:image"])
        let title = ogTitle ?? htmlTitle(html)
        let imageURL = resolveImage(ogImage, against: sourceURL)
        return LinkPreview(
            title: title,
            description: ogDescription,
            imageURL: imageURL,
            sourceURL: sourceURL
        )
    }

    // MARK: - Meta

    /// First matching `<meta>` `content` for `property` or `name` in `keys`.
    public static func metaContent(_ html: String, keys: [String]) -> String? {
        let wanted = Set(keys.map { $0.lowercased() })
        for tag in metaTags(in: html) {
            let property = (tag["property"] ?? tag["name"] ?? "").lowercased()
            guard wanted.contains(property) else { continue }
            if let content = tag["content"] {
                let decoded = decodeEntities(content)
                if !decoded.isEmpty { return decoded }
            }
        }
        return nil
    }

    public static func htmlTitle(_ html: String) -> String? {
        guard let range = html.range(of: "<title", options: [.caseInsensitive]) else {
            return nil
        }
        let after = html[range.upperBound...]
        guard let close = after.range(of: ">") else { return nil }
        let inner = after[close.upperBound...]
        guard let end = inner.range(of: "</title>", options: [.caseInsensitive]) else {
            return nil
        }
        let raw = String(inner[..<end.lowerBound])
        let decoded = decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return decoded.isEmpty ? nil : decoded
    }

    // MARK: - Tag scan

    static func metaTags(in html: String) -> [[String: String]] {
        var tags: [[String: String]] = []
        var search = html.startIndex
        let haystack = html
        while search < haystack.endIndex {
            guard let start = haystack[search...].range(of: "<meta", options: [.caseInsensitive])
            else { break }
            let afterName = start.upperBound
            guard let end = haystack[afterName...].range(of: ">") else { break }
            let inner = String(haystack[afterName..<end.lowerBound])
            tags.append(parseAttributes(inner))
            search = end.upperBound
        }
        return tags
    }

    /// Parse `key="value"` / `key='value'` attribute pairs (order-independent).
    static func parseAttributes(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:]*)\s*=\s*(?:"([^"]*)"|'([^']*)')"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let ns = raw as NSString
        let matches = regex.matches(in: raw, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            guard match.numberOfRanges >= 4 else { continue }
            let key = ns.substring(with: match.range(at: 1)).lowercased()
            let doubleQ = match.range(at: 2)
            let singleQ = match.range(at: 3)
            let valueRange = doubleQ.location != NSNotFound ? doubleQ : singleQ
            guard valueRange.location != NSNotFound else { continue }
            result[key] = ns.substring(with: valueRange)
        }
        return result
    }

    static func resolveImage(_ raw: String?, against sourceURL: URL) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }
        return URL(string: raw, relativeTo: sourceURL)?.absoluteURL
    }

    public static func decodeEntities(_ raw: String) -> String {
        var s = raw
        let named: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
        ]
        for (entity, replacement) in named {
            s = s.replacingOccurrences(of: entity, with: replacement)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
