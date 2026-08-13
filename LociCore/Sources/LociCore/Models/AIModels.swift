import Foundation

/// Side-panel AI actions (PR30). Explicit only — never on the typing path.
public enum AIAction: String, Sendable, Hashable, Codable, Equatable {
    case summarize
    case rewrite
    case translate
    case autofillProperties
}

/// Preferred AI backend. Default is deterministic on-device heuristics (Linux-testable).
public enum AIProviderKind: String, Sendable, Hashable, Codable, Equatable {
    case onDeviceHeuristics
    case appleIntelligence
    case byok
}

/// User preferences for AI (stored under Application Support — never in the vault).
public struct AISettings: Hashable, Sendable, Codable, Equatable {
    public var preferredProvider: AIProviderKind
    /// Must be true **and** request.allowRemoteUpload before any remote payload is sent.
    public var uploadVaultOptIn: Bool
    public var byokProviderName: String?
    public var targetLanguage: String

    public init(
        preferredProvider: AIProviderKind = .onDeviceHeuristics,
        uploadVaultOptIn: Bool = false,
        byokProviderName: String? = nil,
        targetLanguage: String = "es"
    ) {
        self.preferredProvider = preferredProvider
        self.uploadVaultOptIn = uploadVaultOptIn
        self.byokProviderName = byokProviderName
        self.targetLanguage = targetLanguage
    }
}

/// Explicit assist request for one open object (title/body/properties only — never whole vault).
public struct AIRequest: Hashable, Sendable, Codable, Equatable {
    public var action: AIAction
    public var objectID: ObjectID
    public var title: String
    public var bodyMarkdown: String
    public var propertyDefs: [PropertyDef]
    public var existingProperties: [String: PropertyValue]
    public var targetLanguage: String?
    public var rewriteStyle: String?
    /// Caller must set true only when the user confirmed remote upload for this action.
    public var allowRemoteUpload: Bool

    public init(
        action: AIAction,
        objectID: ObjectID,
        title: String,
        bodyMarkdown: String,
        propertyDefs: [PropertyDef] = [],
        existingProperties: [String: PropertyValue] = [:],
        targetLanguage: String? = nil,
        rewriteStyle: String? = nil,
        allowRemoteUpload: Bool = false
    ) {
        self.action = action
        self.objectID = objectID
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.propertyDefs = propertyDefs
        self.existingProperties = existingProperties
        self.targetLanguage = targetLanguage
        self.rewriteStyle = rewriteStyle
        self.allowRemoteUpload = allowRemoteUpload
    }
}

/// Proposed edit returned by `AIServing.run`. Apply via `AIServing.apply` / EditorSession.
public struct AIProposal: Hashable, Sendable, Codable, Equatable {
    public var action: AIAction
    public var objectID: ObjectID
    public var provider: AIProviderKind
    public var summary: String?
    public var proposedBody: String?
    public var proposedProperties: [String: PropertyValue]?
    public var notes: [String]
    /// Must stay false unless opt-in actually sent bytes to a remote transport.
    public var uploaded: Bool

    public init(
        action: AIAction,
        objectID: ObjectID,
        provider: AIProviderKind,
        summary: String? = nil,
        proposedBody: String? = nil,
        proposedProperties: [String: PropertyValue]? = nil,
        notes: [String] = [],
        uploaded: Bool = false
    ) {
        self.action = action
        self.objectID = objectID
        self.provider = provider
        self.summary = summary
        self.proposedBody = proposedBody
        self.proposedProperties = proposedProperties
        self.notes = notes
        self.uploaded = uploaded
    }
}

/// Privacy helpers (pure — no I/O). Unit-tested to never concatenate a vault directory.
public enum AIPrivacy: Sendable {
    /// True only when settings opt-in **and** this request allows remote upload.
    public static func remotePayloadAllowed(settings: AISettings, request: AIRequest) -> Bool {
        settings.uploadVaultOptIn && request.allowRemoteUpload
    }

    /// Title + body of **this object only** — never other vault files or directory listings.
    public static func payloadText(request: AIRequest) -> String {
        let title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = request.bodyMarkdown
        if title.isEmpty { return body }
        if body.isEmpty { return title }
        return title + "\n\n" + body
    }
}
