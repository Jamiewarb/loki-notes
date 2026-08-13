import Foundation
import GRDB
import LociCore
import LociMarkdown

/// Writes / clears link rows for an indexed object.
enum LinkIndexer {
    static func replaceLinks(db: Database, sourceID: ObjectID, links: [WikiLink]) throws {
        let id = sourceID.uuidString.lowercased()
        try db.execute(sql: "DELETE FROM links WHERE source_id = ?", arguments: [id])
        for link in links {
            try db.execute(
                sql: "INSERT INTO links (source_id, target, label) VALUES (?, ?, ?)",
                arguments: [id, link.target, link.label]
            )
        }
    }
}
