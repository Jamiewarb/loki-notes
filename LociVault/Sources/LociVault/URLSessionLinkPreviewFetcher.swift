import Foundation
import LociCore

/// Production HTML fetch for weblink previews (PR43).
///
/// Apple: URLSession GET, http(s) only, request timeout, ~1MB size cap.
/// Linux: scheme check only — live fetch is Apple; tests inject `FakeLinkPreviewFetcher`.
public struct URLSessionLinkPreviewFetcher: LinkPreviewFetching, Sendable {
    public var timeout: TimeInterval
    public var maxBytes: Int

    public init(
        timeout: TimeInterval = 10,
        maxBytes: Int = LinkPreviewNotes.maxBytes
    ) {
        self.timeout = timeout
        self.maxBytes = maxBytes
    }

    public func fetchHTML(from url: URL) async throws -> String {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw LociError.linkPreviewUnsupportedScheme(url.absoluteString)
        }
        #if os(macOS) || os(iOS)
        return try await Self.sessionFetch(url: url, timeout: timeout, maxBytes: maxBytes)
        #else
        throw LociError.linkPreviewFetchFailed(
            "URLSession fetch is Apple-only; use FakeLinkPreviewFetcher on Linux"
        )
        #endif
    }

    #if os(macOS) || os(iOS)
    private static func sessionFetch(
        url: URL,
        timeout: TimeInterval,
        maxBytes: Int
    ) async throws -> String {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpMaximumConnectionsPerHost = 2
        let session = URLSession(configuration: config)
        let (data, _) = try await session.data(from: url)
        let clipped = data.prefix(maxBytes)
        if let utf8 = String(data: clipped, encoding: .utf8) {
            return utf8
        }
        return String(data: clipped, encoding: .isoLatin1) ?? ""
    }
    #endif
}

/// Apple → URLSession; Linux / tests → fixture fake (no live network).
public enum LinkPreviewFetcherFactory: Sendable {
    public static func makeFetcher() -> any LinkPreviewFetching {
        #if os(macOS) || os(iOS)
        return URLSessionLinkPreviewFetcher()
        #else
        return FakeLinkPreviewFetcher.withOpenGraphFixtures()
        #endif
    }

    public static var usesURLSession: Bool {
        #if os(macOS) || os(iOS)
        true
        #else
        false
        #endif
    }
}
