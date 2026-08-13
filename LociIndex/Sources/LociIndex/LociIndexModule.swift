import Foundation

/// LociIndex public surface — disposable SQLite projection of vault markdown.
///
/// **Critical:** the database lives under Application Support (or a test temp directory),
/// never inside the iCloud / local vault folder.
public enum LociIndexModule {
    public static let version = "0.2.0-pr16"

    /// Convention subdirectory under Application Support: `…/Application Support/Loci/<vaultID>/index.sqlite`
    public static let applicationSupportSubdirectory = "Loci"

    public static let databaseFileName = "index.sqlite"
}
