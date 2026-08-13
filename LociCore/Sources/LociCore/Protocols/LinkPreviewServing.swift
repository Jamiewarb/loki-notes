import Foundation

/// Weblink Open Graph preview cache (PR43).
///
/// Fetch on weblink object open, after create when a `url` is present, or an
/// explicit “Refresh preview” tap. **Never** on editor typing debounce.
/// Cache lives in Application Support next to the index — never in the vault.
/// Failures surface as an empty `LinkPreview` placeholder; callers must not
/// rewrite markdown.
public protocol LinkPreviewServing: Sendable {
    func preview(for url: URL) async throws -> LinkPreview
    /// Bypass cache and GET the URL again (Refresh preview).
    func refresh(for url: URL) async throws -> LinkPreview
}

/// Transport that returns HTML for a URL. Apple uses URLSession; Linux/tests
/// inject `FakeLinkPreviewFetcher` with fixture HTML — no live network in XCTest.
public protocol LinkPreviewFetching: Sendable {
    func fetchHTML(from url: URL) async throws -> String
}
