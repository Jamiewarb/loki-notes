import Foundation
import LociCore

/// Disposable weblink preview cache next to the index (PR43).
///
/// JSON file `previews.json` under the caller-provided directory (Application Support
/// / temp in tests). **Never** pass the vault root. Derived OG data is cache-only so
/// it does not churn iCloud markdown.
public final class LinkPreviewService: LinkPreviewServing, @unchecked Sendable {
    private let lock = NSLock()
    private var cacheDirectory: URL
    private let fetcher: any LinkPreviewFetching
    private var memory: [String: LinkPreview] = [:]

    public init(cacheDirectory: URL, fetcher: any LinkPreviewFetching) {
        self.cacheDirectory = cacheDirectory
        self.fetcher = fetcher
        self.memory = (try? Self.loadFile(at: Self.cacheFile(in: cacheDirectory))) ?? [:]
    }

    public var cacheDirectoryURL: URL {
        lock.lock()
        defer { lock.unlock() }
        return cacheDirectory
    }

    public var cacheFileURL: URL {
        lock.lock()
        defer { lock.unlock() }
        return Self.cacheFile(in: cacheDirectory)
    }

    /// Point the cache at the vault's index folder (still Application Support / temp).
    public func setCacheDirectory(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        cacheDirectory = url
        if let disk = try? Self.loadFile(at: Self.cacheFile(in: url)) {
            for (key, value) in disk {
                memory[key] = value
            }
        }
    }

    public func preview(for url: URL) async throws -> LinkPreview {
        guard isHTTP(url) else {
            return .placeholder(sourceURL: url)
        }
        let key = url.absoluteString
        if let cached = cachedPreview(key: key) {
            return cached
        }
        return await fetchAndStore(url)
    }

    public func refresh(for url: URL) async throws -> LinkPreview {
        guard isHTTP(url) else {
            return .placeholder(sourceURL: url)
        }
        return await fetchAndStore(url)
    }

    // MARK: - Internals

    private func cachedPreview(key: String) -> LinkPreview? {
        lock.lock()
        defer { lock.unlock() }
        return memory[key]
    }

    private func fetchAndStore(_ url: URL) async -> LinkPreview {
        do {
            let html = try await fetcher.fetchHTML(from: url)
            let preview = OpenGraphHTMLParser.parse(html, sourceURL: url)
            store(preview)
            return preview
        } catch {
            let placeholder = LinkPreview.placeholder(sourceURL: url)
            // Do not cache failures so Refresh can retry.
            return placeholder
        }
    }

    private func store(_ preview: LinkPreview) {
        lock.lock()
        defer { lock.unlock() }
        memory[preview.sourceURL.absoluteString] = preview
        let snapshot = memory
        let file = Self.cacheFile(in: cacheDirectory)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
        try? Self.writeFile(snapshot, to: file)
    }

    private func isHTTP(_ url: URL) -> Bool {
        WeblinkURL.parseHTTP(url.absoluteString) != nil
    }

    private static func cacheFile(in directory: URL) -> URL {
        directory.appendingPathComponent("previews.json", isDirectory: false)
    }

    private static func loadFile(at url: URL) throws -> [String: LinkPreview] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: LinkPreview].self, from: data)
    }

    private static func writeFile(_ map: [String: LinkPreview], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(map)
        try data.write(to: url, options: [.atomic])
    }
}
