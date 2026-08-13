import Foundation

/// App-level navigation destinations used by AppShell (`Navigating`).
public enum Route: Hashable, Sendable, Codable {
    case daily
    case search
    case types
    case settings
    /// Design system gallery — reachable from shell chrome (debug / Settings).
    case designGallery
    /// Cross-type tag browse (PR17) — Studio / tooling destination.
    case tags
    case object(ObjectID)

    /// Sidebar primary destinations (excludes object deep-links, design gallery, tags).
    public static let primaryDestinations: [Route] = [
        .daily, .search, .types, .settings,
    ]

    public var title: String {
        switch self {
        case .daily: return "Daily"
        case .search: return "Search"
        case .types: return "Types"
        case .settings: return "Settings"
        case .designGallery: return "Design"
        case .tags: return "Tags"
        case .object: return "Object"
        }
    }

    public var systemImage: String {
        switch self {
        case .daily: return "sun.max"
        case .search: return "magnifyingglass"
        case .types: return "square.grid.2x2"
        case .settings: return "gearshape"
        case .designGallery: return "paintpalette"
        case .tags: return "number"
        case .object: return "doc.text"
        }
    }

    public var subtitle: String {
        switch self {
        case .daily: return "Today’s note"
        case .search: return "Full-text index"
        case .types: return "Object dashboards"
        case .settings: return "Vault & sync"
        case .designGallery: return "Tokens & primitives"
        case .tags: return "Cross-type #tags"
        case .object: return "Open object"
        }
    }

    public var isPrimaryDestination: Bool {
        Self.primaryDestinations.contains(self)
    }
}
