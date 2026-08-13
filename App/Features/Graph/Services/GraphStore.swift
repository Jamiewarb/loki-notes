import Foundation
import LociCore

/// Thin feature-local facade over IndexQuerying for the link graph (PR24).
@MainActor
final class GraphStore {
    private let index: (any IndexQuerying)?

    init(index: (any IndexQuerying)?) {
        self.index = index
    }

    func load(options: GraphBuildOptions) async throws -> GraphSnapshot {
        guard let index else {
            return GraphSnapshot()
        }
        return try await index.graph(options: options)
    }
}
