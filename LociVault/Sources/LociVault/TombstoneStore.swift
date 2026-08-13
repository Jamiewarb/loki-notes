import Foundation
import LociCore

/// Writes / reads tombstone manifests under `.loci/trash/` for soft deletes.
public struct TombstoneStore: Sendable {
    private let root: URL
    private let coordinator: FileCoordinatorClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(root: URL, coordinator: FileCoordinatorClient = FileCoordinatorClient()) {
        self.root = root.standardizedFileURL
        self.coordinator = coordinator
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public var trashDirectoryURL: URL {
        root.appendingPathComponent(VaultLayout.trashDirectory, isDirectory: true)
    }

    /// Persist a tombstone JSON next to the trashed payload.
    public func write(_ record: TombstoneRecord) throws {
        let url = trashDirectoryURL
            .appendingPathComponent(Self.manifestName(for: record), isDirectory: false)
        let data = try encoder.encode(record)
        try coordinator.writeData(data, to: url)
    }

    public func read(manifestURL: URL) throws -> TombstoneRecord {
        let data = try coordinator.readData(at: manifestURL)
        return try decoder.decode(TombstoneRecord.self, from: data)
    }

    /// List tombstone manifests currently in trash.
    public func listManifests() throws -> [TombstoneRecord] {
        let trash = trashDirectoryURL
        guard coordinator.fileExists(at: trash) else { return [] }
        let contents = try FileManager.default.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return try contents
            .filter { $0.pathExtension == "tombstone" }
            .map { try read(manifestURL: $0) }
    }

    public static func manifestName(for record: TombstoneRecord) -> String {
        let stamp = Int(record.trashedAt.timeIntervalSince1970)
        let base = (record.originalRelativePath as NSString).lastPathComponent
        return "\(stamp)-\(base).tombstone"
    }
}
