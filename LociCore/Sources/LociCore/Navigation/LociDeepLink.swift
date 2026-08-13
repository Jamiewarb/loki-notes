import Foundation

/// App URL scheme understood by the main app (PR37).
///
/// Widget “Open today” and Share/Widget fallbacks use these URLs. The main app
/// handles them via `onOpenURL` — no second inbox, no index in the extension.
public enum LociDeepLink: String, Sendable, Hashable, Codable, Equatable {
    /// Open / ensure today’s daily note (`daily/YYYY-MM-DD.md`).
    case dailyToday
    /// Open the in-app capture surface (quick add).
    case capture
    case unknown

    public static let scheme = "loci"

    /// Documented widget / AppIntent URL: `loci://daily/today`.
    public static let dailyTodayAbsoluteString = "loci://daily/today"
    /// Fallback when the widget cannot enqueue: `loci://capture`.
    public static let captureAbsoluteString = "loci://capture"

    public static var dailyTodayURL: URL {
        URL(string: dailyTodayAbsoluteString)!
    }

    public static var captureURL: URL {
        URL(string: captureAbsoluteString)!
    }

    public static func parse(_ url: URL) -> LociDeepLink {
        guard url.scheme?.lowercased() == scheme else { return .unknown }
        let host = (url.host ?? "").lowercased()
        let pathParts = url.path.split(separator: "/").map { $0.lowercased() }
        var parts: [String] = []
        if !host.isEmpty { parts.append(host) }
        parts.append(contentsOf: pathParts)
        if parts.first == "daily", parts.count == 1 || parts.dropFirst().first == "today" {
            return .dailyToday
        }
        if parts.first == "capture" {
            return .capture
        }
        return .unknown
    }

    public static func parse(_ string: String) -> LociDeepLink {
        guard let url = URL(string: string) else { return .unknown }
        return parse(url)
    }

    /// Shell route this link should open (`nil` for unknown).
    public var route: Route? {
        switch self {
        case .dailyToday: return .daily
        case .capture: return .capture
        case .unknown: return nil
        }
    }
}
