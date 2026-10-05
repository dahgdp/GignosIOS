import Foundation
import GRDB

/// On-device cache for catalogs and record details. The API stays the source of
/// truth. This is what lets the app open instantly, search the full catalog
/// locally, and keep working offline.
final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    static let shared: AppDatabase = {
        do {
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            // Pool = WAL mode, so search can read while a sync is writing.
            let pool = try DatabasePool(path: folder.appendingPathComponent("gignos.sqlite").path)
            return try AppDatabase(pool)
        } catch {
            // A cache that won't open shouldn't brick the app. Fall back to memory,
            // which behaves like the old sample (network only, nothing persisted).
            return try! AppDatabase(DatabaseQueue())
        }
    }()

    static func inMemory() throws -> AppDatabase { try AppDatabase(DatabaseQueue()) }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // Prototype convenience: wipe the cache when the schema changes.
        // Remove before saved records move into this database.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        migrator.registerMigration("v1") { db in
            try db.create(table: "record") { t in
                // Explicit integer key: the FTS index points at it, and implicit
                // rowids can get renumbered by VACUUM.
                t.autoIncrementedPrimaryKey("rowID")
                t.column("id", .text).notNull().unique()        // "sites/laetoli", "sources/1227"
                t.column("section", .text).notNull().indexed()
                t.column("position", .integer).notNull()        // API order, keeps ordering stable
                t.column("title", .text).notNull()
                t.column("subtitle", .text).notNull()
                t.column("country", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("payload", .blob).notNull()            // full CatalogRecord as JSON
            }
            // Full-text index kept in sync with `record` by triggers.
            // unicode61 strips diacritics, so "cafe" finds "Café".
            try db.create(virtualTable: "record_ft", using: FTS5()) { t in
                t.synchronize(withTable: "record")
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("subtitle")
                t.column("country")
                t.column("kind")
                t.column("summary")
            }
            try db.create(table: "sectionState") { t in
                t.column("section", .text).primaryKey()
                t.column("total", .integer).notNull()
                t.column("isComplete", .boolean).notNull()
                t.column("syncedAt", .datetime).notNull()
            }
            try db.create(table: "detail") { t in
                t.column("recordID", .text).primaryKey()
                t.column("payload", .blob).notNull()            // RecordDetail as JSON
                t.column("fetchedAt", .datetime).notNull()
            }
        }
        return migrator
    }
}

// MARK: - Rows

struct CachedRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "record"
    var rowID: Int64?
    var id: String
    var section: String
    var position: Int
    var title: String
    var subtitle: String
    var country: String
    var kind: String
    var summary: String
    var payload: Data

    init(_ record: CatalogRecord, position: Int) throws {
        rowID = nil
        id = record.id
        section = record.section.rawValue
        self.position = position
        title = record.title
        subtitle = record.subtitle
        country = record.country
        kind = record.kind
        summary = record.summary
        payload = try JSONEncoder().encode(record)
    }

    func decoded() throws -> CatalogRecord { try JSONDecoder().decode(CatalogRecord.self, from: payload) }
}

struct SectionState: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sectionState"
    var section: String
    var total: Int
    var isComplete: Bool   // false = only part of the catalog is cached (first run, or a sync died)
    var syncedAt: Date
}

struct CachedDetail: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "detail"
    var recordID: String
    var payload: Data
    var fetchedAt: Date
}

struct CatalogFacets: Sendable, Equatable {
    var kinds: [String] = []
    var countries: [String] = []
}

// MARK: - Catalog

extension AppDatabase {
    /// Swaps a section's rows in one transaction. Readers see the old copy or the
    /// new one, never a mix. Delete-then-insert (not INSERT OR REPLACE) so the
    /// FTS triggers fire for every removed row.
    func replace(_ section: WebsiteSection, with records: [CatalogRecord], total: Int, isComplete: Bool) async throws {
        let rows = try records.enumerated().map { try CachedRecord($0.element, position: $0.offset) }
        let key = section.rawValue
        try await writer.write { db in
            try CachedRecord.filter(Column("section") == key).deleteAll(db)
            for row in rows { try row.insert(db) }
            try SectionState(section: key, total: total, isComplete: isComplete, syncedAt: Date()).save(db)
        }
    }

    func state(_ section: WebsiteSection) async throws -> SectionState? {
        let key = section.rawValue
        return try await writer.read { db in try SectionState.fetchOne(db, key: key) }
    }

    func count(_ section: WebsiteSection) async throws -> Int {
        let key = section.rawValue
        return try await writer.read { db in try CachedRecord.filter(Column("section") == key).fetchCount(db) }
    }

    /// Search + filters + sort over everything cached for the section.
    /// Callers check `SectionState.isComplete` before calling results "complete".
    func search(_ section: WebsiteSection, filter: CatalogFilter) async throws -> [CatalogRecord] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = query.isEmpty ? nil : FTS5Pattern(matchingAllPrefixesIn: query)?.rawPattern
        if !query.isEmpty && pattern == nil { return [] }   // query was all punctuation
        let key = section.rawValue
        let kind = filter.kind == "All types" ? nil : filter.kind
        let country = filter.country == "All countries" ? nil : filter.country
        let byCountry = filter.sort == .country
        let collation = DatabaseCollation.localizedStandardCompare.name

        let rows = try await writer.read { db -> [CachedRecord] in
            var sql = "SELECT record.* FROM record"
            var arguments: StatementArguments = []
            if let pattern {
                sql += " JOIN record_ft ON record_ft.rowid = record.rowID AND record_ft MATCH ?"
                arguments += [pattern]
            }
            sql += " WHERE record.section = ?"
            arguments += [key]
            if let kind { sql += " AND record.kind = ?"; arguments += [kind] }
            if let country { sql += " AND record.country = ?"; arguments += [country] }
            sql += " ORDER BY "
            if byCountry { sql += "record.country COLLATE \(collation), " }
            sql += "record.title COLLATE \(collation), record.position"
            return try CachedRecord.fetchAll(db, sql: sql, arguments: arguments)
        }
        return try rows.map { try $0.decoded() }
    }

    /// Filter picker options, built from the whole cached section.
    func facets(_ section: WebsiteSection) async throws -> CatalogFacets {
        let key = section.rawValue
        let collation = DatabaseCollation.localizedStandardCompare.name
        return try await writer.read { db in
            func distinct(_ column: String) throws -> [String] {
                try String.fetchAll(db, sql: "SELECT DISTINCT \(column) FROM record WHERE section = ? AND \(column) != '' ORDER BY \(column) COLLATE \(collation)", arguments: [key])
            }
            return CatalogFacets(kinds: try distinct("kind"), countries: try distinct("country"))
        }
    }
}

// MARK: - Details

extension AppDatabase {
    func cachedDetail(_ record: CatalogRecord) async throws -> RecordDetail? {
        let id = record.id
        let row = try await writer.read { db in try CachedDetail.fetchOne(db, key: id) }
        guard let row else { return nil }
        return try JSONDecoder().decode(RecordDetail.self, from: row.payload)
    }

    func store(_ detail: RecordDetail) async throws {
        let row = CachedDetail(recordID: detail.record.id, payload: try JSONEncoder().encode(detail), fetchedAt: Date())
        try await writer.write { db in try row.save(db) }
    }
}
