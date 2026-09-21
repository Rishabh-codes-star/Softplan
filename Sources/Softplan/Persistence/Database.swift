import Foundation
import SQLite3

/// Tells SQLite to copy bound strings instead of borrowing the pointer, which
/// would dangle once the Swift string goes out of scope.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case execFailed(String)
    case prepareFailed(String)

    /// Without this the SQLite message is lost behind Foundation's generic
    /// "the operation couldn't be completed" text.
    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "could not open the database: \(message)"
        case .execFailed(let message): "statement failed: \(message)"
        case .prepareFailed(let message): "could not prepare statement: \(message)"
        }
    }
}

/// Thin wrapper over the system SQLite. One table, synchronous access —
/// the data set is a personal plan, tiny by definition. Every value goes in
/// through a bound parameter, so plan text is never parsed as SQL.
final class Database {
    private var db: OpaquePointer?

    /// Columns beyond the original schema, in the order they were introduced.
    /// A database written by an older build is missing the later ones; each is
    /// added on open so a query never fails on a column that isn't there.
    private static let addedColumns: [(name: String, definition: String)] = [
        ("location", "location TEXT NOT NULL DEFAULT ''"),
        ("category", "category TEXT NOT NULL DEFAULT ''"),
        ("tags", "tags TEXT NOT NULL DEFAULT ''"),
        ("notes", "notes TEXT NOT NULL DEFAULT ''"),
        ("updated_at", "updated_at REAL"),
    ]

    /// `directory` defaults to the app's Application Support folder; tests pass
    /// a temporary one instead of touching the real plan file.
    init(directory: URL? = nil) throws {
        let fileManager = FileManager.default
        let dir = try directory ?? fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Softplan", isDirectory: true)
        try fileManager.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let path = dir.appendingPathComponent("softplan.sqlite").path

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        // Plans are private notes: keep them readable only by their owner.
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)

        try exec("""
            CREATE TABLE IF NOT EXISTS events (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                start_day INTEGER NOT NULL,
                end_day INTEGER NOT NULL,
                palette TEXT NOT NULL,
                location TEXT NOT NULL DEFAULT '',
                category TEXT NOT NULL DEFAULT '',
                tags TEXT NOT NULL DEFAULT '',
                notes TEXT NOT NULL DEFAULT '',
                updated_at REAL
            )
            """)
        try migrate()
    }

    deinit { sqlite3_close(db) }

    // MARK: Schema

    private func migrate() throws {
        let existing = try columnNames()
        for column in Self.addedColumns where !existing.contains(column.name) {
            // Definitions are literals from `addedColumns`, never user input.
            try exec("ALTER TABLE events ADD COLUMN \(column.definition)")
        }
    }

    private func columnNames() throws -> Set<String> {
        let stmt = try prepare("PRAGMA table_info(events)")
        defer { sqlite3_finalize(stmt) }

        var names: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = sqlite3_column_text(stmt, 1) {
                names.insert(String(cString: name))
            }
        }
        return names
    }

    // MARK: Statements

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK else {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errMsg)
            throw DatabaseError.execFailed(msg)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    // MARK: Reads and writes

    func fetchAll() throws -> [PlanEvent] {
        let stmt = try prepare("""
            SELECT id, title, start_day, end_day, palette, location,
                   category, tags, notes
            FROM events ORDER BY start_day, title
            """)
        defer { sqlite3_finalize(stmt) }

        var events: [PlanEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func text(_ col: Int32) -> String {
                guard let c = sqlite3_column_text(stmt, col) else { return "" }
                return String(cString: c)
            }
            guard let id = UUID(uuidString: text(0)) else { continue }
            events.append(PlanEvent(
                id: id,
                title: text(1),
                startDay: Int(sqlite3_column_int64(stmt, 2)),
                endDay: Int(sqlite3_column_int64(stmt, 3)),
                paletteId: text(4),
                location: text(5),
                category: text(6),
                tags: text(7),
                notes: text(8)
            ))
        }
        return events
    }

    func upsert(_ e: PlanEvent) throws {
        let stmt = try prepare("""
            INSERT INTO events (id, title, start_day, end_day, palette,
                                location, category, tags, notes, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                start_day = excluded.start_day,
                end_day = excluded.end_day,
                palette = excluded.palette,
                location = excluded.location,
                category = excluded.category,
                tags = excluded.tags,
                notes = excluded.notes,
                updated_at = excluded.updated_at
            """)
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, e.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, e.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 3, Int64(e.startDay))
        sqlite3_bind_int64(stmt, 4, Int64(e.endDay))
        sqlite3_bind_text(stmt, 5, e.paletteId, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 6, e.location, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 7, e.category, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 8, e.tags, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 9, e.notes, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 10, Date().timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    func delete(id: UUID) throws {
        let stmt = try prepare("DELETE FROM events WHERE id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }
}
