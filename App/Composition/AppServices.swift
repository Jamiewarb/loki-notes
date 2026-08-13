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
    /// Quick capture / inbox drain (PR26). Nil until ObjectServing + DailyNoteServing are ready.
    public private(set) var capture: CaptureService?
    /// Import markdown / Obsidian / Capacities (PR27). Nil until index is ready.
    public private(set) var importer: ImportService?
    /// AI assist (PR30) — always available; settings/credentials outside vault.
    public let ai: AIService
    /// BYOK credential store (Application Support / Keychain) — never vault.
    public let aiCredentials: AICredentialStore
    /// Apple Calendar / Reminders (PR31 / PR36) — EventKit on Apple, fakes on Linux.
    public let apple: AppleIntegrationService
    /// Safari web clipper (PR32). Nil until CaptureServing + ObjectServing are ready.
    public private(set) var safariClipper: SafariClipService?
    /// Bumped when sync UI should refresh (rebuild / simulation / conflict scan).
    public var syncRefreshNonce: Int = 0
    /// Bumped when the pin list in space.json changes (PR34).
    public var pinRefreshNonce: Int = 0

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
        sync: SyncStatusService? = nil,
        capture: CaptureService? = nil,
        importer: ImportService? = nil,
        ai: AIService? = nil,
        aiCredentials: AICredentialStore? = nil,
        apple: AppleIntegrationService? = nil,
        safariClipper: SafariClipService? = nil
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
        if let capture {
            self.capture = capture
        } else if let objects = self.objects, let dailyNotes = self.dailyNotes {
            self.capture = CaptureService(
                vault: resolvedVault,
                objects: objects,
                dailyNotes: dailyNotes
            )
        } else {
            self.capture = nil
        }
        if let importer {
            self.importer = importer
        } else if let index {
            self.importer = ImportService(
                vault: resolvedVault,
                index: index,
                schema: self.schema,
                media: self.media
            )
        } else {
            self.importer = nil
        }
        let aiDir: URL = {
            if let ai { return ai.settingsFileURL.deletingLastPathComponent() }
            return (try? AICredentialStore.defaultDirectory())
                ?? FileManager.default.temporaryDirectory.appendingPathComponent(
                    "Loci/ai",
                    isDirectory: true
                )
        }()
        let resolvedCredentials = aiCredentials ?? AICredentialStore(directory: aiDir)
        self.aiCredentials = resolvedCredentials
        self.ai =
            ai
            ?? AIService(
                settingsDirectory: aiDir,
                credentials: resolvedCredentials,
                remote: nil
            )
        let appleDir: URL = {
            if let apple { return apple.settingsFileURL.deletingLastPathComponent() }
            return (try? AppleIntegrationService.defaultDirectory())
                ?? FileManager.default.temporaryDirectory.appendingPathComponent(
                    "Loci/apple",
                    isDirectory: true
                )
        }()
        self.apple =
            apple
            ?? AppleIntegrationService(
                settingsDirectory: appleDir,
                calendarStore: AppleStoreFactory.makeCalendarStore(),
                remindersStore: AppleStoreFactory.makeRemindersStore()
            )
        if let safariClipper {
            self.safariClipper = safariClipper
        } else if let capture = self.capture, let objects = self.objects {
            self.safariClipper = SafariClipService(
                vault: resolvedVault,
                capture: capture,
                objects: objects
            )
        } else {
            self.safariClipper = nil
        }
    }

    /// Open or create the Application Support index for the active vault (never inside vault),
    /// then wire `ObjectService` + `DailyNoteService` + `CaptureService` + `ImportService`.
    @discardableResult
    public func ensureIndex() async throws -> IndexService {
        if let index {
            if objects == nil {
                objects = ObjectService(vault: vault, index: index, schema: schema)
            }
            if dailyNotes == nil {
                dailyNotes = DailyNoteService(vault: vault, index: index, schema: schema)
            }
            wireCaptureIfPossible()
            wireSafariClipperIfPossible()
            wireImporterIfPossible()
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
        wireCaptureIfPossible()
        wireSafariClipperIfPossible()
        wireImporterIfPossible()
        return service
    }

    /// Ensure vault skeleton + Page/Daily schema + local index (rebuild if empty).
    /// Call on vault create/open (onboarding / Settings). Drains capture inbox on foreground.
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
        // PR26: extensions write inbox files; main app drains on foreground.
        _ = try? await drainCaptureInbox()
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

    public func bumpPinRefresh() {
        pinRefreshNonce &+= 1
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

    public func ensureCaptureService() async throws -> CaptureService {
        if let capture { return capture }
        _ = try await ensureIndex()
        wireCaptureIfPossible()
        guard let capture else { throw LociError.indexUnavailable }
        return capture
    }

    public func ensureImportService() async throws -> ImportService {
        if let importer { return importer }
        _ = try await ensureIndex()
        wireImporterIfPossible()
        guard let importer else { throw LociError.indexUnavailable }
        return importer
    }

    /// AI service is always wired; helper for symmetry with other ensure* APIs.
    @discardableResult
    public func ensureAIService() -> AIService {
        ai
    }

    /// Apple integrations are always wired (EventKit on Apple; fakes on Linux).
    @discardableResult
    public func ensureAppleService() -> AppleIntegrationService {
        apple
    }

    public func ensureSafariClipperService() async throws -> SafariClipService {
        if let safariClipper { return safariClipper }
        _ = try await ensureCaptureService()
        wireSafariClipperIfPossible()
        guard let safariClipper else { throw LociError.indexUnavailable }
        return safariClipper
    }

    /// Drain extension inbox staging files into today / typed objects (PR26).
    @discardableResult
    public func drainCaptureInbox(calendar: Calendar = .current) async throws -> [CaptureResult] {
        let service = try await ensureCaptureService()
        return try await service.drainInbox(calendar: calendar)
    }

    private func wireCaptureIfPossible() {
        guard capture == nil, let objects, let dailyNotes else { return }
        capture = CaptureService(vault: vault, objects: objects, dailyNotes: dailyNotes)
        wireSafariClipperIfPossible()
    }

    private func wireSafariClipperIfPossible() {
        guard safariClipper == nil, let capture, let objects else { return }
        safariClipper = SafariClipService(vault: vault, capture: capture, objects: objects)
    }

    private func wireImporterIfPossible() {
        guard importer == nil, let index else { return }
        importer = ImportService(vault: vault, index: index, schema: schema, media: media)
    }

    /// Ensure today’s daily note exists (auto-create). Used on Daily open / iOS launch path.
    @discardableResult
    public func ensureTodayDailyNote(calendar: Calendar = .current) async throws -> OpenedObject {
        let notes = try await ensureDailyNoteService()
        return try await notes.ensureToday(calendar: calendar)
    }
}
