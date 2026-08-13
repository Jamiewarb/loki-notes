import Foundation
import LociCore

/// Sidebar / chrome destinations for AppShell.
/// Maps 1:1 onto `LociCore.Route` so features never import each other’s views.
enum AppRoute: Hashable, Sendable, CaseIterable, Identifiable {
    case daily
    case search
    case types
    case settings
    case designGallery

    var id: Self { self }

    /// Primary destinations shown in the main nav list.
    static let primary: [AppRoute] = [.daily, .search, .types, .settings]

    /// Debug / tooling destinations (reachable, not primary).
    static let tooling: [AppRoute] = [.designGallery]

    var route: Route {
        switch self {
        case .daily: return .daily
        case .search: return .search
        case .types: return .types
        case .settings: return .settings
        case .designGallery: return .designGallery
        }
    }

    var title: String { route.title }
    var subtitle: String { route.subtitle }
    var systemImage: String { route.systemImage }

    init?(route: Route) {
        switch route {
        case .daily: self = .daily
        case .search: self = .search
        case .types: self = .types
        case .settings: self = .settings
        case .designGallery: self = .designGallery
        case .object: return nil
        }
    }
}

/// Pin section stub — real pinned objects arrive with Object CRUD / collections.
struct PinnedItemStub: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String

    static let placeholders: [PinnedItemStub] = [
        PinnedItemStub(id: "pin-inbox", title: "Inbox", subtitle: "Pinned · coming later"),
    ]
}
