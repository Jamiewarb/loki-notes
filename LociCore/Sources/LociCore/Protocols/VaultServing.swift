import Foundation

/// Coordinated vault file I/O. Implementations live in LociVault (PR04).
/// Always support a local Documents fallback — never require iCloud for features/tests.
public protocol VaultServing: Sendable {
    /// Root URL of the active vault (iCloud ubiquity or local fallback).
    var vaultRootURL: URL { get async throws }

    func readFile(atRelativePath path: String) async throws -> Data
    func writeFile(_ data: Data, atRelativePath path: String) async throws
    func deleteFile(atRelativePath path: String) async throws
    func fileExists(atRelativePath path: String) async throws -> Bool
}
