import Foundation

/// ISO-8601 helpers shared by frontmatter encode/decode.
enum FrontMatterDates {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? basic.date(from: string)
    }

    static func format(_ date: Date) -> String {
        basic.string(from: date)
    }
}
