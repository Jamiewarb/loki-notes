import Foundation

/// Linux / XCTest HTML fetcher (PR43). Returns fixture HTML — **no live network**.
public final class FakeLinkPreviewFetcher: LinkPreviewFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var htmlByURL: [String: String]
    private var failing: Set<String>
    public private(set) var fetchCount: Int = 0
    public private(set) var fetchedURLs: [String] = []

    public init(
        htmlByURL: [URL: String] = [:],
        failing: Set<URL> = []
    ) {
        self.htmlByURL = Dictionary(
            uniqueKeysWithValues: htmlByURL.map { ($0.absoluteString, $1) }
        )
        self.failing = Set(failing.map(\.absoluteString))
    }

    /// Default fixtures used by Linux AppServices / demos.
    public static func withOpenGraphFixtures() -> FakeLinkPreviewFetcher {
        FakeLinkPreviewFetcher(htmlByURL: [
            OpenGraphFixtures.articleURL: OpenGraphFixtures.articleHTML,
            OpenGraphFixtures.weblinkURL: OpenGraphFixtures.articleHTML,
        ])
    }

    public func fetchHTML(from url: URL) async throws -> String {
        try fetchHTMLSync(from: url)
    }

    private func fetchHTMLSync(from url: URL) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        fetchCount += 1
        fetchedURLs.append(url.absoluteString)
        let key = url.absoluteString
        if failing.contains(key) {
            throw LociError.linkPreviewFetchFailed(key)
        }
        if let html = htmlByURL[key] {
            return html
        }
        throw LociError.linkPreviewFetchFailed(key)
    }

    public func setHTML(_ html: String, for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        htmlByURL[url.absoluteString] = html
    }

    public func setFailing(_ url: URL, failing shouldFail: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if shouldFail {
            failing.insert(url.absoluteString)
        } else {
            failing.remove(url.absoluteString)
        }
    }

    public func resetFetchCount() {
        lock.lock()
        defer { lock.unlock() }
        fetchCount = 0
        fetchedURLs = []
    }
}
