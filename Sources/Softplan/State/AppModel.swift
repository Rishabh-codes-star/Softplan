import Combine
import Foundation
import OSLog

/// What the editor sheet is doing: creating a fresh plan or editing an existing one.
struct EditorState: Identifiable {
    let id = UUID()
    var isNew: Bool
    var draft: PlanEvent
}

final class AppModel: ObservableObject {
    @Published var events: [PlanEvent] = []
    @Published var editorState: EditorState?
    @Published private(set) var isRefreshing = false

    private let db: Database?
    private let log = Logger(subsystem: "com.softplan.app", category: "store")

    init() {
        do {
            db = try Database()
        } catch {
            // The timeline still works in memory; only persistence is lost, and
            // the reason belongs in the log rather than in the user's face.
            db = nil
            log.error("could not open the plan database: \(String(describing: error), privacy: .public)")
        }
        events = loadEvents() ?? []
    }

    // MARK: Editing lifecycle

    func beginCreate(startDay: Int, endDay: Int) {
        guard editorState == nil else { return }
        let draft = PlanEvent(
            startDay: startDay,
            endDay: endDay,
            paletteId: Palette.leastUsedId(in: events)
        )
        editorState = EditorState(isNew: true, draft: draft)
    }

    func beginEdit(_ event: PlanEvent) {
        guard editorState == nil else { return }
        editorState = EditorState(isNew: false, draft: event)
    }

    func reloadEvents() {
        guard !isRefreshing else { return }
        isRefreshing = true

        // Long enough for the white overlay to paint and read as a deliberate
        // refresh; the read itself is a handful of local rows.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { [weak self] in
            guard let self else { return }
            // Keep what is on screen if the read fails: an empty timeline would
            // read as "your plans are gone" rather than "the disk said no".
            if let fresh = self.loadEvents() {
                self.events = fresh
            }
            self.isRefreshing = false
        }
    }

    // MARK: Mutations

    func save(_ event: PlanEvent) {
        if let i = events.firstIndex(where: { $0.id == event.id }) {
            events[i] = event
        } else {
            events.append(event)
        }
        write("save plan") { try $0.upsert(event) }
    }

    /// Update in memory only — used while a drag is in flight, for live feedback.
    func updateLive(_ event: PlanEvent) {
        guard let i = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[i] = event
    }

    /// Persist whatever the in-memory copy of this event currently is.
    func commit(_ id: UUID) {
        guard let event = events.first(where: { $0.id == id }) else { return }
        write("commit plan") { try $0.upsert(event) }
    }

    func delete(_ id: UUID) {
        events.removeAll { $0.id == id }
        write("delete plan") { try $0.delete(id: id) }
    }

    // MARK: Storage

    /// nil when the plans could not be read at all, which is not the same thing
    /// as having no plans.
    private func loadEvents() -> [PlanEvent]? {
        guard let db else { return nil }
        do {
            return try db.fetchAll()
        } catch {
            log.error("could not read plans: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Runs a write against the database, keeping the in-memory timeline intact
    /// if the disk refuses. `what` names the operation for the log — never the
    /// plan's contents.
    private func write(_ what: String, _ body: (Database) throws -> Void) {
        guard let db else { return }
        do {
            try body(db)
        } catch {
            log.error("\(what, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}
