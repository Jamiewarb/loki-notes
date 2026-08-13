import Foundation

/// Object type schema — one file per type under `.loci/types/<slug>.json` (merge-friendly).
public struct ObjectType: Hashable, Sendable, Codable, Equatable {
    public var id: ObjectTypeID
    public var name: String
    public var icon: String
    public var color: String
    public var properties: [PropertyDef]
    public var defaultTemplateID: String?
    public var templateIDs: [String]
    public var dashboard: TypeDashboardConfig
    public var isBuiltIn: Bool
    /// When true, objects of this type use deterministic daily paths (PR10).
    public var isDaily: Bool

    public init(
        id: ObjectTypeID,
        name: String,
        icon: String = "doc.text",
        color: String = "#0F6B5C",
        properties: [PropertyDef] = [],
        defaultTemplateID: String? = nil,
        templateIDs: [String] = [],
        dashboard: TypeDashboardConfig = TypeDashboardConfig(),
        isBuiltIn: Bool = false,
        isDaily: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.properties = properties
        self.defaultTemplateID = defaultTemplateID
        self.templateIDs = templateIDs
        self.dashboard = dashboard
        self.isBuiltIn = isBuiltIn
        self.isDaily = isDaily
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, color, properties, defaultTemplateID, templateIDs, dashboard,
            isBuiltIn, isDaily
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ObjectTypeID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "doc.text"
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#0F6B5C"
        properties = try container.decodeIfPresent([PropertyDef].self, forKey: .properties) ?? []
        defaultTemplateID = try container.decodeIfPresent(String.self, forKey: .defaultTemplateID)
        templateIDs = try container.decodeIfPresent([String].self, forKey: .templateIDs) ?? []
        dashboard =
            try container.decodeIfPresent(TypeDashboardConfig.self, forKey: .dashboard)
            ?? TypeDashboardConfig()
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        isDaily = try container.decodeIfPresent(Bool.self, forKey: .isDaily) ?? false
    }

    /// Built-in Page type seeded on vault create / schema bootstrap.
    public static var builtInPage: ObjectType {
        ObjectType(
            id: .page,
            name: "Page",
            icon: "doc.text",
            color: "#0F6B5C",
            properties: [],
            isBuiltIn: true,
            isDaily: false
        )
    }

    /// Built-in Daily type (flagged; seeded when daily notes land in PR10, available for schema).
    public static var builtInDaily: ObjectType {
        ObjectType(
            id: .daily,
            name: "Daily",
            icon: "sun.max",
            color: "#3D6B5C",
            properties: [],
            isBuiltIn: true,
            isDaily: true
        )
    }
}
