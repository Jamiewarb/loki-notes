import Foundation

/// One row from the disposable `links` projection (wiki-link edge).
public struct IndexedLink: Hashable, Sendable, Equatable {
    public var sourceID: ObjectID
    /// Raw wiki-link target as stored in markdown (`[[target]]` / `[[target|label]]`).
    public var target: String
    public var label: String?

    public init(sourceID: ObjectID, target: String, label: String? = nil) {
        self.sourceID = sourceID
        self.target = target
        self.label = label
    }
}

/// Backlink for inspector UI: source object that links *to* the focused object.
public struct BacklinkRecord: Hashable, Sendable, Equatable {
    public var source: LociObjectMeta
    public var target: String
    public var label: String?

    public init(source: LociObjectMeta, target: String, label: String? = nil) {
        self.source = source
        self.target = target
        self.label = label
    }
}

/// Outgoing wiki-link with optional resolved target (nil ⇒ broken).
public struct ResolvedWikiLink: Hashable, Sendable, Equatable {
    public var target: String
    public var label: String?
    public var resolved: LociObjectMeta?

    public init(target: String, label: String? = nil, resolved: LociObjectMeta? = nil) {
        self.target = target
        self.label = label
        self.resolved = resolved
    }

    public var isBroken: Bool { resolved == nil }

    public var displayText: String {
        label ?? resolved?.title ?? target
    }
}
