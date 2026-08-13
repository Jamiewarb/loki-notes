import Foundation
import Observation
import LociCore
import LociVault
import LociIndex

/// Composition root for service wiring.
/// Conforms to `Navigating` + `SyncStatusProviding`; features depend on protocols only.
@Observable
public final class AppServices: Navigating, SyncStatusProviding, @unchecked Sendable {
    public var spaceName: String
    /// Currently presented shell destination.
    public var selectedRoute: Route
    /// Calendar day shown in the Daily inspector “Created today” panel (PR11).
    /// Updated by `DailyNoteView` when the day switcher changes — index query only.
    public var inspectedDailyDay: Date
    /// Type dashboard focus inside Types destination (`nil` = type list). PR12.
    public var focusedTypeID: ObjectTypeID?
    /// Tag browse focus inside Tags destination (`nil` = all tags). PR17.
    public var focusedTag: String?
    /// Draft query shared between Search destination + inspector (PR18).
    public var searchQueryDraft: String = ""
    /// Optional type chip filter for Search (`nil` = all).
    public var searchFilterTypeID: ObjectTypeID?
    /// Bumped by ⌘K / inspector to re-focus the Search field.
    public var searchFocusNonce: Int = 0
    /// Recent FTS queries (in-memory only — not vault / not index).
    public var recentSearches = RecentSearchStore()
    /// Live editor session for the open object — property inspector shares saves (PR13).
    @ObservationIgnored
    public weak var activeEditorSession: EditorSessionBridge?
    /// Concrete vault I/O (local Documents fallback always available).
    public let vault: VaultService
    /// Per-type schema + space.json (merge-friendly `.loci/types/*.json`).
    public let schema: SchemaStore
    /// Local SQLite projection (Application Support) — never inside the vault.
    /// Created lazily after `ensureIndex()` succeeds.
    public private(set) var index: IndexService?
    /// Object CRUD orchestration (`ObjectServing`). Nil until index is ready.
    public private(set) var objects: ObjectService?
    /// Daily note ensure/open (`DailyNoteServing`). Nil until index is ready.
    public private(set) var dailyNotes: DailyNoteService?
    /// Media attach into vault `media/` (PR20). Always available — no index required.
    public let media: MediaService
    /// Sync status derivation + conflict scan (PR21).
    public let sync: SyncStatusService
    /// Bumped when sync UI should refresh (rebuild / simulation / conflict scan).
    public var syncRefreshNonce: Int = 0

    public init(
        spaceName: String = "Loci",
        /// iOS / default launch prefers Daily (inbox). Documented preference for PR10.
        selectedRoute: Route = .daily,
        inspectedDailyDay: Date = DailyNoteIdentity.startOfDay(Date()),
        focusedTypeID: ObjectTypeID? = nil,
        focusedTag: String? = nil,
        vault: VaultService? = nil,
        schema: SchemaStore? = nil,
        index: IndexService? = nil,
        objects: ObjectService? = nil,
        dailyNotes: DailyNoteService? = nil,
        media: MediaService? = nil,
        sync: SyncStatusService? = nil
    ) {
        self.spaceName = spaceName
        self.selectedRoute = selectedRoute
        self.inspectedDailyDay = inspectedDailyDay
        self.focusedTypeID = focusedTypeID
        self.focusedTag = focusedTag
        let resolvedVault =
            vault
            ?? (try? VaultService(forceLocal: false))
            ?? (try! VaultService(forceLocal: true))
        self.vault = resolvedVault
        self.schema = schema ?? SchemaStore(vault: resolvedVault)
        self.media = media ?? MediaService(vault: resolvedVault)
        self.sync = sync ?? SyncStatusService(vault: resolvedVault)
        self.index = index
        if let objects {
            self.objects = objects
        } else if let index {
            self.objects = ObjectService(vault: resolvedVault, index: index, schema: self.schema)
        } else {
            self.objects = nil
        }
        if let dailyNotes {
            self.dailyNotes = dailyNotes
        } else if let index {
            self.dailyNotes = DailyNoteService(
                vault: resolvedVault,
                index: index,
                schema: self.schema
            )
        } else {
            self.dailyNotes = nil
        }
    }

    /// Open or create the Application Support index for the active vault (never inside vault),
    /// then wire `ObjectService` + `DailyNoteService`.
    @discardableResult
    public func ensureIndex() async throws -> IndexService {
        if let index {
            if objects == nil {
                objects = ObjectService(vault: vault, index: index, schema: schema)
            }
            if dailyNotes == nil {
                dailyNotes = DailyNoteService(vault: vault, index: index, schema: schema)
            }
            return index
        }
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let directory = try IndexDatabase.defaultApplicationSupportDirectory()
        #else
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Loci", isDirectory: true)
        #endif
        let service = try await IndexService(vault: vault, indexDirectory: directory)
        self.index = service
        self.objects = ObjectService(vault: vault, index: service, schema: schema)
        self.dailyNotes = DailyNoteService(vault: vault, index: service, schema: schema)
        return service
    }

    /// Ensure vault skeleton + Page/Daily schema + local index (rebuild if empty).
    /// Call on vault create/open (onboarding / Settings).
    public func openVaultPipeline(rebuildIfNeeded: Bool = true) async throws {
        try await schema.bootstrapSchema(spaceName: spaceName)
        let index = try await ensureIndex()
        if rebuildIfNeeded {
            let pages = try await index.objects(typeID: .page)
            let dailies = try await index.objects(typeID: .daily)
            // Fresh index after first open — full scan so existing vault files appear.
            if pages.isEmpty && dailies.isEmpty {
                try await index.rebuild()
            }
        }
        if let settings = try? await schema.loadSpaceSettings() {
            spaceName = settings.name
        }
    }

    public func open(route: Route) async {
        selectedRoute = route
    }

    public func open(objectID: ObjectID) async {
        selectedRoute = .object(objectID)
    }

    public var status: SyncStatus {
        get async {
            await sync.currentStatus()
        }
    }

    public var vaultPathDisplay: String {
        get async throws {
            try await sync.vaultPathDisplay()
        }
    }

    public func listConflictedCopies() async throws -> [SyncConflictItem] {
        try await sync.listConflictedCopies()
    }

    public func ensureDownloaded(atRelativePath path: String) async throws {
        try await sync.ensureDownloaded(atRelativePath: path)
    }

    public func rebuildIndex() async throws {
        let index = try await ensureIndex()
        try await index.rebuild()
        bumpSyncRefresh()
    }

    @discardableResult
    public func revealVaultPath() async throws -> String {
        try await sync.revealVaultPath()
    }

    /// DevHarness / tests: force chip state (Linux simulated syncing/offline/error).
    public func simulateSyncStatus(_ status: SyncStatus?) {
        sync.simulatedOverride = status
        bumpSyncRefresh()
    }

    public func bumpSyncRefresh() {
        syncRefreshNonce &+= 1
    }

    /// Settings / onboarding “Create vault” — skeleton + bootstrap + index.
    public func createVaultIfNeeded() async throws {
        try await openVaultPipeline(rebuildIfNeeded: true)
    }

    /// Create a Page and navigate to the editor.
    @discardableResult
    public func createPage(title: String = "Untitled") async throws -> LociObjectMeta {
        try await createObject(typeID: .page, title: title)
    }

    /// Create an object of any known type and navigate to the editor.
    @discardableResult
    public func createObject(typeID: ObjectTypeID, title: String = "Untitled") async throws
        -> LociObjectMeta
    {
        let service = try await ensureObjectService()
        let meta = try await service.create(typeID: typeID, title: title)
        await open(objectID: meta.id)
        return meta
    }

    /// Open Types destination focused on a type dashboard (PR12).
    public func openTypeDashboard(_ typeID: ObjectTypeID) async {
        focusedTypeID = typeID
        selectedRoute = .types
    }

    /// Open Tags browse, optionally focused on one tag (PR17).
    public func openTag(_ tag: String?) async {
        if let tag {
            focusedTag = TagNormalization.normalize(tag)
        } else {
            focusedTag = nil
        }
        selectedRoute = .tags
    }

    /// Open Search destination and focus the query field (⌘K / iOS Search tab). PR18.
    public func openSearch(query: String? = nil) async {
        if let query {
            searchQueryDraft = SearchRanking.normalizeQuery(query)
        }
        searchFocusNonce &+= 1
        selectedRoute = .search
    }

    public func requestSearchFocus() {
        searchFocusNonce &+= 1
    }

    public func recordRecentSearch(_ query: String) {
        var store = recentSearches
        store.record(query)
        recentSearches = store
    }

    public func clearRecentSearches() {
        var store = recentSearches
        store.clear()
        recentSearches = store
    }

    public func ensureObjectService() async throws -> ObjectService {
        if let objects { return objects }
        _ = try await ensureIndex()
        guard let objects else { throw LociError.indexUnavailable }
        return objects
    }

    public func ensureDailyNoteService() async throws -> DailyNoteService {
        if let dailyNotes { return dailyNotes }
        _ = try await ensureIndex()
        guard let dailyNotes else { throw LociError.indexUnavailable }
        return dailyNotes
    }

    /// Ensure today’s daily note exists (auto-create). Used on Daily open / iOS launch path.
    @discardableResult
    public func ensureTodayDailyNote(calendar: Calendar = .current) async throws -> OpenedObject {
        let notes = try await ensureDailyNoteService()
        return try await notes.ensureToday(calendar: calendar)
    }
}
