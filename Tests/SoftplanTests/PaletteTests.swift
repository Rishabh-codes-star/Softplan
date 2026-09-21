import XCTest
@testable import Softplan

final class PaletteTests: XCTestCase {
    func testUnknownIdFallsBackToTheFirstFamily() {
        XCTAssertEqual(Palette.color(for: "not-a-color").id, Palette.colors[0].id)
    }

    func testEmptyTimelineTakesTheFirstFamily() {
        XCTAssertEqual(Palette.leastUsedId(in: []), Palette.colors[0].id)
    }

    func testUsedFamiliesAreSkippedInPaletteOrder() {
        let used = Palette.colors.prefix(3).map {
            PlanEvent(startDay: 0, endDay: 1, paletteId: $0.id)
        }
        XCTAssertEqual(Palette.leastUsedId(in: used), Palette.colors[3].id)
    }

    func testTheLeastUsedFamilyWinsOnceEveryFamilyIsTaken() {
        var events = Palette.colors.map { PlanEvent(startDay: 0, endDay: 1, paletteId: $0.id) }
        // Everything used once except one family, which is used twice.
        events.append(PlanEvent(startDay: 0, endDay: 1, paletteId: Palette.colors[0].id))
        XCTAssertEqual(Palette.leastUsedId(in: events), Palette.colors[1].id)
    }
}
