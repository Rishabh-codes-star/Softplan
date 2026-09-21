import XCTest
@testable import Softplan

/// Stacking is what keeps bars from covering each other, and it is pure
/// geometry — worth pinning down away from the canvas.
final class EventLayoutTests: XCTestCase {
    func testPlansThatDoNotOverlapShareARow() {
        let layout = EventLayout.layout(
            events: [plan(from: 0, to: 9), plan(from: 20, to: 29)],
            viewport: viewport(),
            expandedEventIDs: []
        )
        XCTAssertEqual(layout.items.count, 2)
        XCTAssertEqual(Set(layout.items.map(\.row)), [0])
    }

    func testOverlappingPlansStack() {
        let layout = EventLayout.layout(
            events: [plan(from: 0, to: 9), plan(from: 5, to: 14), plan(from: 6, to: 20)],
            viewport: viewport(),
            expandedEventIDs: []
        )
        XCTAssertEqual(layout.items.map(\.row).sorted(), [0, 1, 2])

        // Rows are laid out top to bottom, one bar height plus the gap apart.
        let ys = layout.items.sorted { $0.row < $1.row }.map(\.y)
        XCTAssertEqual(ys[0], UI.timelineBarsTop)
        XCTAssertEqual(ys[1] - ys[0], UI.barHeight + UI.rowGap, accuracy: 0.001)
    }

    func testPlansOffScreenAreDropped() {
        let layout = EventLayout.layout(
            events: [plan(from: 0, to: 9), plan(from: 10_000, to: 10_010)],
            viewport: viewport(),
            expandedEventIDs: []
        )
        XCTAssertEqual(layout.items.count, 1)
        XCTAssertEqual(layout.items.first?.event.startDay, 0)
    }

    func testVeryShortPlansKeepAMinimumWidth() {
        let layout = EventLayout.layout(
            events: [plan(from: 0, to: 0)],
            viewport: viewport(pixelsPerDay: 0.5),
            expandedEventIDs: []
        )
        XCTAssertEqual(layout.items.first?.width, UI.minBarWidth)
    }

    func testExpandingAPlanWithNotesGrowsItsRow() {
        let described = plan(from: 0, to: 99, notes: "Ship the thing, then write about shipping it.")
        let collapsed = EventLayout.layout(
            events: [described],
            viewport: viewport(),
            expandedEventIDs: []
        )
        let expanded = EventLayout.layout(
            events: [described],
            viewport: viewport(),
            expandedEventIDs: [described.id]
        )

        XCTAssertEqual(collapsed.items.first?.notesLines, 0)
        XCTAssertEqual(collapsed.items.first?.height, UI.barHeight)
        XCTAssertGreaterThan(expanded.items.first?.notesLines ?? 0, 0)
        XCTAssertGreaterThan(expanded.items.first?.height ?? 0, UI.barHeight)
    }

    func testAPlanWithoutNotesNeverExpands() {
        let bare = plan(from: 0, to: 99)
        let layout = EventLayout.layout(
            events: [bare],
            viewport: viewport(),
            expandedEventIDs: [bare.id]
        )
        XCTAssertEqual(layout.items.first?.notesLines, 0)
    }

    // MARK: Helpers

    private func plan(from startDay: Int, to endDay: Int, notes: String = "") -> PlanEvent {
        PlanEvent(
            title: "Plan",
            startDay: startDay,
            endDay: endDay,
            paletteId: Palette.colors[0].id,
            notes: notes
        )
    }

    /// A viewport pinned to day 0 so x = day × pixelsPerDay, backed by a scratch
    /// defaults suite: the real one holds the user's saved scroll position.
    private func viewport(pixelsPerDay: Double = 4, width: Double = 1000) -> Viewport {
        let suite = "SoftplanTests.viewport"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let viewport = Viewport(defaults: defaults)
        viewport.width = width
        viewport.pixelsPerDay = pixelsPerDay
        viewport.leftDay = 0
        return viewport
    }
}
