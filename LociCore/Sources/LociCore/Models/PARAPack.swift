import Foundation

/// PARA starter pack (PR15) — Project + Area types, Resource/Archive guidance.
///
/// **Design choices (documented):**
/// - **Resource:** `#resource` tag on any object (Page or otherwise) — not a dedicated type.
///   Matches Capacities guidance (“whole space, or `#resource` tag”).
/// - **Archive:** `#archive` tag (primary) and/or `status = Archived` on Project/Area.
///   Never a filesystem folder move. Dashboards hide archived by default when pack is applied.
/// - **Inbox:** Daily note (already seeded).
public enum PARAPack: Sendable {
    public static let resourceTag = "resource"
    public static let archiveTag = "archive"

    public static let projectID = ObjectTypeID.project
    public static let areaID = ObjectTypeID.area

    public static let projectDefaultTemplateID = "project.default"
    public static let areaDefaultTemplateID = "area.default"

    /// Short in-app / harness explainer.
    public static let explainer = """
    PARA in Loci: Projects and Areas are object types with starter properties and templates. \
    Mark reference material with #resource (any type — no Resource folder). \
    Archive with #archive or status=Archived; dashboards hide archived by default. \
    Your inbox is today’s Daily note. Nothing is “moved” into archive folders.
    """

    public static let resourceGuidance =
        "Tag any object with #resource. No dedicated Resource type — the whole vault can hold reference material."

    public static let archiveGuidance =
        "Archive via #archive tag or status=Archived on Project/Area. Filter hides archived; files stay put."

    /// Idempotent apply: create Project/Area + starter props/templates; record guidance in space.json.
    @discardableResult
    public static func apply(to schema: any SchemaServing) async throws -> PARAPackResult {
        var createdTypeIDs: [String] = []
        var updatedTypeIDs: [String] = []
        var createdTemplateIDs: [String] = []
        var skippedTemplateIDs: [String] = []

        let project = try await ensureType(
            schema: schema,
            id: .project,
            name: "Project",
            icon: "flag",
            color: "#B85C38",
            created: &createdTypeIDs,
            updated: &updatedTypeIDs
        )
        _ = try await ensureProperties(
            schema: schema,
            typeID: project.id,
            defs: Self.projectPropertyDefs
        )
        let projectTpl = try await ensureDefaultTemplate(
            schema: schema,
            typeID: project.id,
            name: "Default Project",
            slug: "default",
            bodyMarkdown: Self.projectTemplateBody,
            defaultProperties: ["status": .select("Active")],
            created: &createdTemplateIDs,
            skipped: &skippedTemplateIDs
        )
        _ = try await configureDashboard(schema: schema, typeID: project.id, hideArchived: true)

        let area = try await ensureType(
            schema: schema,
            id: .area,
            name: "Area",
            icon: "square.grid.2x2",
            color: "#2A6F97",
            created: &createdTypeIDs,
            updated: &updatedTypeIDs
        )
        _ = try await ensureProperties(
            schema: schema,
            typeID: area.id,
            defs: Self.areaPropertyDefs
        )
        let areaTpl = try await ensureDefaultTemplate(
            schema: schema,
            typeID: area.id,
            name: "Default Area",
            slug: "default",
            bodyMarkdown: Self.areaTemplateBody,
            defaultProperties: [
                "status": .select("Active"),
                "review": .select("Monthly"),
            ],
            created: &createdTemplateIDs,
            skipped: &skippedTemplateIDs
        )
        _ = try await configureDashboard(schema: schema, typeID: area.id, hideArchived: true)

        var space = try await schema.loadSpaceSettings()
        space.paraPackApplied = true
        space.hideArchived = true
        space.resourceApproach = "tag:#resource"
        space.archiveApproach = "tag:#archive"
        try await schema.saveSpaceSettings(space)

        return PARAPackResult(
            projectTypeID: project.id.rawValue,
            areaTypeID: area.id.rawValue,
            projectTemplateID: projectTpl,
            areaTemplateID: areaTpl,
            createdTypeIDs: createdTypeIDs,
            updatedTypeIDs: updatedTypeIDs,
            createdTemplateIDs: createdTemplateIDs,
            skippedTemplateIDs: skippedTemplateIDs,
            resourceApproach: space.resourceApproach ?? "tag:#resource",
            archiveApproach: space.archiveApproach ?? "tag:#archive",
            hideArchived: space.hideArchived,
            resourceGuidance: Self.resourceGuidance,
            archiveGuidance: Self.archiveGuidance,
            explainer: Self.explainer
        )
    }

    // MARK: - Starters

    public static let projectPropertyDefs: [PropertyDef] = [
        PropertyDef(
            id: "status",
            name: "Status",
            kind: .select,
            options: ["Active", "On Hold", "Done", "Archived"]
        ),
        PropertyDef(id: "deadline", name: "Deadline", kind: .date),
        PropertyDef(id: "area", name: "Area", kind: .text),
    ]

    public static let areaPropertyDefs: [PropertyDef] = [
        PropertyDef(
            id: "status",
            name: "Status",
            kind: .select,
            options: ["Active", "Paused", "Archived"]
        ),
        PropertyDef(
            id: "review",
            name: "Review",
            kind: .select,
            options: ["Weekly", "Monthly", "Quarterly"]
        ),
    ]

    public static let projectTemplateBody = """
    ## Outcome

    ## Next actions

    ## Notes
    """

    public static let areaTemplateBody = """
    ## Standards

    ## Current focus

    ## Notes
    """

    // MARK: - Internals

    private static func ensureType(
        schema: any SchemaServing,
        id: ObjectTypeID,
        name: String,
        icon: String,
        color: String,
        created: inout [String],
        updated: inout [String]
    ) async throws -> ObjectType {
        let ids = try await schema.knownTypeIDs()
        if ids.contains(id) {
            var type = try await schema.loadType(id)
            var dirty = false
            if type.name != name {
                type.name = name
                dirty = true
            }
            if type.icon.isEmpty {
                type.icon = icon
                dirty = true
            }
            if type.color.isEmpty {
                type.color = color
                dirty = true
            }
            if dirty {
                try await schema.saveType(type)
                updated.append(id.rawValue)
            } else if !updated.contains(id.rawValue) {
                updated.append(id.rawValue)
            }
            return try await schema.loadType(id)
        }
        let type = try await schema.createType(name: name, icon: icon, color: color, slug: id.rawValue)
        created.append(id.rawValue)
        return type
    }

    private static func ensureProperties(
        schema: any SchemaServing,
        typeID: ObjectTypeID,
        defs: [PropertyDef]
    ) async throws -> ObjectType {
        var type = try await schema.loadType(typeID)
        for def in defs {
            if let idx = type.properties.firstIndex(where: { $0.id == def.id }) {
                // Preserve user options if they already customized; only fill when empty.
                var existing = type.properties[idx]
                if existing.options.isEmpty, !def.options.isEmpty {
                    existing.options = def.options
                }
                if existing.name.isEmpty {
                    existing.name = def.name
                }
                type.properties[idx] = existing
            } else {
                type.properties.append(def)
            }
        }
        return try await schema.setProperties(typeID, properties: type.properties)
    }

    private static func ensureDefaultTemplate(
        schema: any SchemaServing,
        typeID: ObjectTypeID,
        name: String,
        slug: String,
        bodyMarkdown: String,
        defaultProperties: [String: PropertyValue],
        created: inout [String],
        skipped: inout [String]
    ) async throws -> String {
        let id = try TemplateID.make(typeID: typeID, name: name, explicitSlug: slug)
        if let _ = try? await schema.loadTemplate(id) {
            // Already present — leave user edits alone; ensure starred default.
            let type = try await schema.loadType(typeID)
            if type.defaultTemplateID != id {
                _ = try await schema.setDefaultTemplate(typeID: typeID, templateID: id)
            }
            skipped.append(id)
            return id
        }
        do {
            _ = try await schema.createTemplate(
                typeID: typeID,
                name: name,
                bodyMarkdown: bodyMarkdown,
                defaultProperties: defaultProperties,
                slug: slug,
                makeDefault: true
            )
            created.append(id)
            return id
        } catch LociError.templateAlreadyExists {
            skipped.append(id)
            _ = try await schema.setDefaultTemplate(typeID: typeID, templateID: id)
            return id
        }
    }

    private static func configureDashboard(
        schema: any SchemaServing,
        typeID: ObjectTypeID,
        hideArchived: Bool
    ) async throws -> ObjectType {
        var type = try await schema.loadType(typeID)
        type.dashboard.hideArchived = hideArchived
        if type.dashboard.cardPreviewPropertyIDs.isEmpty {
            type.dashboard.cardPreviewPropertyIDs = ["status"]
        }
        if type.dashboard.defaultSort == nil {
            type.dashboard.defaultSort = "updated"
        }
        try await schema.saveType(type)
        return type
    }
}

/// Result of applying the PARA starter pack (for demos, harness, UI status).
public struct PARAPackResult: Hashable, Sendable, Codable, Equatable {
    public var projectTypeID: String
    public var areaTypeID: String
    public var projectTemplateID: String
    public var areaTemplateID: String
    public var createdTypeIDs: [String]
    public var updatedTypeIDs: [String]
    public var createdTemplateIDs: [String]
    public var skippedTemplateIDs: [String]
    public var resourceApproach: String
    public var archiveApproach: String
    public var hideArchived: Bool
    public var resourceGuidance: String
    public var archiveGuidance: String
    public var explainer: String

    public init(
        projectTypeID: String,
        areaTypeID: String,
        projectTemplateID: String,
        areaTemplateID: String,
        createdTypeIDs: [String],
        updatedTypeIDs: [String],
        createdTemplateIDs: [String],
        skippedTemplateIDs: [String],
        resourceApproach: String,
        archiveApproach: String,
        hideArchived: Bool,
        resourceGuidance: String,
        archiveGuidance: String,
        explainer: String
    ) {
        self.projectTypeID = projectTypeID
        self.areaTypeID = areaTypeID
        self.projectTemplateID = projectTemplateID
        self.areaTemplateID = areaTemplateID
        self.createdTypeIDs = createdTypeIDs
        self.updatedTypeIDs = updatedTypeIDs
        self.createdTemplateIDs = createdTemplateIDs
        self.skippedTemplateIDs = skippedTemplateIDs
        self.resourceApproach = resourceApproach
        self.archiveApproach = archiveApproach
        self.hideArchived = hideArchived
        self.resourceGuidance = resourceGuidance
        self.archiveGuidance = archiveGuidance
        self.explainer = explainer
    }
}

/// Archive detection for sidebar / type-dashboard filters (PR15).
public enum ArchiveFilter: Sendable {
    /// True when object has `#archive` / `archive` tag or `status` property is Archived.
    public static func isArchived(_ meta: LociObjectMeta) -> Bool {
        let normalizedTags = meta.tags.map { tag in
            tag.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
        }
        if normalizedTags.contains(PARAPack.archiveTag) {
            return true
        }
        if case .select(let value) = meta.properties["status"],
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "archived"
        {
            return true
        }
        if case .text(let value) = meta.properties["status"],
            value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "archived"
        {
            return true
        }
        return false
    }

    /// Apply hide-archived preference to a list.
    public static func visible(
        _ items: [LociObjectMeta],
        hideArchived: Bool
    ) -> [LociObjectMeta] {
        guard hideArchived else { return items }
        return items.filter { !isArchived($0) }
    }
}
