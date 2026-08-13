import Foundation
import LociCore

/// Thin feature-local facade over `ImportServing` (PR27).
@MainActor
final class ImportStore {
    private let importer: (any ImportServing)?

    init(importer: (any ImportServing)?) {
        self.importer = importer
    }

    func detect(at url: URL) async throws -> ImportSourceKind? {
        guard let importer else { return nil }
        return try await importer.detectKind(atSourceRoot: url)
    }

    func dryRun(
        at url: URL,
        kind: ImportSourceKind?,
        policy: ImportConflictPolicy
    ) async throws -> ImportDryRunSummary? {
        guard let importer else { return nil }
        return try await importer.dryRun(
            sourceRoot: url,
            kind: kind,
            conflictPolicy: policy
        )
    }

    func apply(
        summary: ImportDryRunSummary,
        policy: ImportConflictPolicy
    ) async throws -> ImportApplyResult? {
        guard let importer else { return nil }
        return try await importer.apply(summary: summary, conflictPolicy: policy)
    }
}
