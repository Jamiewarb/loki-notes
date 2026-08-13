import Foundation

/// Linux-testable helpers for wiki-link insert + broken-link classification (PR16).
public enum WikiLinkInsert: Sendable {
    /// Build markdown for a picker selection — always prefer ObjectID as target.
    public static func markdown(targetID: String, title: String) -> String {
        WikiLink(target: targetID, label: title.isEmpty ? nil : title).markdown
    }
}

/// Style token for resolved vs broken wiki-links (UI + harness).
public enum WikiLinkStyleKind: String, Sendable, Hashable {
    case resolved
    case broken
}

public struct WikiLinkStyle: Hashable, Sendable, Equatable {
    public var link: WikiLink
    public var kind: WikiLinkStyleKind
    public var resolvedTitle: String?

    public init(link: WikiLink, kind: WikiLinkStyleKind, resolvedTitle: String? = nil) {
        self.link = link
        self.kind = kind
        self.resolvedTitle = resolvedTitle
    }

    public var isBroken: Bool { kind == .broken }

    public var displayText: String {
        link.label ?? resolvedTitle ?? link.target
    }

    /// CSS / accessibility class name.
    public var styleClass: String {
        kind == .broken ? "wiki-link is-broken" : "wiki-link is-resolved"
    }

    /// Classify extracted wiki-links given a resolve callback result map (target → title).
    public static func classify(
        links: [WikiLink],
        resolvedTitlesByTarget: [String: String]
    ) -> [WikiLinkStyle] {
        links.map { link in
            if let title = resolvedTitlesByTarget[link.target]
                ?? resolvedTitlesByTarget[link.target.lowercased()]
            {
                return WikiLinkStyle(link: link, kind: .resolved, resolvedTitle: title)
            }
            return WikiLinkStyle(link: link, kind: .broken, resolvedTitle: nil)
        }
    }
}
