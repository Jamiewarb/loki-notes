import Foundation

/// Import markdown folders / Obsidian vaults / Capacities exports into a Loci vault (PR27).
///
/// **Dry-run first:** `dryRun` builds an `ImportDryRunSummary` without writing.
/// **Apply:** writes real vault files (`objects/`, `daily/`, `media/`) then indexes via
/// `IndexUpdating` — never invents a parallel store. Features call this protocol only.
public protocol ImportServing: Sendable {
    /// Heuristic detect from the source root (`.obsidian/` → Obsidian, `Objects/` → Capacities).
    func detectKind(atSourceRoot sourceRoot: URL) async throws -> ImportSourceKind

    /// Plan an import without mutating the vault.
    func dryRun(
        sourceRoot: URL,
        kind: ImportSourceKind?,
        conflictPolicy: ImportConflictPolicy
    ) async throws -> ImportDryRunSummary

    /// Apply a previously computed dry-run plan (paths must still resolve).
    func apply(
        summary: ImportDryRunSummary,
        conflictPolicy: ImportConflictPolicy
    ) async throws -> ImportApplyResult

    /// Convenience: dry-run then apply in one call (still returns both via apply result warnings).
    func importFrom(
        sourceRoot: URL,
        kind: ImportSourceKind?,
        conflictPolicy: ImportConflictPolicy
    ) async throws -> ImportApplyResult
}
