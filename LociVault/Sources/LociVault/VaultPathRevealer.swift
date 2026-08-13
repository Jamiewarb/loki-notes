import Foundation
import LociCore

/// Reveal vault path in Finder / Files, or return the path string (all platforms). PR21.
public enum VaultPathRevealer: Sendable {
    /// Reveal `url` in the platform file browser when possible; always returns the path string.
    @discardableResult
    public static func reveal(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        #if os(macOS)
        // NSWorkspace is AppKit — keep Foundation-only reveal via `open` for SPM purity.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-R", path]
        try? process.run()
        #elseif os(iOS)
        // Files app deep-link is entitlement-sensitive; Settings shows the path instead.
        #endif
        return path
    }
}
