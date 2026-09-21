import Foundation

/// A plan on the timeline. Always a date range (inclusive of both ends),
/// day-level precision, minimum one day.
struct PlanEvent: Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDay: Int
    var endDay: Int
    var paletteId: String
    var location: String
    var category: String
    var tags: String
    var notes: String

    init(
        id: UUID = UUID(),
        title: String = "",
        startDay: Int,
        endDay: Int,
        paletteId: String,
        location: String = "",
        category: String = "",
        tags: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.startDay = startDay
        self.endDay = max(endDay, startDay)
        self.paletteId = paletteId
        self.location = location
        self.category = category
        self.tags = tags
        self.notes = notes
    }

    var durationDays: Int { endDay - startDay + 1 }

    /// "14 September → 03 October", with years appended when the range crosses years.
    var dateRangeLabel: String { rangeLabel(joinedBy: "→") }

    /// The same range spoken rather than drawn: VoiceOver reads the arrow aloud.
    var spokenDateRange: String { rangeLabel(joinedBy: "to") }

    private func rangeLabel(joinedBy separator: String) -> String {
        let start = DayMath.date(from: startDay)
        let end = DayMath.date(from: endDay)
        let sameYear = DayMath.calendar.component(.year, from: start)
            == DayMath.calendar.component(.year, from: end)
        let formatter = sameYear ? DayMath.dayMonthFormatter : DayMath.dayMonthYearFormatter
        return "\(formatter.string(from: start)) \(separator) \(formatter.string(from: end))"
    }
}
