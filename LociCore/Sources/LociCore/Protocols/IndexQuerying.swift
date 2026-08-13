import Foundation

/// Read-only derived index queries. Index DB lives in Application Support only — never in the vault.
public protocol IndexQuerying: Sendable {
    func object(id: ObjectID) async throws -> LociObjectMeta?
    func objects(typeID: ObjectTypeID) async throws -> [LociObjectMeta]
    func search(query: String) async throws -> [LociObjectMeta]
    func created(on day: Date) async throws -> [LociObjectMeta]

    /// Filter via `properties_idx` (text / select / url match on `value_text`).
    /// When `typeID` is non-nil, results are restricted to that type.
    func objects(
        typeID: ObjectTypeID?,
        propertyKey: String,
        equalsText: String
    ) async throws -> [LociObjectMeta]

    /// Scalar columns from `properties_idx` for an object (filter/sort foundation).
    func propertyIndex(objectID: ObjectID) async throws -> [PropertyIndexRow]

    // MARK: - Wiki-links / backlinks (PR16)

    /// Resolve a wiki-link target: ObjectID first, then path/slug, then title.
    func resolve(wikiTarget: String) async throws -> LociObjectMeta?

    /// Objects that contain a wiki-link pointing at `objectID` (by id / path / title aliases).
    func backlinks(to objectID: ObjectID) async throws -> [BacklinkRecord]

    /// Outgoing wiki-links from an object, each optionally resolved.
    func outgoingLinks(from objectID: ObjectID) async throws -> [ResolvedWikiLink]

    /// Picker candidates (`@` / `[[` search). Empty query → recent by `updated`.
    func linkCandidates(
        matching query: String,
        excluding excludeID: ObjectID?,
        limit: Int
    ) async throws -> [LociObjectMeta]
}

/// One row from the disposable `properties_idx` projection.
public struct PropertyIndexRow: Hashable, Sendable, Equatable {
    public var key: String
    public var valueText: String?
    public var valueNumber: Double?
    public var valueBool: Bool?
    public var valueDate: Date?

    public init(
        key: String,
        valueText: String? = nil,
        valueNumber: Double? = nil,
        valueBool: Bool? = nil,
        valueDate: Date? = nil
    ) {
        self.key = key
        self.valueText = valueText
        self.valueNumber = valueNumber
        self.valueBool = valueBool
        self.valueDate = valueDate
    }
}
