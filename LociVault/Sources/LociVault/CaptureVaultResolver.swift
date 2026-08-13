import Foundation
import LociCore

/// Resolve a vault for Share / Widget / Safari / menu-bar processes (PR37 / PR38).
///
/// Same policy as `AppServices`: prefer ubiquity, then local Documents.
/// Never crashes — returns `nil` when both roots fail so the extension can
/// show a short error instead of aborting. Does **not** open SQLite.
public enum CaptureVaultResolver: Sendable {
    /// Best-effort vault for an extension process (no index).
    public static func resolve() -> VaultService? {
        if let vault = try? VaultService(forceLocal: false) {
            return vault
        }
        return try? VaultService(forceLocal: true)
    }

    /// Test / harness override: local Documents under `preferredLocalDirectory`.
    public static func resolve(
        preferredLocalDirectory: URL?,
        forceLocal: Bool = true
    ) -> VaultService? {
        if let preferred = preferredLocalDirectory {
            return try? VaultService(preferredLocalDirectory: preferred, forceLocal: true)
        }
        if !forceLocal, let vault = try? VaultService(forceLocal: false) {
            return vault
        }
        return try? VaultService(forceLocal: true)
    }
}
