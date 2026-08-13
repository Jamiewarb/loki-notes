import Foundation
import GRDB

/// Owns the on-disk SQLite path for one vault’s local index.
///
/// Path shape: `<directory>/<vaultID>/index.sqlite`
/// - `directory` is Application Support/`Loci` on device, or a temp folder in tests.
/// - **Never** pass the vault root as `directory`.
public struct IndexDatabase: Sendable {
    public let vaultID: String
    public let directory: URL

    public init(vaultID: String, directory: URL) {
        self.vaultID = vaultID
        self.directory = directory
    }

    /// Parent folder for this vault’s index files (`…/Loci/<vaultID>/`).
    public var vaultIndexDirectory: URL {
        directory.appendingPathComponent(vaultID, isDirectory: true)
    }

    public var databaseURL: URL {
        vaultIndexDirectory.appendingPathComponent(LociIndexModule.databaseFileName, isDirectory: false)
    }

    /// Creates the index directory if needed and opens a `DatabaseQueue`.
    public func open() throws -> DatabaseQueue {
        try FileManager.default.createDirectory(
            at: vaultIndexDirectory,
            withIntermediateDirectories: true
        )
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let queue = try DatabaseQueue(path: databaseURL.path, configuration: config)
        try IndexSchema.migrate(queue)
        return queue
    }

    /// Stable vault id derived from the vault root URL (path hash) — not persisted identity of objects.
    public static func vaultID(forVaultRoot root: URL) -> String {
        let path = root.standardizedFileURL.path
        var hash: UInt64 = 5381
        for byte in path.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "v%016llx", hash)
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    /// Default Application Support container for Loci indexes (Apple platforms).
    public static func defaultApplicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent(
            LociIndexModule.applicationSupportSubdirectory,
            isDirectory: true
        )
    }
    #endif
}
