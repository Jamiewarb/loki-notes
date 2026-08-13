import Foundation

/// Role → `Font.TextStyle` name used with `Font.custom(_:size:relativeTo:)` (PR39).
/// Numeric token sizes stay the unscaled defaults; Linux tests never import SwiftUI.
public struct LociDynamicTypeRole: Hashable, Sendable, Equatable, Codable {
    public var role: String
    public var textStyle: String

    public init(role: String, textStyle: String) {
        self.role = role
        self.textStyle = textStyle
    }
}

public enum LociDynamicTypeCatalog: Sendable {
    /// SwiftUI helper uses `relativeTo:` so Dynamic Type scales custom fonts.
    public static let usesRelativeTo = true

    public static let all: [LociDynamicTypeRole] = [
        LociDynamicTypeRole(role: "brand", textStyle: "largeTitle"),
        LociDynamicTypeRole(role: "display", textStyle: "title"),
        LociDynamicTypeRole(role: "title", textStyle: "title2"),
        LociDynamicTypeRole(role: "headline", textStyle: "headline"),
        LociDynamicTypeRole(role: "body", textStyle: "body"),
        LociDynamicTypeRole(role: "callout", textStyle: "callout"),
        LociDynamicTypeRole(role: "caption", textStyle: "caption"),
        LociDynamicTypeRole(role: "overline", textStyle: "caption"),
    ]

    public static var roleNames: [String] { all.map(\.role) }

    public static func textStyleName(forRole role: String) -> String? {
        all.first { $0.role == role }?.textStyle
    }
}
