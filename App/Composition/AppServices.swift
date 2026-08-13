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
    /// Concrete vault I/O (local Documents fallback always available).
    public let vault: VaultService
    /// Per-type schema + space.json (merge-friendly `.loci/types/*.json`).
    public let schema: SchemaStore
    /// Local SQLite projection (Application Support) — never inside the vault.
    /// Created lazily after vault root is known; nil until `ensureIndex()` succeeds.
    public private(set) var index: IndexService?
    /// Object CRUD orchestration (`ObjectServing`). Nil until index is ready.
    public private(set) var objects: ObjectService?
    /// Daily note ensure/open (`DailyNoteServing`). Nil until index is ready.
    public private(set) var dailyNotes: DailyNoteService?

    public init(
        spaceName: String = "Loci",
        /// iOS / default launch prefers Daily (inbox). Documented preference for PR10.
        selectedRoute: Route = .daily,
        vault: VaultService? = nil,
        schema: SchemaStore? = nil,
        index: IndexService? = nil,
        objects: ObjectService? = nil,
        dailyNotes: DailyNoteService? = nil
    ) {
        self.spaceName = spaceName
        self.selectedRoute = selectedRoute
        let resolvedVault =
            vault
            ?? (try? VaultService(forceLocal: false))
            ?? (try! VaultService(forceLocal: true))
        self.vault = resolvedVault
        self.schema = schema ?? SchemaStore(vault: resolvedVault)
        self.index = index
        if let objects {
            self.objects = objects
        } else if let index {
            self.objects = ObjectService(vault: resolvedVault, index: index)
        } else {
            self.objects = nil
        }
        if let dailyNotes {
            self.dailyNotes = dailyNotes
        } else if let index {
            self.dailyNotes = DailyNoteService(vault: resolvedVault, index: index)
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
                objects = ObjectService(vault: vault, index: index)
            }
            if dailyNotes == nil {
                dailyNotes = DailyNoteService(vault: vault, index: index)
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
        self.objects = ObjectService(vault: vault, index: service)
        self.dailyNotes = DailyNoteService(vault: vault, index: service)
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
            switch await vault.rootKind {
            case .localDocuments:
                return .localOnly
            case .iCloudUbiquity:
                return .iCloudAvailable
            }
        }
    }

    /// Settings / onboarding “Create vault” — skeleton + bootstrap + index.
    public func createVaultIfNeeded() async throws {
        try await openVaultPipeline(rebuildIfNeeded: true)
    }

    /// Create a Page and navigate to the editor.
    @discardableResult
    public func createPage(title: String = "Untitled") async throws -> LociObjectMeta {
        let service = try await ensureObjectService()
        let meta = try await service.create(typeID: .page, title: title)
        await open(objectID: meta.id)
        return meta
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
