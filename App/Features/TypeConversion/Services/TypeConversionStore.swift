import Foundation
import LociCore

/// Thin feature-local facade over `ObjectServing` type conversion (PR28).
@MainActor
final class TypeConversionStore {
    private let objects: (any ObjectServing)?
    private let schema: (any SchemaServing)?

    init(objects: (any ObjectServing)?, schema: (any SchemaServing)?) {
        self.objects = objects
        self.schema = schema
    }

    func listConvertibleTypes(excluding source: ObjectTypeID) async throws -> [ObjectType] {
        guard let schema else { return [] }
        let all = try await schema.allTypes()
        return all.filter { $0.id != source && $0.id != .daily }
    }

    func plan(id: ObjectID, toTypeID: ObjectTypeID) async throws -> TypeConversionPlan? {
        guard let objects else { return nil }
        return try await objects.planConversion(id: id, toTypeID: toTypeID)
    }

    func convert(
        id: ObjectID,
        toTypeID: ObjectTypeID,
        propertyMap: [TypeConversionPropertyMap]
    ) async throws -> TypeConversionResult? {
        guard let objects else { return nil }
        return try await objects.convert(id: id, toTypeID: toTypeID, propertyMap: propertyMap)
    }
}
