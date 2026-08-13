/// LociIndex package stub. SQLite/GRDB projection lands in PR07.
/// Critical: the index database must live under Application Support, never inside the iCloud vault.
public enum LociIndexModule {
    public static let stubVersion = "0.0.1-pr01"

    /// Documented path convention for later PRs (not created yet).
    public static let applicationSupportSubdirectory = "Loci"
}
