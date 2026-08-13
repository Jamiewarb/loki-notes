import Foundation
import LociCore
import LociMarkdown

/// Loads/saves `.loci/space.json` and per-type `.loci/types/<slug>.json` via `VaultServing`.
/// Merge-friendly: one type per file — never a monolithic schema.json.
/// Templates live under `.loci/templates/<id>.md` (PR14).
/// Collections live under `.loci/collections/<type>.<slug>.json` (PR22).
/// Saved queries live under `.loci/queries/<slug>.json` (PR23) — definitions only.
public final class SchemaStore: SchemaServing, PinServing, @unchecked Sendable {
    private let vault: any VaultServing
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(vault: any VaultServing) {
        self.vault = vault
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Space

    public func loadSpaceSettings() async throws -> SpaceSettings {
        let path = VaultLayout.spaceJSON
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.schemaNotFound(path)
        }
        let data = try await vault.readFile(atRelativePath: path)
        return try decoder.decode(SpaceSettings.self, from: data)
    }

    public func saveSpaceSettings(_ settings: SpaceSettings) async throws {
        let data = try encoder.encode(settings)
        try await vault.writeFile(data, atRelativePath: VaultLayout.spaceJSON)
    }

    // MARK: - Types

    public func knownTypeIDs() async throws -> [ObjectTypeID] {
        let names = try await listTypeFileSlugs()
        return names.map { ObjectTypeID($0) }.sorted { $0.rawValue < $1.rawValue }
    }

    public func loadType(_ id: ObjectTypeID) async throws -> ObjectType {
        let path = Self.typeRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.schemaNotFound(path)
        }
        let data = try await vault.readFile(atRelativePath: path)
        return try decoder.decode(ObjectType.self, from: data)
    }

    public func saveType(_ type: ObjectType) async throws {
        let path = Self.typeRelativePath(for: type.id)
        let data = try encoder.encode(type)
        try await vault.writeFile(data, atRelativePath: path)
    }

    public func allTypes() async throws -> [ObjectType] {
        var result: [ObjectType] = []
        for id in try await knownTypeIDs() {
            result.append(try await loadType(id))
        }
        return result
    }

    /// Ensure vault skeleton directories + `space.json`, then seed built-in **Page** + **Daily** + **Image** + **Meeting** + **Weblink**.
    public func bootstrapSchema(spaceName: String = "Loci") async throws {
        try await vault.ensureSkeleton(spaceName: spaceName)
        try await seedBuiltInPageIfNeeded()
        try await seedBuiltInDailyIfNeeded()
        try await seedBuiltInImageIfNeeded()
        try await seedBuiltInMeetingIfNeeded()
        try await seedBuiltInWeblinkIfNeeded()
    }

    /// Write `page.json` when absent (idempotent). Safe to call after `ensureSkeleton`.
    public func seedBuiltInPageIfNeeded() async throws {
        let path = Self.typeRelativePath(for: .page)
        if try await vault.fileExists(atRelativePath: path) {
            return
        }
        try await saveType(.builtInPage)
    }

    /// Write `daily.json` when absent (idempotent). Daily notes use `daily/YYYY-MM-DD.md`.
    public func seedBuiltInDailyIfNeeded() async throws {
        let path = Self.typeRelativePath(for: .daily)
        if try await vault.fileExists(atRelativePath: path) {
            return
        }
        try await saveType(.builtInDaily)
    }

    /// Write `image.json` when absent (idempotent). Blobs live under `media/`; objects under `objects/image/`.
    public func seedBuiltInImageIfNeeded() async throws {
        let path = Self.typeRelativePath(for: .image)
        if !(try await vault.fileExists(atRelativePath: path)) {
            try await saveType(.builtInImage)
        }
        try await ensureObjectsFolder(for: .image)
    }

    /// Write `meeting.json` when absent (idempotent). Objects under `objects/meeting/` (PR31).
    public func seedBuiltInMeetingIfNeeded() async throws {
        let path = Self.typeRelativePath(for: .meeting)
        if !(try await vault.fileExists(atRelativePath: path)) {
            try await saveType(.builtInMeeting)
        }
        try await ensureObjectsFolder(for: .meeting)
    }

    /// Write `weblink.json` when absent (idempotent). Objects under `objects/weblink/` (PR32).
    public func seedBuiltInWeblinkIfNeeded() async throws {
        let path = Self.typeRelativePath(for: .weblink)
        if !(try await vault.fileExists(atRelativePath: path)) {
            try await saveType(.builtInWeblink)
        }
        try await ensureObjectsFolder(for: .weblink)
    }

    // MARK: - Custom types (PR12)

    public func createType(
        name: String,
        icon: String = "square.grid.2x2",
        color: String = "#0F6B5C",
        slug: String? = nil
    ) async throws -> ObjectType {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LociError.invalidTypeSlug("(empty name)")
        }
        let resolved = try TypeSlug.resolve(explicit: slug, fromName: trimmed)
        let id = ObjectTypeID(resolved)
        if TypeSlug.isProtected(id) {
            throw LociError.typeProtected(resolved)
        }
        let path = Self.typeRelativePath(for: id)
        if try await vault.fileExists(atRelativePath: path) {
            throw LociError.typeAlreadyExists(resolved)
        }
        let type = ObjectType(
            id: id,
            name: trimmed,
            icon: icon.isEmpty ? "square.grid.2x2" : icon,
            color: color.isEmpty ? "#0F6B5C" : color,
            properties: [],
            isBuiltIn: false,
            isDaily: false
        )
        try await saveType(type)
        try await ensureObjectsFolder(for: id)
        return type
    }

    public func renameType(_ id: ObjectTypeID, name: String) async throws -> ObjectType {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LociError.invalidTypeSlug("(empty name)")
        }
        var type = try await loadType(id)
        type.name = trimmed
        try await saveType(type)
        return type
    }

    public func deleteType(_ id: ObjectTypeID, force: Bool = false) async throws {
        let type = try await loadType(id)
        if type.isBuiltIn || TypeSlug.isProtected(id) {
            throw LociError.typeProtected(id.rawValue)
        }
        let markdownCount = try await countObjectMarkdown(for: id)
        if markdownCount > 0 && !force {
            throw LociError.typeNotEmpty(id.rawValue)
        }
        try await vault.deleteFile(atRelativePath: Self.typeRelativePath(for: id))
    }

    // MARK: - Properties (PR13)

    @discardableResult
    public func setProperties(_ typeID: ObjectTypeID, properties: [PropertyDef]) async throws
        -> ObjectType
    {
        var type = try await loadType(typeID)
        // Reject duplicate ids within the payload.
        var seen = Set<String>()
        for def in properties {
            let id = PropertyKey.normalize(def.id)
            guard !id.isEmpty else { throw LociError.invalidPropertyID("(empty)") }
            if seen.contains(id) {
                throw LociError.invalidPropertyID(id)
            }
            seen.insert(id)
        }
        type.properties = properties.map { def in
            var copy = def
            copy.id = PropertyKey.normalize(def.id)
            return copy
        }
        try await saveType(type)
        return type
    }

    @discardableResult
    public func upsertProperty(_ typeID: ObjectTypeID, def: PropertyDef) async throws -> ObjectType {
        let id = try PropertyKey.resolve(explicit: def.id, fromName: def.name)
        var type = try await loadType(typeID)
        var next = def
        next.id = id
        if let idx = type.properties.firstIndex(where: { $0.id == id }) {
            type.properties[idx] = next
        } else {
            type.properties.append(next)
        }
        try await saveType(type)
        return type
    }

    @discardableResult
    public func removeProperty(_ typeID: ObjectTypeID, propertyID: String) async throws -> ObjectType {
        let id = PropertyKey.normalize(propertyID)
        guard !id.isEmpty else { throw LociError.invalidPropertyID("(empty)") }
        var type = try await loadType(typeID)
        let before = type.properties.count
        type.properties.removeAll { $0.id == id }
        guard type.properties.count < before else {
            throw LociError.propertyNotFound(id)
        }
        try await saveType(type)
        return type
    }

    // MARK: - Templates (PR14)

    public func listTemplates(typeID: ObjectTypeID) async throws -> [ObjectTemplate] {
        _ = try await loadType(typeID) // ensure type exists
        let slugs = try await listTemplateFileIDs()
        var result: [ObjectTemplate] = []
        for fileID in slugs where fileID.hasPrefix("\(typeID.rawValue).") {
            if let template = try? await loadTemplate(fileID), template.typeID == typeID {
                result.append(template)
            }
        }
        // Also include ids registered on the type that may use non-prefix naming.
        let type = try await loadType(typeID)
        for registered in type.templateIDs where !result.contains(where: { $0.id == registered }) {
            if let template = try? await loadTemplate(registered), template.typeID == typeID {
                result.append(template)
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    public func loadTemplate(_ id: String) async throws -> ObjectTemplate {
        let path = Self.templateRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.templateNotFound(id)
        }
        let data = try await vault.readFile(atRelativePath: path)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw LociError.templateNotFound(id)
        }
        do {
            return try TemplateCodec.decode(markdown)
        } catch {
            throw LociError.templateNotFound(id)
        }
    }

    @discardableResult
    public func saveTemplate(_ template: ObjectTemplate) async throws -> ObjectTemplate {
        guard TemplateID.isValid(template.id) else {
            throw LociError.invalidTemplateID(template.id)
        }
        // Ensure type exists.
        var type = try await loadType(template.typeID)
        let markdown = TemplateCodec.encode(template)
        guard let data = markdown.data(using: .utf8) else {
            throw LociError.coordinationFailed("utf8 encode failed for template \(template.id)")
        }
        try await vault.writeFile(data, atRelativePath: Self.templateRelativePath(for: template.id))
        if !type.templateIDs.contains(template.id) {
            type.templateIDs.append(template.id)
            type.templateIDs.sort()
            try await saveType(type)
        }
        return template
    }

    @discardableResult
    public func createTemplate(
        typeID: ObjectTypeID,
        name: String,
        bodyMarkdown: String = "",
        defaultProperties: [String: PropertyValue] = [:],
        slug: String? = nil,
        makeDefault: Bool = false
    ) async throws -> ObjectTemplate {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LociError.invalidTemplateID("(empty name)")
        }
        _ = try await loadType(typeID)
        let id = try TemplateID.make(typeID: typeID, name: trimmed, explicitSlug: slug)
        if try await vault.fileExists(atRelativePath: Self.templateRelativePath(for: id)) {
            throw LociError.templateAlreadyExists(id)
        }
        let template = ObjectTemplate(
            id: id,
            typeID: typeID,
            name: trimmed,
            bodyMarkdown: bodyMarkdown,
            defaultProperties: defaultProperties
        )
        _ = try await saveTemplate(template)
        if makeDefault {
            _ = try await setDefaultTemplate(typeID: typeID, templateID: id)
        }
        return template
    }

    public func deleteTemplate(_ id: String) async throws {
        let path = Self.templateRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.templateNotFound(id)
        }
        // Prefer typeID from file; fall back to id prefix.
        let typeID: ObjectTypeID
        if let loaded = try? await loadTemplate(id) {
            typeID = loaded.typeID
        } else if let prefix = id.split(separator: ".", maxSplits: 1).first {
            typeID = ObjectTypeID(String(prefix))
        } else {
            throw LociError.invalidTemplateID(id)
        }
        try await vault.deleteFile(atRelativePath: path)
        if var type = try? await loadType(typeID) {
            type.templateIDs.removeAll { $0 == id }
            if type.defaultTemplateID == id {
                type.defaultTemplateID = nil
            }
            try await saveType(type)
        }
    }

    @discardableResult
    public func setDefaultTemplate(typeID: ObjectTypeID, templateID: String?) async throws
        -> ObjectType
    {
        var type = try await loadType(typeID)
        if let templateID {
            guard TemplateID.isValid(templateID) else {
                throw LociError.invalidTemplateID(templateID)
            }
            let template = try await loadTemplate(templateID)
            guard template.typeID == typeID else {
                throw LociError.invalidTemplateID(templateID)
            }
            if !type.templateIDs.contains(templateID) {
                type.templateIDs.append(templateID)
                type.templateIDs.sort()
            }
            type.defaultTemplateID = templateID
        } else {
            type.defaultTemplateID = nil
        }
        try await saveType(type)
        return type
    }

    public func defaultTemplate(for typeID: ObjectTypeID) async throws -> ObjectTemplate? {
        let type = try await loadType(typeID)
        guard let id = type.defaultTemplateID else { return nil }
        return try await loadTemplate(id)
    }

    // MARK: - Collections (PR22)

    public func listCollections(typeID: ObjectTypeID) async throws -> [ObjectCollection] {
        _ = try await loadType(typeID)
        let ids = try await listCollectionFileIDs()
        var result: [ObjectCollection] = []
        let prefix = "\(typeID.rawValue)."
        for fileID in ids where fileID.hasPrefix(prefix) {
            if let collection = try? await loadCollection(fileID), collection.typeID == typeID {
                result.append(collection)
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    public func loadCollection(_ id: String) async throws -> ObjectCollection {
        let path = Self.collectionRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.collectionNotFound(id)
        }
        let data = try await vault.readFile(atRelativePath: path)
        do {
            return try decoder.decode(ObjectCollection.self, from: data)
        } catch {
            throw LociError.collectionNotFound(id)
        }
    }

    @discardableResult
    public func saveCollection(_ collection: ObjectCollection) async throws -> ObjectCollection {
        guard CollectionID.isValid(collection.id) else {
            throw LociError.invalidCollectionID(collection.id)
        }
        _ = try await loadType(collection.typeID)
        var stored = collection
        stored.updatedAt = Date()
        let data = try encoder.encode(stored)
        try await vault.writeFile(data, atRelativePath: Self.collectionRelativePath(for: stored.id))
        return stored
    }

    @discardableResult
    public func createCollection(
        typeID: ObjectTypeID,
        name: String,
        slug: String? = nil
    ) async throws -> ObjectCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LociError.invalidCollectionID("(empty name)")
        }
        _ = try await loadType(typeID)
        let id = try CollectionID.make(typeID: typeID, name: trimmed, explicitSlug: slug)
        if try await vault.fileExists(atRelativePath: Self.collectionRelativePath(for: id)) {
            throw LociError.collectionAlreadyExists(id)
        }
        let collection = ObjectCollection(
            id: id,
            typeID: typeID,
            name: trimmed,
            memberIDs: []
        )
        return try await saveCollection(collection)
    }

    public func deleteCollection(_ id: String) async throws {
        let path = Self.collectionRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.collectionNotFound(id)
        }
        try await vault.deleteFile(atRelativePath: path)
    }

    @discardableResult
    public func addToCollection(_ collectionID: String, objectID: ObjectID) async throws
        -> ObjectCollection
    {
        var collection = try await loadCollection(collectionID)
        if !collection.memberIDs.contains(objectID) {
            collection.memberIDs.append(objectID)
            collection = try await saveCollection(collection)
        }
        return collection
    }

    @discardableResult
    public func removeFromCollection(_ collectionID: String, objectID: ObjectID) async throws
        -> ObjectCollection
    {
        var collection = try await loadCollection(collectionID)
        let before = collection.memberIDs.count
        collection.memberIDs.removeAll { $0 == objectID }
        guard collection.memberIDs.count < before else {
            throw LociError.collectionMemberNotFound(objectID.frontMatterIDString)
        }
        return try await saveCollection(collection)
    }

    // MARK: - Saved queries (PR23)

    public func listQueries() async throws -> [SavedQuery] {
        let ids = try await listQueryFileIDs()
        var result: [SavedQuery] = []
        for fileID in ids {
            if let query = try? await loadQuery(fileID) {
                result.append(query)
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    public func listPinnedQueries(typeID: ObjectTypeID) async throws -> [SavedQuery] {
        let all = try await listQueries()
        return all.filter { $0.pinnedTypeID == typeID }
    }

    public func loadQuery(_ id: String) async throws -> SavedQuery {
        let path = Self.queryRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.queryNotFound(id)
        }
        let data = try await vault.readFile(atRelativePath: path)
        do {
            return try decoder.decode(SavedQuery.self, from: data)
        } catch {
            throw LociError.queryNotFound(id)
        }
    }

    @discardableResult
    public func saveQuery(_ query: SavedQuery) async throws -> SavedQuery {
        guard QueryID.isValid(query.id) else {
            throw LociError.invalidQueryID(query.id)
        }
        if let pinned = query.pinnedTypeID {
            _ = try await loadType(pinned)
        }
        var stored = query
        stored.updatedAt = Date()
        let data = try encoder.encode(stored)
        try await vault.writeFile(data, atRelativePath: Self.queryRelativePath(for: stored.id))
        return stored
    }

    @discardableResult
    public func createQuery(
        name: String,
        definition: QueryDefinition,
        slug: String? = nil,
        pinnedTypeID: ObjectTypeID? = nil
    ) async throws -> SavedQuery {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LociError.invalidQueryID("(empty name)")
        }
        if let pinnedTypeID {
            _ = try await loadType(pinnedTypeID)
        }
        let id = try QueryID.make(name: trimmed, explicitSlug: slug)
        if try await vault.fileExists(atRelativePath: Self.queryRelativePath(for: id)) {
            throw LociError.queryAlreadyExists(id)
        }
        let query = SavedQuery(
            id: id,
            name: trimmed,
            definition: definition,
            pinnedTypeID: pinnedTypeID
        )
        return try await saveQuery(query)
    }

    public func deleteQuery(_ id: String) async throws {
        let path = Self.queryRelativePath(for: id)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.queryNotFound(id)
        }
        try await vault.deleteFile(atRelativePath: path)
    }

    @discardableResult
    public func setQueryPinned(_ id: String, typeID: ObjectTypeID?) async throws -> SavedQuery {
        var query = try await loadQuery(id)
        if let typeID {
            _ = try await loadType(typeID)
        }
        query.pinnedTypeID = typeID
        return try await saveQuery(query)
    }

    // MARK: - Paths

    public static func typeRelativePath(for id: ObjectTypeID) -> String {
        "\(VaultLayout.typesDirectory)/\(id.rawValue).json"
    }

    public static func templateRelativePath(for id: String) -> String {
        "\(VaultLayout.templatesDirectory)/\(id).md"
    }

    public static func collectionRelativePath(for id: String) -> String {
        "\(VaultLayout.collectionsDirectory)/\(id).json"
    }

    public static func queryRelativePath(for id: String) -> String {
        "\(VaultLayout.queriesDirectory)/\(id).json"
    }

    public static func objectsFolderRelativePath(for id: ObjectTypeID) -> String {
        "\(VaultLayout.objectsDirectory)/\(id.rawValue)"
    }

    public func ensureObjectsFolder(for id: ObjectTypeID) async throws {
        let root = try await vault.vaultRootURL
        let url = root.appendingPathComponent(
            Self.objectsFolderRelativePath(for: id),
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func countObjectMarkdown(for id: ObjectTypeID) async throws -> Int {
        let root = try await vault.vaultRootURL
        let folder = root.appendingPathComponent(
            Self.objectsFolderRelativePath(for: id),
            isDirectory: true
        )
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir),
            isDir.boolValue
        else {
            return 0
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls.filter { $0.pathExtension.lowercased() == "md" }.count
    }

    private func listTypeFileSlugs() async throws -> [String] {
        let root = try await vault.vaultRootURL
        let typesURL = root.appendingPathComponent(VaultLayout.typesDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: typesURL.path, isDirectory: &isDir),
            isDir.boolValue
        else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: typesURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    private func listTemplateFileIDs() async throws -> [String] {
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(VaultLayout.templatesDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir),
            isDir.boolValue
        else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    private func listCollectionFileIDs() async throws -> [String] {
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(VaultLayout.collectionsDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir),
            isDir.boolValue
        else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    private func listQueryFileIDs() async throws -> [String] {
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(VaultLayout.queriesDirectory, isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir),
            isDir.boolValue
        else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}
