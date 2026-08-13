import Foundation
import LociCore

/// Thin feature-local facade over `AIServing` (PR30).
@MainActor
final class AIStore {
    private let ai: any AIServing

    init(ai: any AIServing) {
        self.ai = ai
    }

    func loadSettings() async throws -> AISettings {
        try await ai.loadSettings()
    }

    func saveSettings(_ settings: AISettings) async throws {
        try await ai.saveSettings(settings)
    }

    func run(_ request: AIRequest) async throws -> AIProposal {
        try await ai.run(request)
    }

    @discardableResult
    func apply(_ proposal: AIProposal, using objects: any ObjectServing) async throws -> OpenedObject {
        try await ai.apply(proposal, using: objects)
    }
}
