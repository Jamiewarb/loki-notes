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

    /// Other notes whose plain body text mentions this object’s title but do not
    /// already wiki-link to it. Derived UI only — never run on the typing path.
    /// Bounded to `UnlinkedMentionScanner.resultLimit` (50).
    func unlinkedMentions(to objectID: ObjectID) async throws -> [UnlinkedMention]

    /// Picker candidates (`@` / `[[` search). Empty query → recent by `updated`.
    func linkCandidates(
        matching query: String,
        excluding excludeID: ObjectID?,
        limit: Int
    ) async throws -> [LociObjectMeta]

    // MARK: - Tags (PR17)

    /// Distinct tags with object counts (optionally collapsed via aliases).
    func allTags(aliases: TagAliasTable, limit: Int) async throws -> [TagSummary]

    /// Objects carrying `tag` (or any of its aliases). Optional `typeID` restricts to one type.
    func objects(
        tagged tag: String,
        typeID: ObjectTypeID?,
        aliases: TagAliasTable
    ) async throws -> [LociObjectMeta]

    /// `#` completer candidates. Empty query → most-used tags.
    func tagCandidates(
        matching query: String,
        aliases: TagAliasTable,
        limit: Int
    ) async throws -> [TagSummary]

    // MARK: - Tasks (PR19)

    /// Projected GFM task items. `completed` nil = all; `true`/`false` filters checkbox state.
    func tasks(completed: Bool?) async throws -> [IndexedTask]

    /// Incomplete tasks across the vault (Open tasks aggregation).
    func openTasks() async throws -> [IndexedTask]

    /// Tasks whose source object is the daily note for `day` (`daily/YYYY-MM-DD.md`).
    func tasks(inDailyNoteOn day: Date, calendar: Calendar) async throws -> [IndexedTask]

    // MARK: - QueryEngine (PR23)

    /// Execute a filter DSL against the index. Results are derived — callers must
    /// not write them into vault markdown unless the user explicitly inserts an embed.
    func execute(_ definition: QueryDefinition) async throws -> [LociObjectMeta]

    // MARK: - Graph (PR24)

    /// Build a capped link graph from the disposable `links` table (resolved edges only).
    /// Features must not scrape markdown for graph topology.
    func graph(options: GraphBuildOptions) async throws -> GraphSnapshot

    // MARK: - Calendar markers (PR25)

    /// Index-derived day markers for calendar chrome (daily note presence, content, creations).
    /// Inclusive `from`/`to` calendar days. Never writes into the vault.
    func calendarMarkers(
        from: Date,
        to: Date,
        calendar: Calendar
    ) async throws -> [CalendarDayMarker]
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
