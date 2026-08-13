import Foundation
import LociCore

/// Observes vault file changes and emits `VaultFileEvent`s for the indexer (PR07).
///
/// - Apple ubiquity roots: structured `NSMetadataQuery` hooks (start/stop + reconcile).
/// - Linux / local Documents: polling snapshot + `noteLocalWrite` for in-process updates.
public final class MetadataQueryMonitor: @unchecked Sendable {
    public typealias EventHandler = @Sendable (VaultFileEvent) -> Void

    private let root: URL
    private let pollInterval: TimeInterval
    private var handler: EventHandler?
    private var knownPaths: Set<String> = []
    private var timer: Timer?
    private let lock = NSLock()
    private var running = false
    private var observerTokens: [NSObjectProtocol] = []

    #if canImport(Darwin)
    private var metadataQuery: NSMetadataQuery?
    #endif

    public init(root: URL, pollInterval: TimeInterval = 0.4) {
        self.root = root.standardizedFileURL
        self.pollInterval = pollInterval
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    /// Begin observing. Keep `onEvent` light — parse/index off the callback.
    public func start(onEvent: @escaping EventHandler) {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { return }
        handler = onEvent
        running = true
        knownPaths = Self.snapshotRelativePaths(under: root)

        #if canImport(Darwin)
        if startMetadataQueryIfPossible() {
            return
        }
        #endif
        startPollingLocked()
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        running = false
        handler = nil
        timer?.invalidate()
        timer = nil
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
        observerTokens.removeAll()
        #if canImport(Darwin)
        stopMetadataQuery()
        #endif
    }

    /// Force a local poll pass (tests / Linux).
    public func pollNow() {
        lock.lock()
        let rootURL = root
        let previous = knownPaths
        let current = Self.snapshotRelativePaths(under: rootURL)
        knownPaths = current
        let callback = handler
        lock.unlock()

        guard let callback else { return }
        let created = current.subtracting(previous)
        let deleted = previous.subtracting(current)
        for path in created.sorted() {
            callback(
                VaultFileEvent(
                    relativePath: path,
                    kind: .created,
                    isConflictedCopy: ConflictedCopyDetector.isConflictedCopy(pathOrFilename: path)
                )
            )
        }
        for path in deleted.sorted() {
            callback(VaultFileEvent(relativePath: path, kind: .deleted, isConflictedCopy: false))
        }
    }

    /// Notify monitor of an in-process write so listeners stay coherent without waiting for poll.
    public func noteLocalWrite(relativePath: String, kind: VaultEventKind) {
        lock.lock()
        switch kind {
        case .created, .modified, .renamed:
            knownPaths.insert(relativePath)
        case .deleted:
            knownPaths.remove(relativePath)
        }
        let callback = handler
        lock.unlock()
        callback?(
            VaultFileEvent(
                relativePath: relativePath,
                kind: kind,
                isConflictedCopy: ConflictedCopyDetector.isConflictedCopy(pathOrFilename: relativePath)
            )
        )
    }

    // MARK: - Local polling

    private func startPollingLocked() {
        let interval = pollInterval
        if Thread.isMainThread {
            let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.pollNow()
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    static func snapshotRelativePaths(under root: URL) -> Set<String> {
        var result = Set<String>()
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
            )
        else {
            return result
        }
        let rootPath = root.standardizedFileURL.path
        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            let path = fileURL.standardizedFileURL.path
            guard path.hasPrefix(rootPath) else { continue }
            var relative = String(path.dropFirst(rootPath.count))
            if relative.hasPrefix("/") {
                relative.removeFirst()
            }
            if !relative.isEmpty {
                result.insert(relative)
            }
        }
        return result
    }

    // MARK: - NSMetadataQuery (Apple)

    #if canImport(Darwin)
    @discardableResult
    private func startMetadataQueryIfPossible() -> Bool {
        let path = root.path
        guard path.contains("Mobile Documents") || path.contains("com~apple~CloudDocs") else {
            return false
        }
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")

        let center = NotificationCenter.default
        let tokenUpdate = center.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.handleMetadataUpdate()
        }
        let tokenGather = center.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.handleMetadataUpdate()
        }
        observerTokens.append(contentsOf: [tokenUpdate, tokenGather])
        metadataQuery = query
        query.start()
        return true
    }

    private func stopMetadataQuery() {
        metadataQuery?.stop()
        metadataQuery = nil
    }

    private func handleMetadataUpdate() {
        // Disable updates while iterating (Apple guidance).
        guard let query = metadataQuery else {
            pollNow()
            return
        }
        query.disableUpdates()
        defer { query.enableUpdates() }
        pollNow()
    }
    #endif
}
