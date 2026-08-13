import Foundation

/// Display / draft helpers for property values (UI + demos; no I/O).
public enum PropertyValueFormatting: Sendable {
    /// Human-readable label for inspector / harness rows.
    public static func displayString(_ value: PropertyValue) -> String {
        switch value {
        case .null:
            return ""
        case .text(let s), .url(let s), .select(let s):
            return s
        case .number(let n):
            if n == Double(Int(n)) { return String(Int(n)) }
            return String(n)
        case .bool(let b):
            return b ? "true" : "false"
        case .date(let d):
            return ISO8601DateFormatter().string(from: d)
        case .multiSelect(let items), .objectSelect(let items):
            return items.joined(separator: ", ")
        }
    }

    /// Coerce a draft string into a `PropertyValue` for the given kind.
    /// Object-select stays a stub: comma-separated ids stored as `.objectSelect`.
    public static func coerce(draft: String, kind: PropertyKind) -> PropertyValue {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .text:
            return trimmed.isEmpty ? .null : .text(trimmed)
        case .number:
            guard !trimmed.isEmpty, let n = Double(trimmed) else { return .null }
            return .number(n)
        case .date:
            guard !trimmed.isEmpty else { return .null }
            if let d = ISO8601DateFormatter().date(from: trimmed) {
                return .date(d)
            }
            // Date-only YYYY-MM-DD
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            df.dateFormat = "yyyy-MM-dd"
            if let d = df.date(from: trimmed) {
                return .date(d)
            }
            return .text(trimmed)
        case .select:
            return trimmed.isEmpty ? .null : .select(trimmed)
        case .multiSelect:
            let parts = trimmed.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            return parts.isEmpty ? .null : .multiSelect(parts)
        case .checkbox:
            if trimmed.isEmpty { return .bool(false) }
            let lower = trimmed.lowercased()
            if ["true", "1", "yes", "on"].contains(lower) { return .bool(true) }
            if ["false", "0", "no", "off"].contains(lower) { return .bool(false) }
            return .bool(false)
        case .url:
            return trimmed.isEmpty ? .null : .url(trimmed)
        case .objectSelect:
            // Stub: store comma-separated object id / path refs.
            let parts = trimmed.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            return parts.isEmpty ? .null : .objectSelect(parts)
        }
    }

    /// Draft string used when editing an existing value in a text field.
    public static func draftString(_ value: PropertyValue) -> String {
        displayString(value)
    }
}
