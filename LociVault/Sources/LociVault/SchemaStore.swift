import Foundation
import LociCore

/// Loads/saves `.loci/space.json` and per-type `.loci/types/<slug>.json` via `VaultServing`.
/// Merge-friendly: one type per file — never a monolithic schema.json.
public final class SchemaStore: SchemaServing, @unchecked Sendable {
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

    /// Ensure vault skeleton directories + `space.json`, then seed built-in **Page** + **Daily**.
    public func bootstrapSchema(spaceName: String = "Loci") async throws {
        try await vault.ensureSkeleton(spaceName: spaceName)
        try await seedBuiltInPageIfNeeded()
        try await seedBuiltInDailyIfNeeded()
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

    // MARK: - Paths

    public static func typeRelativePath(for id: ObjectTypeID) -> String {
        "\(VaultLayout.typesDirectory)/\(id.rawValue).json"
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
}
