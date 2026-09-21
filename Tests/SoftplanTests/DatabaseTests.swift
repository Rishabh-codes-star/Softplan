import SQLite3
import XCTest
@testable import Softplan

final class DatabaseTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SoftplanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testPlansSurviveAWriteAndReadBack() throws {
        let db = try Database(directory: directory)
        let plan = PlanEvent(
            title: "Website launch",
            startDay: 9_000,
            endDay: 9_030,
            paletteId: "teal",
            location: "Bengaluru",
            category: "Work",
            tags: "launch,web",
            notes: "Line one\nLine two"
        )
        try db.upsert(plan)

        let loaded = try Database(directory: directory).fetchAll()
        XCTAssertEqual(loaded, [plan])
    }

    func testUpsertUpdatesInPlace() throws {
        let db = try Database(directory: directory)
        var plan = PlanEvent(title: "Draft", startDay: 10, endDay: 20, paletteId: "sage")
        try db.upsert(plan)

        plan.title = "Final"
        plan.endDay = 25
        try db.upsert(plan)

        let loaded = try db.fetchAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Final")
        XCTAssertEqual(loaded.first?.endDay, 25)
    }

    func testDeleteRemovesOnlyItsOwnRow() throws {
        let db = try Database(directory: directory)
        let keep = PlanEvent(title: "Keep", startDay: 0, endDay: 1, paletteId: "navy")
        let drop = PlanEvent(title: "Drop", startDay: 2, endDay: 3, paletteId: "brick")
        try db.upsert(keep)
        try db.upsert(drop)

        try db.delete(id: drop.id)
        XCTAssertEqual(try db.fetchAll().map(\.title), ["Keep"])
    }

    func testTitlesAreStoredAsTextNotSQL() throws {
        let db = try Database(directory: directory)
        let nasty = PlanEvent(
            title: "'; DROP TABLE events; --",
            startDay: 5,
            endDay: 6,
            paletteId: "mauve"
        )
        try db.upsert(nasty)

        let loaded = try db.fetchAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "'; DROP TABLE events; --")
    }

    func testAnOlderDatabaseGainsTheColumnsItIsMissing() throws {
        try writeLegacyDatabase()

        // Opening runs the migration; without it this read fails on `location`.
        let loaded = try Database(directory: directory).fetchAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Legacy plan")
        XCTAssertEqual(loaded.first?.notes, "")
        XCTAssertEqual(loaded.first?.location, "")
    }

    // MARK: Helpers

    /// The schema as it stood before location, category, tags and notes existed.
    private func writeLegacyDatabase() throws {
        var handle: OpaquePointer?
        let path = directory.appendingPathComponent("softplan.sqlite").path
        XCTAssertEqual(sqlite3_open(path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }

        let sql = """
            CREATE TABLE events (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                start_day INTEGER NOT NULL,
                end_day INTEGER NOT NULL,
                palette TEXT NOT NULL
            );
            INSERT INTO events (id, title, start_day, end_day, palette)
            VALUES ('\(UUID().uuidString)', 'Legacy plan', 100, 120, 'olive');
            """
        XCTAssertEqual(sqlite3_exec(handle, sql, nil, nil, nil), SQLITE_OK)
    }
}
