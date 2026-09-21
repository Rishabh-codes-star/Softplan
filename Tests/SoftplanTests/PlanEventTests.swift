import XCTest
@testable import Softplan

final class PlanEventTests: XCTestCase {
    func testEndDayNeverPrecedesStartDay() {
        let event = PlanEvent(startDay: 100, endDay: 40, paletteId: "brick")
        XCTAssertEqual(event.startDay, 100)
        XCTAssertEqual(event.endDay, 100)
        XCTAssertEqual(event.durationDays, 1)
    }

    func testDurationCountsBothEnds() {
        XCTAssertEqual(PlanEvent(startDay: 10, endDay: 12, paletteId: "sage").durationDays, 3)
    }

    func testDrawnAndSpokenRangesDifferOnlyInTheJoin() {
        let event = PlanEvent(startDay: 9_000, endDay: 9_030, paletteId: "teal")
        XCTAssertTrue(event.dateRangeLabel.contains("→"))
        XCTAssertFalse(event.spokenDateRange.contains("→"))
        XCTAssertEqual(
            event.dateRangeLabel.replacingOccurrences(of: "→", with: "to"),
            event.spokenDateRange
        )
    }
}
