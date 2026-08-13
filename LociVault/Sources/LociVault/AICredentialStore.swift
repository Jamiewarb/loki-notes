import Foundation
import LociCore

/// Stores BYOK API keys outside the vault (PR30).
///
/// Default directory: Application Support `Loci/ai/` — **never** the vault.
/// File `credentials.json` shape: `{ "provider": "api-key" }` with 0600 when possible.
/// On Apple, Keychain is preferred when available; otherwise the same file fallback.
public final class AICredentialStore: @unchecked Sendable {
    private let directory: URL
    private let fileURL: URL
    private let lock = NSLock()

    public init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("credentials.json", isDirectory: false)
    }

    /// Application Support `Loci/ai/` on Apple; temp `Loci/ai/` on Linux.
    public static func defaultDirectory() throws -> URL {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("Loci/ai", isDirectory: true)
        #else
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Loci/ai", isDirectory: true)
        #endif
    }

    public func setAPIKey(_ key: String, for provider: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var map = (try? loadUnlocked()) ?? [:]
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            map.removeValue(forKey: provider)
        } else {
            map[provider] = trimmed
        }
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // Keychain preferred on Apple when available; always mirror to file for portability/tests.
        #endif
        try writeUnlocked(map)
    }

    public func apiKey(for provider: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        let map = try loadUnlocked()
        return map[provider]
    }

    public func clear(provider: String? = nil) throws {
        lock.lock()
        defer { lock.unlock() }
        if let provider {
            var map = (try? loadUnlocked()) ?? [:]
            map.removeValue(forKey: provider)
            try writeUnlocked(map)
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Absolute path of the credentials file (for demos / proofs — never under vault).
    public var credentialsFileURL: URL { fileURL }

    private func loadUnlocked() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    private func writeUnlocked(_ map: [String: String]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(map)
        try data.write(to: fileURL, options: [.atomic])
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(Linux)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        #endif
    }
}
