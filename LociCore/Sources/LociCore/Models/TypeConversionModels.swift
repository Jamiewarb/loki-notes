import Foundation

/// One row in the type-conversion property mapper (PR28).
///
/// `targetPropertyID == nil` means drop the source value (do not carry it over).
public struct TypeConversionPropertyMap: Hashable, Sendable, Codable, Equatable {
    public var sourcePropertyID: String
    public var targetPropertyID: String?

    public init(sourcePropertyID: String, targetPropertyID: String?) {
        self.sourcePropertyID = sourcePropertyID
        self.targetPropertyID = targetPropertyID
    }
}

/// Preview of a conversion before vault writes (UI dry-run).
public struct TypeConversionPlan: Hashable, Sendable, Codable, Equatable {
    public var objectID: ObjectID
    public var title: String
    public var sourceTypeID: ObjectTypeID
    public var targetTypeID: ObjectTypeID
    public var sourceRelativePath: String
    public var proposedRelativePath: String
    public var mappings: [TypeConversionPropertyMap]
    public var sourceDefs: [PropertyDef]
    public var targetDefs: [PropertyDef]
    /// Source property ids with no mapping target (dropped).
    public var droppedPropertyIDs: [String]
    /// Target required defs that will stay empty after apply.
    public var unmappedRequiredTargetIDs: [String]

    public init(
        objectID: ObjectID,
        title: String,
        sourceTypeID: ObjectTypeID,
        targetTypeID: ObjectTypeID,
        sourceRelativePath: String,
        proposedRelativePath: String,
        mappings: [TypeConversionPropertyMap],
        sourceDefs: [PropertyDef],
        targetDefs: [PropertyDef],
        droppedPropertyIDs: [String],
        unmappedRequiredTargetIDs: [String]
    ) {
        self.objectID = objectID
        self.title = title
        self.sourceTypeID = sourceTypeID
        self.targetTypeID = targetTypeID
        self.sourceRelativePath = sourceRelativePath
        self.proposedRelativePath = proposedRelativePath
        self.mappings = mappings
        self.sourceDefs = sourceDefs
        self.targetDefs = targetDefs
        self.droppedPropertyIDs = droppedPropertyIDs
        self.unmappedRequiredTargetIDs = unmappedRequiredTargetIDs
    }
}

/// Result after a successful type conversion (ObjectID stable).
public struct TypeConversionResult: Hashable, Sendable, Codable, Equatable {
    public var objectID: ObjectID
    public var sourceTypeID: ObjectTypeID
    public var targetTypeID: ObjectTypeID
    public var oldRelativePath: String
    public var newRelativePath: String
    public var mappedPropertyCount: Int
    public var droppedPropertyCount: Int
    public var opened: OpenedObject

    public init(
        objectID: ObjectID,
        sourceTypeID: ObjectTypeID,
        targetTypeID: ObjectTypeID,
        oldRelativePath: String,
        newRelativePath: String,
        mappedPropertyCount: Int,
        droppedPropertyCount: Int,
        opened: OpenedObject
    ) {
        self.objectID = objectID
        self.sourceTypeID = sourceTypeID
        self.targetTypeID = targetTypeID
        self.oldRelativePath = oldRelativePath
        self.newRelativePath = newRelativePath
        self.mappedPropertyCount = mappedPropertyCount
        self.droppedPropertyCount = droppedPropertyCount
        self.opened = opened
    }
}

/// Pure property-mapping helpers — no I/O (PR28).
public enum TypeConversionMapper: Sendable {
    /// Suggest source→target maps: exact id, then name+kind, then name (coerced).
    public static func suggestMapping(
        sourceDefs: [PropertyDef],
        targetDefs: [PropertyDef]
    ) -> [TypeConversionPropertyMap] {
        let targetsByID = Dictionary(uniqueKeysWithValues: targetDefs.map { ($0.id, $0) })
        let targetsByName = Dictionary(
            targetDefs.map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        var claimedTargets = Set<String>()
        var maps: [TypeConversionPropertyMap] = []

        for source in sourceDefs {
            if let exact = targetsByID[source.id], !claimedTargets.contains(exact.id) {
                claimedTargets.insert(exact.id)
                maps.append(
                    TypeConversionPropertyMap(
                        sourcePropertyID: source.id,
                        targetPropertyID: exact.id
                    )
                )
                continue
            }

            if let byName = targetsByName[source.name.lowercased()],
               !claimedTargets.contains(byName.id),
               byName.kind == source.kind
            {
                claimedTargets.insert(byName.id)
                maps.append(
                    TypeConversionPropertyMap(
                        sourcePropertyID: source.id,
                        targetPropertyID: byName.id
                    )
                )
                continue
            }

            if let byName = targetsByName[source.name.lowercased()],
               !claimedTargets.contains(byName.id)
            {
                claimedTargets.insert(byName.id)
                maps.append(
                    TypeConversionPropertyMap(
                        sourcePropertyID: source.id,
                        targetPropertyID: byName.id
                    )
                )
                continue
            }

            maps.append(
                TypeConversionPropertyMap(sourcePropertyID: source.id, targetPropertyID: nil)
            )
        }
        return maps
    }

    /// Apply mapping + coerce values into target property kinds.
    public static func applyProperties(
        source: [String: PropertyValue],
        mappings: [TypeConversionPropertyMap],
        targetDefs: [PropertyDef]
    ) -> [String: PropertyValue] {
        let defsByID = Dictionary(uniqueKeysWithValues: targetDefs.map { ($0.id, $0) })
        var out: [String: PropertyValue] = [:]

        for map in mappings {
            guard let targetID = map.targetPropertyID, !targetID.isEmpty else { continue }
            guard let value = source[map.sourcePropertyID], value != .null else { continue }
            guard let def = defsByID[targetID] else { continue }
            out[targetID] = coerce(value, to: def)
        }
        return out
    }

    /// Coerce a property value into a target def’s kind (reuse PropertyValueFormatting).
    public static func coerce(_ value: PropertyValue, to def: PropertyDef) -> PropertyValue {
        if case .null = value { return .null }
        // Same-shaped values can pass when kinds align.
        switch (value, def.kind) {
        case (.text, .text), (.number, .number), (.bool, .checkbox),
             (.date, .date), (.url, .url), (.select, .select),
             (.multiSelect, .multiSelect), (.objectSelect, .objectSelect):
            return value
        default:
            let draft = PropertyValueFormatting.draftString(value)
            return PropertyValueFormatting.coerce(draft: draft, kind: def.kind)
        }
    }

    public static func droppedPropertyIDs(in mappings: [TypeConversionPropertyMap]) -> [String] {
        mappings.compactMap { $0.targetPropertyID == nil ? $0.sourcePropertyID : nil }
    }

    public static func unmappedRequiredTargetIDs(
        targetDefs: [PropertyDef],
        mappings: [TypeConversionPropertyMap]
    ) -> [String] {
        let mappedTargets = Set(mappings.compactMap(\.targetPropertyID))
        return targetDefs
            .filter { $0.required && !mappedTargets.contains($0.id) }
            .map(\.id)
    }
}
