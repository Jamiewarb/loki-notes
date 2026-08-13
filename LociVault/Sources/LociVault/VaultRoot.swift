import Foundation
import LociCore

/// Resolves the active vault root: prefer iCloud ubiquity when available, else local Documents.
/// Linux / CI always use a local directory (tests pass a temp URL).
public struct VaultRoot: Sendable, Equatable {
    public let url: URL
    public let kind: VaultRootKind

    public init(url: URL, kind: VaultRootKind) {
        self.url = url.standardizedFileURL
        self.kind = kind
    }

    /// Resolve vault root for the running platform.
    /// - Parameters:
    ///   - preferredLocalDirectory: Override local root (unit tests / custom sandbox).
    ///   - forceLocal: Skip ubiquity even when the API exists (simulators / CI).
    ///   - fileManager: Injectable for tests.
    public static func resolve(
        preferredLocalDirectory: URL? = nil,
        forceLocal: Bool = false,
        fileManager: FileManager = .default
    ) throws -> VaultRoot {
        if let preferred = preferredLocalDirectory {
            let root = preferred.appendingPathComponent("LociVault", isDirectory: true)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            return VaultRoot(url: root, kind: .localDocuments)
        }

        #if canImport(Darwin)
        if !forceLocal, let ubiquity = Self.ubiquityDocumentsURL(fileManager: fileManager) {
            let root = ubiquity.appendingPathComponent("LociVault", isDirectory: true)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            return VaultRoot(url: root, kind: .iCloudUbiquity)
        }
        #endif

        let local = try Self.defaultLocalDocumentsURL(fileManager: fileManager)
        let root = local.appendingPathComponent("LociVault", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return VaultRoot(url: root, kind: .localDocuments)
    }

    /// Application sandbox Documents (or temp-friendly equivalent on Linux).
    public static func defaultLocalDocumentsURL(fileManager: FileManager = .default) throws -> URL {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return docs
        }
        throw LociError.vaultUnavailable
        #else
        // Linux: mirror a Documents folder under Application Support / home.
        let base =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let docs = base.appendingPathComponent("Loci/Documents", isDirectory: true)
        try fileManager.createDirectory(at: docs, withIntermediateDirectories: true)
        return docs
        #endif
    }

    #if canImport(Darwin)
    /// Ubiquity container Documents URL when iCloud Drive is signed in and entitled.
    private static func ubiquityDocumentsURL(fileManager: FileManager) -> URL? {
        // Container id matches entitlements / Info.plist (see App/Resources).
        let containerID = "iCloud.app.loci.Loci"
        guard let container = fileManager.url(forUbiquityContainerIdentifier: containerID)
            ?? fileManager.url(forUbiquityContainerIdentifier: nil)
        else {
            return nil
        }
        return container.appendingPathComponent("Documents", isDirectory: true)
    }
    #endif
}
