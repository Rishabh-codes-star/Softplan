import Foundation

/// All timeline math works in whole "day indices" — days since 2000-01-01 in the
/// user's local calendar. Day-level precision is the finest unit in Softplan.
enum DayMath {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    static let epoch: Date = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1))!

    static func day(from date: Date) -> Int {
        calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: date)).day ?? 0
    }

    static func date(from day: Int) -> Date {
        calendar.date(byAdding: .day, value: day, to: epoch) ?? epoch
    }

    static func today() -> Int { day(from: Date()) }

    /// First day of the month containing `day`, plus that month/year.
    static func monthStart(containing day: Int) -> (startDay: Int, month: Int, year: Int) {
        let d = date(from: day)
        let comps = calendar.dateComponents([.year, .month], from: d)
        let start = calendar.date(from: comps) ?? d
        return (self.day(from: start), comps.month ?? 1, comps.year ?? 2000)
    }

    static func nextMonthStart(after monthStartDay: Int) -> Int {
        let d = date(from: monthStartDay)
        let next = calendar.date(byAdding: .month, value: 1, to: d) ?? d
        return day(from: next)
    }

    static func yearStart(containing day: Int) -> (startDay: Int, year: Int) {
        let d = date(from: day)
        let year = calendar.component(.year, from: d)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? d
        return (self.day(from: start), year)
    }

    static func nextYearStart(after yearStartDay: Int) -> Int {
        let d = date(from: yearStartDay)
        let next = calendar.date(byAdding: .year, value: 1, to: d) ?? d
        return day(from: next)
    }

    static func daysInMonth(startingAt monthStartDay: Int) -> Int {
        nextMonthStart(after: monthStartDay) - monthStartDay
    }

    // MARK: Formatting

    static let shortMonthNames: [String] = formatter(for: "").shortMonthSymbols ?? []

    static let dayMonthFormatter = formatter(for: "dd MMMM")
    static let dayMonthYearFormatter = formatter(for: "dd MMM yyyy")

    /// Month names still follow the user's language, but the calendar is pinned
    /// to the one the timeline is built on: a locale defaulting to a non-
    /// Gregorian calendar would otherwise label days the ruler never drew.
    static func formatter(for format: String) -> DateFormatter {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        if !format.isEmpty { df.dateFormat = format }
        return df
    }
}
