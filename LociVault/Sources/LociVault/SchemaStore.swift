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

    /// Ensure vault skeleton directories + `space.json`, then seed built-in **Page** if missing.
    public func bootstrapSchema(spaceName: String = "Loci") async throws {
        try await vault.ensureSkeleton(spaceName: spaceName)
        try await seedBuiltInPageIfNeeded()
    }

    /// Write `page.json` when absent (idempotent). Safe to call after `ensureSkeleton`.
    public func seedBuiltInPageIfNeeded() async throws {
        let path = Self.typeRelativePath(for: .page)
        if try await vault.fileExists(atRelativePath: path) {
            return
        }
        try await saveType(.builtInPage)
    }

    // MARK: - Paths

    public static func typeRelativePath(for id: ObjectTypeID) -> String {
        "\(VaultLayout.typesDirectory)/\(id.rawValue).json"
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
