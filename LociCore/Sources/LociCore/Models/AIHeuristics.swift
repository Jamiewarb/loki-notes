import Foundation

/// Deterministic on-device AI heuristics (PR30). Pure — no I/O, no network.
public enum AIHeuristics: Sendable {
    public static func run(_ request: AIRequest, settings: AISettings) -> AIProposal {
        switch request.action {
        case .summarize:
            return summarize(request)
        case .rewrite:
            return rewrite(request)
        case .translate:
            let lang = (request.targetLanguage ?? settings.targetLanguage)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return translate(request, language: lang.isEmpty ? "es" : lang)
        case .autofillProperties:
            return autofillProperties(request)
        }
    }

    // MARK: - Summarize

    public static func summarize(_ request: AIRequest) -> AIProposal {
        let sentences = nonEmptySentences(from: request.bodyMarkdown)
        let taken = Array(sentences.prefix(2))
        var parts: [String] = []
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { parts.append(title) }
        parts.append(contentsOf: taken)
        let summary = "Summary: " + (parts.isEmpty ? "(empty)" : parts.joined(separator: " · "))
        let count = taken.count
        let note = "\(count) sentence\(count == 1 ? "" : "s")"
        return AIProposal(
            action: .summarize,
            objectID: request.objectID,
            provider: .onDeviceHeuristics,
            summary: summary,
            notes: [note],
            uploaded: false
        )
    }

    // MARK: - Rewrite / tighten

    public static func rewrite(_ request: AIRequest) -> AIProposal {
        var text = request.bodyMarkdown
        // Collapse 3+ newlines to 2.
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            String(line).replacingOccurrences(
                of: #"[ \t]+$"#,
                with: "",
                options: .regularExpression
            )
        }
        text = lines.joined(separator: "\n")
        text = stripFillers(text)
        if !text.hasSuffix("\n") { text += "\n" }
        return AIProposal(
            action: .rewrite,
            objectID: request.objectID,
            provider: .onDeviceHeuristics,
            proposedBody: text,
            notes: ["tightened on-device"],
            uploaded: false
        )
    }

    // MARK: - Translate

    public static func translate(_ request: AIRequest, language: String) -> AIProposal {
        let glossary = glossary(for: language)
        let source = request.bodyMarkdown.isEmpty ? request.title : request.bodyMarkdown
        var out = source
        // Longer keys first so multi-word phrases win if added later.
        let keys = glossary.keys.sorted { $0.count > $1.count }
        for key in keys {
            guard let value = glossary[key] else { continue }
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(out.startIndex..<out.endIndex, in: out)
                out = regex.stringByReplacingMatches(
                    in: out,
                    options: [],
                    range: range,
                    withTemplate: value
                )
            }
        }
        let marker = "<!-- loci-ai:translated:\(language) -->"
        let proposed: String
        if out.isEmpty {
            proposed = marker + "\n"
        } else if out.hasPrefix(marker) {
            proposed = out.hasSuffix("\n") ? out : out + "\n"
        } else {
            proposed = marker + "\n" + (out.hasSuffix("\n") ? out : out + "\n")
        }
        return AIProposal(
            action: .translate,
            objectID: request.objectID,
            provider: .onDeviceHeuristics,
            proposedBody: proposed,
            notes: ["glossary:\(language)"],
            uploaded: false
        )
    }

    // MARK: - Autofill properties

    public static func autofillProperties(_ request: AIRequest) -> AIProposal {
        let haystack = request.title + "\n" + request.bodyMarkdown
        var proposed: [String: PropertyValue] = [:]
        var notes: [String] = []

        let tags = extractHashtags(from: haystack)
        if !tags.isEmpty {
            notes.append("tags: " + tags.joined(separator: ", "))
        }

        for def in request.propertyDefs {
            if let existing = request.existingProperties[def.id], existing != .null {
                continue
            }
            switch def.kind {
            case .url:
                if let url = firstURL(in: haystack) {
                    proposed[def.id] = .url(url)
                }
            case .date:
                if let date = firstISODate(in: haystack) {
                    proposed[def.id] = .date(date)
                }
            case .text:
                let idName = (def.id + " " + def.name).lowercased()
                if idName.contains("title") || idName.contains("name") {
                    let t = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { proposed[def.id] = .text(t) }
                } else if idName.contains("tag") {
                    if !tags.isEmpty {
                        proposed[def.id] = .text(tags.joined(separator: ", "))
                    }
                } else if let snippet = firstTextSnippet(from: request.bodyMarkdown, title: request.title) {
                    proposed[def.id] = .text(snippet)
                }
            case .select:
                if let opt = def.options.first(where: { haystack.localizedCaseInsensitiveContains($0) }) {
                    proposed[def.id] = .select(opt)
                }
            case .multiSelect:
                let matches = def.options.filter { haystack.localizedCaseInsensitiveContains($0) }
                if !matches.isEmpty {
                    proposed[def.id] = .multiSelect(matches)
                }
            case .checkbox:
                let lower = haystack.lowercased()
                if lower.contains("done") || lower.contains("complete") {
                    proposed[def.id] = .bool(true)
                }
            case .number:
                if let n = firstNumber(in: haystack) {
                    proposed[def.id] = .number(n)
                }
            case .objectSelect:
                // Never hallucinate ObjectIDs.
                continue
            }
        }

        notes.append("filled \(proposed.count) propert\(proposed.count == 1 ? "y" : "ies")")
        return AIProposal(
            action: .autofillProperties,
            objectID: request.objectID,
            provider: .onDeviceHeuristics,
            proposedProperties: proposed.isEmpty ? nil : proposed,
            notes: notes,
            uploaded: false
        )
    }

    // MARK: - Helpers

    private static func nonEmptySentences(from body: String) -> [String] {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
        let parts = normalized.split(whereSeparator: { ".!?".contains($0) })
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stripFillers(_ text: String) -> String {
        var out = text
        for phrase in ["very ", "really ", "just "] {
            if let regex = try? NSRegularExpression(
                pattern: NSRegularExpression.escapedPattern(for: phrase),
                options: [.caseInsensitive]
            ) {
                let range = NSRange(out.startIndex..<out.endIndex, in: out)
                out = regex.stringByReplacingMatches(
                    in: out,
                    options: [],
                    range: range,
                    withTemplate: ""
                )
            }
        }
        return out
    }

    private static func glossary(for language: String) -> [String: String] {
        switch language {
        case "es":
            return [
                "hello": "hola",
                "world": "mundo",
                "book": "libro",
                "meeting": "reunión",
                "today": "hoy",
                "the": "el",
                "and": "y",
            ]
        case "fr":
            return [
                "hello": "bonjour",
                "world": "monde",
                "book": "livre",
                "meeting": "réunion",
                "today": "aujourd'hui",
            ]
        default:
            return [:]
        }
    }

    private static func firstURL(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s\)\]\>\"']+"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
            let r = Range(match.range, in: text)
        else { return nil }
        return String(text[r])
    }

    private static func firstISODate(in text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d{4})-(\d{2})-(\d{2})\b"#)
        else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
            let r = Range(match.range, in: text)
        else { return nil }
        let s = String(text[r])
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func firstNumber(in text: String) -> Double? {
        // Prefer standalone numbers that are not part of YYYY-MM-DD dates.
        guard let regex = try? NSRegularExpression(pattern: #"\b(\d+(?:\.\d+)?)\b"#) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches {
            guard let r = Range(match.range, in: text) else { continue }
            let start = r.lowerBound
            // Skip year/month/day pieces inside ISO dates.
            if isInsideISODate(text: text, at: start) { continue }
            if let value = Double(text[r]) { return value }
        }
        return nil
    }

    private static func isInsideISODate(text: String, at index: String.Index) -> Bool {
        guard let dateRegex = try? NSRegularExpression(pattern: #"\b\d{4}-\d{2}-\d{2}\b"#)
        else { return false }
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = dateRegex.matches(in: text, range: full)
        let utf16 = text.utf16
        let loc = utf16.distance(from: utf16.startIndex, to: index)
        for match in matches {
            if loc >= match.range.location && loc < match.range.location + match.range.length {
                return true
            }
        }
        return false
    }

    private static func firstTextSnippet(from body: String, title: String) -> String? {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        if let heading = lines.first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("#")
        }) {
            var h = heading.trimmingCharacters(in: .whitespaces)
            while h.hasPrefix("#") { h.removeFirst() }
            h = h.trimmingCharacters(in: .whitespacesAndNewlines)
            if !h.isEmpty { return truncate(h, max: 80) }
        }
        if let sentence = nonEmptySentences(from: body).first {
            return truncate(sentence, max: 80)
        }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : truncate(t, max: 80)
    }

    private static func truncate(_ s: String, max: Int) -> String {
        if s.count <= max { return s }
        return String(s.prefix(max - 1)) + "…"
    }

    private static func extractHashtags(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"#([A-Za-z0-9_\-]+)"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        var tags: [String] = []
        var seen = Set<String>()
        for match in matches {
            guard match.numberOfRanges >= 2,
                let r = Range(match.range(at: 1), in: text)
            else { continue }
            let tag = String(text[r])
            let key = tag.lowercased()
            if seen.insert(key).inserted {
                tags.append(tag)
            }
        }
        return tags
    }
}
