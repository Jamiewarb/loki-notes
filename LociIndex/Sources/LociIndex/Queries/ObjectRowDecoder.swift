import Foundation
import GRDB
import LociCore

/// Shared row → `LociObjectMeta` decoding for query helpers.
enum ObjectRowDecoder {
    static func decode(_ row: Row) throws -> LociObjectMeta {
        let idString: String = row["id"]
        guard let objectID = ObjectID(parsing: idString) else {
            throw LociError.invalidObjectID(idString)
        }
        let typeID = ObjectTypeID(row["type_id"])
        let title: String = row["title"]
        let created = Date(timeIntervalSince1970: row["created"])
        let updated = Date(timeIntervalSince1970: row["updated"])
        let relativePath: String = row["relative_path"]
        let tagsJSON: String = row["tags_json"]
        let propsJSON: String = row["properties_json"]

        let tags = try JSONDecoder().decode([String].self, from: Data(tagsJSON.utf8))
        let properties = try JSONDecoder().decode([String: PropertyValue].self, from: Data(propsJSON.utf8))

        return LociObjectMeta(
            id: objectID,
            typeID: typeID,
            title: title,
            created: created,
            updated: updated,
            relativePath: relativePath,
            tags: tags,
            properties: properties
        )
    }
}
