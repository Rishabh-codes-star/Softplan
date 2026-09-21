import XCTest
@testable import Softplan

/// The whole timeline is drawn from day indices, so this arithmetic has to hold
/// across month lengths, leap years and year boundaries.
final class DayMathTests: XCTestCase {
    func testDayAndDateRoundTrip() {
        for day in [0, 1, 366, 8_000, 20_000] {
            XCTAssertEqual(DayMath.day(from: DayMath.date(from: day)), day)
        }
    }

    func testEpochIsDayZero() {
        XCTAssertEqual(DayMath.day(from: DayMath.epoch), 0)
    }

    func testMonthStartAndNext() {
        let march = DayMath.day(from: date(2024, 3, 17))
        let (start, month, year) = DayMath.monthStart(containing: march)

        XCTAssertEqual(start, DayMath.day(from: date(2024, 3, 1)))
        XCTAssertEqual(month, 3)
        XCTAssertEqual(year, 2024)
        XCTAssertEqual(DayMath.nextMonthStart(after: start), DayMath.day(from: date(2024, 4, 1)))
    }

    func testMonthStartRollsOverAYearBoundary() {
        let december = DayMath.day(from: date(2024, 12, 5))
        let (start, _, _) = DayMath.monthStart(containing: december)
        XCTAssertEqual(DayMath.nextMonthStart(after: start), DayMath.day(from: date(2025, 1, 1)))
    }

    func testDaysInMonthHandlesLeapYears() {
        XCTAssertEqual(daysInMonth(2024, 2), 29)
        XCTAssertEqual(daysInMonth(2025, 2), 28)
        XCTAssertEqual(daysInMonth(2025, 4), 30)
        XCTAssertEqual(daysInMonth(2025, 12), 31)
    }

    func testYearStartAndNext() {
        let (start, year) = DayMath.yearStart(containing: DayMath.day(from: date(2031, 7, 4)))
        XCTAssertEqual(year, 2031)
        XCTAssertEqual(start, DayMath.day(from: date(2031, 1, 1)))
        XCTAssertEqual(DayMath.nextYearStart(after: start), DayMath.day(from: date(2032, 1, 1)))
    }

    // MARK: Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DayMath.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func daysInMonth(_ year: Int, _ month: Int) -> Int {
        DayMath.daysInMonth(startingAt: DayMath.day(from: date(year, month, 1)))
    }
}
