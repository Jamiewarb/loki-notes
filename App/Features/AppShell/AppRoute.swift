import Foundation
import LociCore

/// Sidebar / chrome destinations for AppShell.
/// Maps 1:1 onto `LociCore.Route` so features never import each other’s views.
enum AppRoute: Hashable, Sendable, CaseIterable, Identifiable {
    case daily
    case tasks
    case search
    case types
    case settings
    case designGallery
    case tags
    case graph
    case calendar
    case capture
    case importExport
    case typeConvert
    case ai
    case apple
    case safari

    var id: Self { self }

    /// Primary destinations shown in the main nav list.
    static let primary: [AppRoute] = [.daily, .tasks, .search, .types, .settings]

    /// Debug / tooling destinations (reachable, not primary).
    static let tooling: [AppRoute] = [
        .tags, .graph, .calendar, .capture, .importExport, .typeConvert, .ai, .apple, .safari,
        .designGallery,
    ]

    var route: Route {
        switch self {
        case .daily: return .daily
        case .tasks: return .tasks
        case .search: return .search
        case .types: return .types
        case .settings: return .settings
        case .designGallery: return .designGallery
        case .tags: return .tags
        case .graph: return .graph
        case .calendar: return .calendar
        case .capture: return .capture
        case .importExport: return .importExport
        case .typeConvert: return .typeConvert
        case .ai: return .ai
        case .apple: return .apple
        case .safari: return .safari
        }
    }

    var title: String { route.title }
    var subtitle: String { route.subtitle }
    var systemImage: String { route.systemImage }

    init?(route: Route) {
        switch route {
        case .daily: self = .daily
        case .tasks: self = .tasks
        case .search: self = .search
        case .types: self = .types
        case .settings: self = .settings
        case .designGallery: self = .designGallery
        case .tags: self = .tags
        case .graph: self = .graph
        case .calendar: self = .calendar
        case .capture: self = .capture
        case .importExport: self = .importExport
        case .typeConvert: self = .typeConvert
        case .ai: self = .ai
        case .apple: self = .apple
        case .safari: self = .safari
        case .object: return nil
        }
    }
}
