import Foundation
import GRDB

/// SQLite schema for the local Loci index projection.
enum IndexSchema {
    static let migrationIdentifier = "v1"

    static func migrate(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration(migrationIdentifier) { db in
            try db.execute(
                sql: """
                    CREATE TABLE objects (
                      id TEXT PRIMARY KEY NOT NULL,
                      type_id TEXT NOT NULL,
                      title TEXT NOT NULL,
                      created REAL NOT NULL,
                      updated REAL NOT NULL,
                      relative_path TEXT NOT NULL UNIQUE,
                      tags_json TEXT NOT NULL DEFAULT '[]',
                      properties_json TEXT NOT NULL DEFAULT '{}'
                    );

                    CREATE INDEX objects_type_id ON objects(type_id);
                    CREATE INDEX objects_created ON objects(created);

                    CREATE TABLE links (
                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                      source_id TEXT NOT NULL,
                      target TEXT NOT NULL,
                      label TEXT,
                      FOREIGN KEY(source_id) REFERENCES objects(id) ON DELETE CASCADE
                    );

                    CREATE INDEX links_source ON links(source_id);
                    CREATE INDEX links_target ON links(target);

                    CREATE TABLE tags (
                      object_id TEXT NOT NULL,
                      tag TEXT NOT NULL,
                      PRIMARY KEY (object_id, tag),
                      FOREIGN KEY(object_id) REFERENCES objects(id) ON DELETE CASCADE
                    );

                    CREATE INDEX tags_tag ON tags(tag);

                    CREATE TABLE properties_idx (
                      object_id TEXT NOT NULL,
                      key TEXT NOT NULL,
                      value_text TEXT,
                      value_number REAL,
                      value_bool INTEGER,
                      value_date REAL,
                      PRIMARY KEY (object_id, key),
                      FOREIGN KEY(object_id) REFERENCES objects(id) ON DELETE CASCADE
                    );

                    CREATE INDEX properties_idx_key ON properties_idx(key);

                    CREATE VIRTUAL TABLE blocks_fts USING fts5(
                      object_id UNINDEXED,
                      title,
                      body,
                      tokenize = 'porter unicode61'
                    );
                    """
            )
        }
        try migrator.migrate(dbQueue)
    }
}
