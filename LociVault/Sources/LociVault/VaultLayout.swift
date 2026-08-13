import Foundation

/// Canonical on-disk layout for a Loci vault (Part 4 of PLAN.md).
/// Index / SQLite must never live under these paths.
public enum VaultLayout: Sendable {
    public static let lociDirectory = ".loci"
    public static let spaceJSON = ".loci/space.json"
    public static let typesDirectory = ".loci/types"
    public static let templatesDirectory = ".loci/templates"
    public static let trashDirectory = ".loci/trash"
    public static let dailyDirectory = "daily"
    public static let objectsDirectory = "objects"
    public static let mediaImagesDirectory = "media/images"
    public static let mediaFilesDirectory = "media/files"

    /// Directories created by `ensureSkeleton`.
    public static let requiredDirectories: [String] = [
        lociDirectory,
        typesDirectory,
        templatesDirectory,
        trashDirectory,
        dailyDirectory,
        objectsDirectory,
        mediaImagesDirectory,
        mediaFilesDirectory,
    ]
}

/// Module marker + version for diagnostics / harness copy.
public enum LociVaultModule {
    public static let version = "0.8.0-pr08"
}
