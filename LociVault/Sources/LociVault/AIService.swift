import Foundation
import LociCore

/// Concrete `AIServing` — settings + heuristics + optional BYOK transport (PR30).
///
/// Settings and credentials live under Application Support (caller-provided directory) —
/// **never** inside the vault. Vault writes go only through `ObjectServing.save`.
public final class AIService: AIServing, @unchecked Sendable {
    private let settingsDirectory: URL
    private let settingsURL: URL
    private let credentials: AICredentialStore
    private let remote: (any AIRemoteTransport)?
    private let lock = NSLock()

    public init(
        settingsDirectory: URL,
        credentials: AICredentialStore,
        remote: (any AIRemoteTransport)? = nil
    ) {
        self.settingsDirectory = settingsDirectory
        self.settingsURL = settingsDirectory.appendingPathComponent("settings.json", isDirectory: false)
        self.credentials = credentials
        self.remote = remote
    }

    /// Convenience: Application Support `Loci/ai/` (Apple) or temp (Linux).
    public static func makeDefault(remote: (any AIRemoteTransport)? = nil) throws -> AIService {
        let dir = try AICredentialStore.defaultDirectory()
        return AIService(
            settingsDirectory: dir,
            credentials: AICredentialStore(directory: dir),
            remote: remote
        )
    }

    public var settingsFileURL: URL { settingsURL }

    // MARK: - AIServing

    public func loadSettings() async throws -> AISettings {
        try loadSettingsLocked()
    }

    public func saveSettings(_ settings: AISettings) async throws {
        try saveSettingsLocked(settings)
    }

    public func run(_ request: AIRequest) async throws -> AIProposal {
        let settings = try await loadSettings()
        // Remote BYOK only when this request allows upload. Otherwise stay on-device
        // even if BYOK is the preferred provider (never block local assist).
        let wantsBYOK = settings.preferredProvider == .byok && request.allowRemoteUpload

        if wantsBYOK {
            guard AIPrivacy.remotePayloadAllowed(settings: settings, request: request) else {
                throw LociError.aiUploadNotAllowed
            }
            let providerName = settings.byokProviderName ?? "default"
            let key = try credentials.apiKey(for: providerName)
            guard let key, !key.isEmpty else {
                throw LociError.aiCredentialsMissing
            }
            _ = key
            if let remote {
                let prompt = AIPrivacy.payloadText(request: request)
                let completion = try await remote.complete(prompt: prompt)
                var proposal = AIHeuristics.run(request, settings: settings)
                if !completion.isEmpty {
                    switch request.action {
                    case .summarize:
                        proposal.summary = completion
                    case .rewrite, .translate:
                        proposal.proposedBody = completion
                    case .autofillProperties:
                        break
                    }
                }
                proposal.provider = .byok
                proposal.uploaded = true
                proposal.notes.append("remote transport completed")
                return proposal
            }
            // No real HTTP in Linux tests — fall back to heuristics.
            var proposal = AIHeuristics.run(request, settings: settings)
            proposal.provider = .onDeviceHeuristics
            proposal.uploaded = false
            proposal.notes.append(
                "remote transport not configured; used on-device heuristics"
            )
            return proposal
        }

        if settings.preferredProvider == .appleIntelligence {
            #if os(macOS) || os(iOS)
            // Stub: Apple Intelligence wiring lands with platform SDK availability.
            var proposal = AIHeuristics.run(request, settings: settings)
            proposal.provider = .appleIntelligence
            proposal.uploaded = false
            proposal.notes.append("apple intelligence stub → heuristics")
            return proposal
            #else
            var proposal = AIHeuristics.run(request, settings: settings)
            proposal.provider = .onDeviceHeuristics
            proposal.uploaded = false
            proposal.notes.append("apple intelligence unavailable; used on-device heuristics")
            return proposal
            #endif
        }

        // Default: on-device heuristics — never uploaded.
        var proposal = AIHeuristics.run(request, settings: settings)
        proposal.provider = .onDeviceHeuristics
        proposal.uploaded = false
        if settings.preferredProvider == .byok && !request.allowRemoteUpload {
            proposal.notes.append("BYOK skipped (no remote upload for this action)")
        }
        return proposal
    }

    private func loadSettingsLocked() throws -> AISettings {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return AISettings()
        }
        let data = try Data(contentsOf: settingsURL)
        return try JSONDecoder().decode(AISettings.self, from: data)
    }

    private func saveSettingsLocked(_ settings: AISettings) throws {
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: settingsURL.path
        )
    }

    @discardableResult
    public func apply(
        _ proposal: AIProposal,
        using objects: any ObjectServing
    ) async throws -> OpenedObject {
        let opened = try await objects.open(id: proposal.objectID)
        var meta = opened.meta
        if let props = proposal.proposedProperties {
            for (key, value) in props {
                meta.properties[key] = value
            }
        }
        let body = proposal.proposedBody ?? opened.bodyMarkdown
        try await objects.save(meta: meta, bodyMarkdown: body)
        return try await objects.open(id: proposal.objectID)
    }
}
