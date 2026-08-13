import Foundation
import LociCore

/// Concrete `VaultServing` — coordinated I/O against a resolved `VaultRoot`.
/// Never creates SQLite / index files inside the vault.
public final class VaultService: VaultServing, @unchecked Sendable {
    private let root: VaultRoot
    private let coordinator: FileCoordinatorClient
    private let monitor: MetadataQueryMonitor
    private let lock = NSLock()

    public init(
        root: VaultRoot,
        coordinator: FileCoordinatorClient = FileCoordinatorClient(),
        monitor: MetadataQueryMonitor? = nil
    ) {
        self.root = root
        self.coordinator = coordinator
        self.monitor = monitor ?? MetadataQueryMonitor(root: root.url)
    }

    /// Convenience: resolve root (local fallback unless ubiquity is available).
    public convenience init(
        preferredLocalDirectory: URL? = nil,
        forceLocal: Bool = false
    ) throws {
        let resolved = try VaultRoot.resolve(
            preferredLocalDirectory: preferredLocalDirectory,
            forceLocal: forceLocal
        )
        self.init(root: resolved)
    }

    public var vaultRootURL: URL {
        get async throws { root.url }
    }

    public var rootKind: VaultRootKind {
        get async { root.kind }
    }

    /// Expose monitor for AppServices / SyncStatus wiring.
    public var fileMonitor: MetadataQueryMonitor { monitor }

    public var resolvedRoot: VaultRoot { root }

    public func ensureSkeleton(spaceName: String = "Loci") async throws {
        for dir in VaultLayout.requiredDirectories {
            let url = try absoluteURLSync(forRelativePath: dir)
            try coordinator.createDirectory(at: url)
        }

        let spaceURL = try absoluteURLSync(forRelativePath: VaultLayout.spaceJSON)
        if !coordinator.fileExists(at: spaceURL) {
            let settings = SpaceSettings(name: spaceName, schemaVersion: 1)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try coordinator.writeData(data, to: spaceURL)
            monitor.noteLocalWrite(relativePath: VaultLayout.spaceJSON, kind: .created)
        }

        // Seed built-in Page + Daily + Image types (merge-friendly per-type files). Idempotent.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for type in [ObjectType.builtInPage, ObjectType.builtInDaily, ObjectType.builtInImage] {
            let relative = SchemaStore.typeRelativePath(for: type.id)
            let url = try absoluteURLSync(forRelativePath: relative)
            if !coordinator.fileExists(at: url) {
                let data = try encoder.encode(type)
                try coordinator.writeData(data, to: url)
                monitor.noteLocalWrite(relativePath: relative, kind: .created)
            }
        }
    }

    public func readFile(atRelativePath path: String) async throws -> Data {
        let url = try absoluteURLSync(forRelativePath: path)
        guard coordinator.fileExists(at: url) else {
            throw LociError.fileNotFound(path)
        }
        return try coordinator.readData(at: url)
    }

    public func writeFile(_ data: Data, atRelativePath path: String) async throws {
        let url = try absoluteURLSync(forRelativePath: path)
        let existed = coordinator.fileExists(at: url)
        try coordinator.writeData(data, to: url)
        monitor.noteLocalWrite(
            relativePath: normalizeRelativePath(path),
            kind: existed ? .modified : .created
        )
    }

    public func deleteFile(atRelativePath path: String) async throws {
        let url = try absoluteURLSync(forRelativePath: path)
        guard coordinator.fileExists(at: url) else {
            throw LociError.fileNotFound(path)
        }
        try coordinator.removeItem(at: url)
        monitor.noteLocalWrite(relativePath: normalizeRelativePath(path), kind: .deleted)
    }

    public func moveFile(fromRelativePath source: String, toRelativePath destination: String)
        async throws
    {
        let from = normalizeRelativePath(source)
        let to = normalizeRelativePath(destination)
        guard from != to else { return }
        let sourceURL = try absoluteURLSync(forRelativePath: from)
        guard coordinator.fileExists(at: sourceURL) else {
            throw LociError.fileNotFound(from)
        }
        let destURL = try absoluteURLSync(forRelativePath: to)
        try coordinator.moveItem(from: sourceURL, to: destURL)
        monitor.noteLocalWrite(relativePath: from, kind: .deleted)
        monitor.noteLocalWrite(relativePath: to, kind: .created)
    }

    public func fileExists(atRelativePath path: String) async throws -> Bool {
        let url = try absoluteURLSync(forRelativePath: path)
        return coordinator.fileExists(at: url)
    }

    public func putMedia(
        _ data: Data,
        kind: MediaKind,
        preferredFileName: String
    ) async throws -> MediaAttachment {
        try await MediaStore.put(
            data: data,
            kind: kind,
            preferredFileName: preferredFileName,
            vault: self
        )
    }

    @discardableResult
    public func trashFile(atRelativePath path: String, objectID: ObjectID? = nil) async throws
        -> TombstoneRecord
    {
        let normalized = normalizeRelativePath(path)
        let source = try absoluteURLSync(forRelativePath: normalized)
        guard coordinator.fileExists(at: source) else {
            throw LociError.fileNotFound(normalized)
        }

        let stamp = Int(Date().timeIntervalSince1970)
        let base = (normalized as NSString).lastPathComponent
        let trashedRelative = "\(VaultLayout.trashDirectory)/\(stamp)-\(base)"
        let destination = try absoluteURLSync(forRelativePath: trashedRelative)

        try coordinator.moveItem(from: source, to: destination)

        let record = TombstoneRecord(
            originalRelativePath: normalized,
            trashedRelativePath: trashedRelative,
            trashedAt: Date(),
            objectID: objectID?.uuidString.lowercased()
        )
        let store = TombstoneStore(root: root.url, coordinator: coordinator)
        try store.write(record)

        monitor.noteLocalWrite(relativePath: normalized, kind: .deleted)
        monitor.noteLocalWrite(relativePath: trashedRelative, kind: .created)
        return record
    }

    public func absoluteURL(forRelativePath path: String) async throws -> URL {
        try absoluteURLSync(forRelativePath: path)
    }

    public func ensureDownloaded(atRelativePath path: String) async throws {
        let url = try absoluteURLSync(forRelativePath: path)
        // Local roots: no-op. Ubiquity: Apple stub via DownloadOnDemand.
        if root.kind == .localDocuments {
            return
        }
        try DownloadOnDemand.ensureDownloaded(at: url)
    }

    public func listConflictedCopies() async throws -> [SyncConflictItem] {
        ConflictScanner.listConflictedCopies(under: root.url)
    }

    // MARK: - Path helpers

    private func absoluteURLSync(forRelativePath path: String) throws -> URL {
        let normalized = normalizeRelativePath(path)
        if normalized.contains("..") {
            throw LociError.invalidRelativePath(path)
        }
        let url = root.url.appendingPathComponent(normalized)
        let standardized = url.standardizedFileURL
        let rootPath = root.url.standardizedFileURL.path
        guard standardized.path == rootPath || standardized.path.hasPrefix(rootPath + "/") else {
            throw LociError.pathOutsideVault(path)
        }
        return standardized
    }

    private func normalizeRelativePath(_ path: String) -> String {
        var p = path
        while p.hasPrefix("/") {
            p.removeFirst()
        }
        return p
    }
}
