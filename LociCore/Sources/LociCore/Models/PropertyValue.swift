import Foundation

/// Property value union used by frontmatter / schema (kinds align with `PropertyKind`).
public enum PropertyValue: Hashable, Sendable, Codable, Equatable {
    case text(String)
    case number(Double)
    case bool(Bool)
    case date(Date)
    case url(String)
    case select(String)
    case multiSelect([String])
    /// Object references by ObjectID string (frontmatter / wiki-link targets).
    case objectSelect([String])
    case null

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    private enum KindKey: String, Codable {
        case text, number, bool, date, url, select, multiSelect, objectSelect, null
    }

    public init(from decoder: Decoder) throws {
        // Prefer tagged object encoding; also accept bare JSON primitives for frontmatter comfort.
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
            let kind = try? container.decode(KindKey.self, forKey: .kind)
        {
            switch kind {
            case .text:
                self = .text(try container.decode(String.self, forKey: .value))
            case .number:
                self = .number(try container.decode(Double.self, forKey: .value))
            case .bool:
                self = .bool(try container.decode(Bool.self, forKey: .value))
            case .date:
                self = .date(try container.decode(Date.self, forKey: .value))
            case .url:
                self = .url(try container.decode(String.self, forKey: .value))
            case .select:
                self = .select(try container.decode(String.self, forKey: .value))
            case .multiSelect:
                self = .multiSelect(try container.decode([String].self, forKey: .value))
            case .objectSelect:
                self = .objectSelect(try container.decode([String].self, forKey: .value))
            case .null:
                self = .null
            }
            return
        }

        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let b = try? single.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? single.decode(Double.self) {
            self = .number(n)
        } else if let s = try? single.decode(String.self) {
            self = .text(s)
        } else if let arr = try? single.decode([String].self) {
            self = .multiSelect(arr)
        } else {
            throw DecodingError.dataCorruptedError(
                in: single,
                debugDescription: "Unsupported PropertyValue payload"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):
            try container.encode(KindKey.text, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .number(let v):
            try container.encode(KindKey.number, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .bool(let v):
            try container.encode(KindKey.bool, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .date(let v):
            try container.encode(KindKey.date, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .url(let v):
            try container.encode(KindKey.url, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .select(let v):
            try container.encode(KindKey.select, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .multiSelect(let v):
            try container.encode(KindKey.multiSelect, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .objectSelect(let v):
            try container.encode(KindKey.objectSelect, forKey: .kind)
            try container.encode(v, forKey: .value)
        case .null:
            try container.encode(KindKey.null, forKey: .kind)
        }
    }
}
