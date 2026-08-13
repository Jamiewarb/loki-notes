import Foundation

/// How a capture should land in the vault (PR26).
///
/// Extensions enqueue these as JSON under `.loci/inbox/`; the main app drains
/// them into today’s daily note or a typed object. Staging inbox files are
/// **not** a second permanent inbox — daily remains the user-facing inbox.
public enum CaptureKind: String, Sendable, Hashable, Codable, Equatable {
    /// Append a line to `daily/YYYY-MM-DD.md` (ensure-today first).
    case appendToToday
    /// Create a typed object under `objects/<type>/`.
    case createObject
}

/// Surface that produced the capture (diagnostic only — not persisted into body unless formatted).
public enum CaptureSource: String, Sendable, Hashable, Codable, Equatable {
    case share
    case widget
    case menuBar
    case harness
    case unknown
}

/// Staging payload written by Share / Widget / menu bar into `.loci/inbox/<id>.json`.
///
/// Extensions have no in-memory index — they only write vault files. The main app
/// drains on foreground (`CaptureServing.drainInbox`).
public struct CaptureInboxItem: Hashable, Sendable, Equatable, Codable {
    public var id: String
    public var createdAt: Date
    public var kind: CaptureKind
    /// Shared text / note body / URL description.
    public var text: String
    /// Optional title when `kind == .createObject` (falls back to first line of text).
    public var title: String?
    /// Object type for create (`page` default). Ignored for append.
    public var typeID: ObjectTypeID?
    /// Optional source URL (share sheet web page, etc.).
    public var sourceURL: String?
    public var source: CaptureSource

    public init(
        id: String = UUID().uuidString.lowercased(),
        createdAt: Date = Date(),
        kind: CaptureKind,
        text: String,
        title: String? = nil,
        typeID: ObjectTypeID? = nil,
        sourceURL: String? = nil,
        source: CaptureSource = .unknown
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.text = text
        self.title = title
        self.typeID = typeID
        self.sourceURL = sourceURL
        self.source = source
    }

    /// Convenience: append-to-today inbox item.
    public static func appendLine(
        _ text: String,
        source: CaptureSource = .unknown,
        sourceURL: String? = nil
    ) -> CaptureInboxItem {
        CaptureInboxItem(
            kind: .appendToToday,
            text: text,
            sourceURL: sourceURL,
            source: source
        )
    }

    /// Convenience: create-typed-object inbox item.
    public static func createTyped(
        typeID: ObjectTypeID = .page,
        title: String?,
        text: String,
        source: CaptureSource = .unknown,
        sourceURL: String? = nil
    ) -> CaptureInboxItem {
        CaptureInboxItem(
            kind: .createObject,
            text: text,
            title: title,
            typeID: typeID,
            sourceURL: sourceURL,
            source: source
        )
    }
}

/// Outcome of applying one capture (direct or drained).
public struct CaptureResult: Hashable, Sendable, Equatable, Codable {
    public var kind: CaptureKind
    /// Object that received the write (daily id or created object id).
    public var objectID: ObjectID
    public var relativePath: String
    /// Staging path that was drained (`nil` for direct captures).
    public var inboxRelativePath: String?
    public var appendedLine: String?

    public init(
        kind: CaptureKind,
        objectID: ObjectID,
        relativePath: String,
        inboxRelativePath: String? = nil,
        appendedLine: String? = nil
    ) {
        self.kind = kind
        self.objectID = objectID
        self.relativePath = relativePath
        self.inboxRelativePath = inboxRelativePath
        self.appendedLine = appendedLine
    }
}

/// Pure helpers for inbox paths + append-line formatting (Linux-testable).
public enum CaptureInbox: Sendable {
    public static let directory = ".loci/inbox"

    /// Vault-relative path for a staging item: `.loci/inbox/<id>.json`.
    public static func relativePath(forID id: String) -> String {
        let safe = sanitizeID(id)
        return "\(directory)/\(safe).json"
    }

    public static func sanitizeID(_ id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var out = ""
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                out.unicodeScalars.append(scalar)
            }
        }
        return out.isEmpty ? UUID().uuidString.lowercased() : out
    }

    /// Whether a relative path looks like a capture inbox JSON file.
    public static func isInboxPath(_ relativePath: String) -> Bool {
        let p = relativePath.replacingOccurrences(of: "\\", with: "/")
        guard p.hasPrefix("\(directory)/"), p.hasSuffix(".json") else { return false }
        let name = (p as NSString).lastPathComponent
        return name.count > 5
    }
}

/// Formats a single markdown line appended into today’s daily note.
public enum CaptureLineFormatter: Sendable {
    /// `- Shared text` optionally with URL and source tag.
    public static func line(
        text: String,
        sourceURL: String? = nil,
        source: CaptureSource? = nil
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var body = trimmed.isEmpty ? "(empty capture)" : trimmed
        // Collapse internal newlines into spaces so one capture = one list item.
        body = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if body.isEmpty { body = "(empty capture)" }

        var suffix = ""
        if let url = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            suffix += " — \(url)"
        }
        if let source, source != .unknown {
            suffix += " · \(source.rawValue)"
        }
        return "- \(body)\(suffix)"
    }

    /// Append `line` to an existing body, ensuring a trailing newline separation.
    public static func append(line: String, toBody body: String) -> String {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else { return body }
        if body.isEmpty { return trimmedLine + "\n" }
        if body.hasSuffix("\n") {
            return body + trimmedLine + "\n"
        }
        return body + "\n" + trimmedLine + "\n"
    }

    /// Derive a short title from capture text when none was provided.
    public static func inferredTitle(from text: String, fallback: String = "Captured") -> String {
        let first = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if first.isEmpty { return fallback }
        if first.count <= 80 { return first }
        return String(first.prefix(77)) + "…"
    }
}

/// JSON codec for inbox staging files (Linux-testable; no I/O).
public enum CaptureInboxCodec: Sendable {
    public static func encode(_ item: CaptureInboxItem) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(item)
    }

    public static func decode(_ data: Data) throws -> CaptureInboxItem {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CaptureInboxItem.self, from: data)
    }
}
