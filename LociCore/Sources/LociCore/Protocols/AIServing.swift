import Foundation

/// AI assist surface (PR30) — summarize / rewrite / translate / property autofill.
///
/// **Privacy:** never upload vault bytes unless the user opts in (`AISettings.uploadVaultOptIn`)
/// **and** the request sets `allowRemoteUpload`. Prefer on-device heuristics / Apple Intelligence.
///
/// **Writes:** `apply` must go through `ObjectServing.save` — AI never writes vault files itself.
/// Explicit side-panel actions only; never on the typing path.
public protocol AIServing: Sendable {
    func loadSettings() async throws -> AISettings
    func saveSettings(_ settings: AISettings) async throws
    func run(_ request: AIRequest) async throws -> AIProposal
    /// Apply via ObjectServing.save — never write vault files directly.
    @discardableResult
    func apply(_ proposal: AIProposal, using objects: any ObjectServing) async throws -> OpenedObject
}

/// Optional remote BYOK transport (injected in tests / Apple). Linux unit tests keep this nil.
public protocol AIRemoteTransport: Sendable {
    func complete(prompt: String) async throws -> String
}
