import Foundation
import LociCore

/// Lenient frontmatter + title extraction for foreign markdown (Obsidian / generic / Capacities).
///
/// Does **not** require Loci `id` / `type` fields — importers synthesize those on write.
public struct LooseFrontMatter: Hashable, Sendable, Equatable {
    public var id: String?
    public var type: String?
    public var title: String?
    public var tags: [String]
    public var aliases: [String]
    public var created: Date?
    public var updated: Date?
    public var properties: [String: String]
    /// Raw YAML map keys for diagnostics.
    public var rawKeys: [String]

    public init(
        id: String? = nil,
        type: String? = nil,
        title: String? = nil,
        tags: [String] = [],
        aliases: [String] = [],
        created: Date? = nil,
        updated: Date? = nil,
        properties: [String: String] = [:],
        rawKeys: [String] = []
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.tags = tags
        self.aliases = aliases
        self.created = created
        self.updated = updated
        self.properties = properties
        self.rawKeys = rawKeys
    }
}

/// Probe a foreign `.md` file into loose frontmatter + body (Linux-testable).
public enum ImportDocumentProbe: Sendable {
    public struct Result: Hashable, Sendable, Equatable {
        public var frontMatter: LooseFrontMatter?
        public var body: String
        public var title: String
        public var wikiLinkTargets: [String]
        public var markdownImageRefs: [String]
        public var obsidianEmbeds: [String]

        public init(
            frontMatter: LooseFrontMatter?,
            body: String,
            title: String,
            wikiLinkTargets: [String],
            markdownImageRefs: [String],
            obsidianEmbeds: [String]
        ) {
            self.frontMatter = frontMatter
            self.body = body
            self.title = title
            self.wikiLinkTargets = wikiLinkTargets
            self.markdownImageRefs = markdownImageRefs
            self.obsidianEmbeds = obsidianEmbeds
        }
    }

    public static func probe(markdown: String, fallbackTitle: String) -> Result {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let (yaml, body) = splitLooseFrontMatter(normalized)
        let matter = yaml.flatMap { parseLoose($0) }
        let title = resolveTitle(
            matter: matter,
            body: body,
            fallback: fallbackTitle
        )
        let wiki = WikiLinkSyntax.extract(from: body).map(\.target)
        let images = extractMarkdownImageRefs(from: body)
        let embeds = extractObsidianEmbeds(from: body)
        return Result(
            frontMatter: matter,
            body: body,
            title: title,
            wikiLinkTargets: wiki,
            markdownImageRefs: images,
            obsidianEmbeds: embeds
        )
    }

    /// Split `---` fences without requiring valid Loci frontmatter.
    public static func splitLooseFrontMatter(_ text: String) -> (String?, String) {
        let trimmedStart = text.drop(while: { $0 == "\n" })
        guard trimmedStart.hasPrefix("---\n") || trimmedStart.hasPrefix("---\r\n") else {
            return (nil, text)
        }
        let afterOpen = trimmedStart.hasPrefix("---\n")
            ? trimmedStart.dropFirst(4)
            : trimmedStart.dropFirst(5)
        if let closeRange = afterOpen.range(of: "\n---") {
            let yaml = String(afterOpen[..<closeRange.lowerBound])
            var rest = afterOpen[closeRange.upperBound...]
            if rest.hasPrefix("\n") { rest = rest.dropFirst() }
            return (yaml, String(rest))
        }
        // Unclosed fence — treat entire file as body.
        return (nil, text)
    }

    public static func parseLoose(_ yaml: String) -> LooseFrontMatter? {
        let map: [String: SimpleYAML.Value]
        do {
            map = try SimpleYAML.parseMap(yaml)
        } catch {
            return nil
        }
        let id = stringValue(map["id"]) ?? stringValue(map["uuid"])
        let type = stringValue(map["type"]) ?? stringValue(map["typeID"])
            ?? stringValue(map["objectType"])
        let title = stringValue(map["title"]) ?? stringValue(map["name"])
        var tags: [String] = []
        if let tagsValue = map["tags"] {
            tags = stringArray(tagsValue)
        }
        var aliases: [String] = []
        if let aliasesValue = map["aliases"] {
            aliases = stringArray(aliasesValue)
        }
        let created = dateValue(map["created"]) ?? dateValue(map["created_at"])
        let updated = dateValue(map["updated"]) ?? dateValue(map["updated_at"])
            ?? dateValue(map["modified"])

        var properties: [String: String] = [:]
        let reserved: Set<String> = [
            "id", "uuid", "type", "typeID", "objectType", "title", "name", "tags", "aliases",
            "created", "created_at", "updated", "updated_at", "modified", "template", "properties",
        ]
        if let props = map["properties"], case .map(let nested) = props {
            for (k, v) in nested {
                if let s = stringValue(v) { properties[k] = s }
            }
        }
        for (k, v) in map where !reserved.contains(k) {
            if let s = stringValue(v) { properties[k] = s }
        }

        return LooseFrontMatter(
            id: id,
            type: type,
            title: title,
            tags: tags,
            aliases: aliases,
            created: created,
            updated: updated,
            properties: properties,
            rawKeys: Array(map.keys).sorted()
        )
    }

    private static func resolveTitle(
        matter: LooseFrontMatter?,
        body: String,
        fallback: String
    ) -> String {
        if let t = matter?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let h = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if !h.isEmpty { return String(h) }
            }
            if !trimmed.isEmpty { break }
        }
        let stem = (fallback as NSString).deletingPathExtension
        return stem.isEmpty ? "Untitled" : stem
    }

    private static func extractMarkdownImageRefs(from body: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)"#)
        else { return [] }
        let ns = body as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: body, range: range).compactMap { match -> String? in
            guard match.numberOfRanges >= 2,
                let r = Range(match.range(at: 1), in: body)
            else { return nil }
            return String(body[r])
        }
    }

    /// Obsidian embeds: `![[file.png]]` / `![[Note]]`.
    private static func extractObsidianEmbeds(from body: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"!\[\[([^\]|]+)(?:\|[^\]]+)?\]\]"#)
        else { return [] }
        let ns = body as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: body, range: range).compactMap { match -> String? in
            guard match.numberOfRanges >= 2,
                let r = Range(match.range(at: 1), in: body)
            else { return nil }
            return String(body[r]).trimmingCharacters(in: .whitespaces)
        }
    }

    private static func stringValue(_ value: SimpleYAML.Value?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let s): return s
        case .number(let n):
            if n.rounded() == n { return String(Int(n)) }
            return String(n)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    private static func stringArray(_ value: SimpleYAML.Value) -> [String] {
        switch value {
        case .array(let items):
            return items.compactMap { stringValue($0) }
        case .string(let s):
            // Obsidian sometimes uses "a, b" or "#a #b"
            if s.contains(",") {
                return s.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                }.filter { !$0.isEmpty }
            }
            return [s.trimmingCharacters(in: CharacterSet(charactersIn: "#"))]
        default:
            return []
        }
    }

    private static func dateValue(_ value: SimpleYAML.Value?) -> Date? {
        guard let s = stringValue(value) else { return nil }
        if let d = FrontMatterDates.parse(s) { return d }
        // Obsidian often uses `YYYY-MM-DD` or `YYYY-MM-DD HH:mm`.
        let dayOnly = DateFormatter()
        dayOnly.calendar = Calendar(identifier: .gregorian)
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dayOnly.dateFormat = "yyyy-MM-dd"
        if let d = dayOnly.date(from: String(s.prefix(10))) { return d }
        return nil
    }
}

/// Convert Obsidian `![[file.png]]` embeds into markdown images when the target looks like media.
public enum ObsidianEmbedRewriter: Sendable {
    public static func rewriteEmbedsToMarkdownImages(_ body: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"!\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#)
        else { return body }
        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var result = body
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                let targetRange = Range(match.range(at: 1), in: result)
            else { continue }
            let target = String(result[targetRange]).trimmingCharacters(in: .whitespaces)
            let ext = (target as NSString).pathExtension.lowercased()
            let mediaExts: Set<String> = [
                "png", "jpg", "jpeg", "gif", "webp", "svg", "pdf", "mp3", "mp4", "mov",
            ]
            guard mediaExts.contains(ext) else { continue }
            var alt = (target as NSString).deletingPathExtension
            if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
                let labelRange = Range(match.range(at: 2), in: result)
            {
                alt = String(result[labelRange])
            }
            let replacement = "![\(alt)](\(target))"
            if let full = Range(match.range(at: 0), in: result) {
                result.replaceSubrange(full, with: replacement)
            }
        }
        return result
    }
}
