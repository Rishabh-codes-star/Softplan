import Foundation
import SwiftUI

enum DateRangeEndpoint: Equatable {
    case start
    case end
}

struct DateRangePicker: View {
    @Binding private var startDate: Date
    @Binding private var endDate: Date

    @State private var draftStartDate: Date
    @State private var draftEndDate: Date
    @State private var displayedMonth: Date
    @State private var activeEndpoint: DateRangeEndpoint

    private let onDismiss: () -> Void

    init(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        initialEndpoint: DateRangeEndpoint,
        onDismiss: @escaping () -> Void
    ) {
        _startDate = startDate
        _endDate = endDate
        _draftStartDate = State(initialValue: startDate.wrappedValue)
        _draftEndDate = State(initialValue: endDate.wrappedValue)
        _displayedMonth = State(initialValue: Self.monthStart(for: startDate.wrappedValue))
        _activeEndpoint = State(initialValue: initialEndpoint)
        self.onDismiss = onDismiss
    }

    private static let fullDateFormatter = DayMath.formatter(for: "d MMM yyyy")

    private var followingMonth: Date {
        DayMath.calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                endpointButton("From", date: draftStartDate, endpoint: .start)
                endpointButton("To", date: draftEndDate, endpoint: .end)
            }
            .padding(20)

            Divider().overlay(UI.controlBorder)

            HStack(alignment: .top, spacing: 14) {
                navigationButton("chevron.left", label: "Previous month") {
                    shiftMonth(by: -1)
                }

                DateRangeMonth(
                    month: displayedMonth,
                    startDate: draftStartDate,
                    endDate: draftEndDate,
                    onSelect: choose
                )

                Divider().frame(height: 250)

                DateRangeMonth(
                    month: followingMonth,
                    startDate: draftStartDate,
                    endDate: draftEndDate,
                    onSelect: choose
                )

                navigationButton("chevron.right", label: "Next month") {
                    shiftMonth(by: 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)

            Divider().overlay(UI.controlBorder)

            HStack {
                Button("Cancel", action: onDismiss)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Apply dates") {
                    startDate = draftStartDate
                    endDate = draftEndDate
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(UI.labelPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func endpointButton(
        _ title: String,
        date: Date,
        endpoint: DateRangeEndpoint
    ) -> some View {
        Button {
            activeEndpoint = endpoint
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(UI.labelSecondary)
                Text(Self.fullDateFormatter.string(from: date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(UI.labelPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(UI.inputFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                activeEndpoint == endpoint ? UI.labelPrimary : UI.inputBorder,
                                lineWidth: activeEndpoint == endpoint ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(Self.fullDateFormatter.string(from: date))
        .accessibilityAddTraits(activeEndpoint == endpoint ? [.isSelected] : [])
    }

    private func navigationButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(UI.labelPrimary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(UI.inputFill))
        }
        .buttonStyle(.plain)
        .padding(.top, 42)
        .help(label)
        .accessibilityLabel(label)
    }

    private func choose(_ date: Date) {
        switch activeEndpoint {
        case .start:
            draftStartDate = date
            if date > draftEndDate {
                draftEndDate = date
            }
            activeEndpoint = .end
        case .end:
            draftEndDate = max(date, draftStartDate)
        }
    }

    private func shiftMonth(by amount: Int) {
        displayedMonth = DayMath.calendar.date(byAdding: .month, value: amount, to: displayedMonth) ?? displayedMonth
    }

    fileprivate static func monthStart(for date: Date) -> Date {
        let components = DayMath.calendar.dateComponents([.year, .month], from: date)
        return DayMath.calendar.date(from: components) ?? date
    }
}

private struct DateRangeMonth: View {
    let month: Date
    let startDate: Date
    let endDate: Date
    let onSelect: (Date) -> Void

    private static let monthFormatter = DayMath.formatter(for: "MMMM yyyy")

    private static let accessibilityFormatter: DateFormatter = {
        let formatter = DayMath.formatter(for: "")
        formatter.dateStyle = .full
        return formatter
    }()

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 10) {
            Text(Self.monthFormatter.string(from: month))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(UI.labelPrimary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(UI.labelSecondary)
                        .frame(height: 20)
                        .accessibilityHidden(true)
                }

                ForEach(0..<42, id: \.self) { index in
                    if let date = date(at: index) {
                        dateButton(date)
                    } else {
                        Color.clear
                            .frame(height: 30)
                    }
                }
            }
        }
        .frame(width: 240)
    }

    private func dateButton(_ date: Date) -> some View {
        let endpoint = isEndpoint(date)
        return Button {
            onSelect(date)
        } label: {
            ZStack {
                if isWithinRange(date) && !endpoint {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(UI.inputFill)
                }
                if endpoint {
                    Circle().fill(UI.labelPrimary)
                } else if DayMath.calendar.isDateInToday(date) {
                    Circle().strokeBorder(UI.labelPrimary.opacity(0.45), lineWidth: 1)
                }
                Text(String(DayMath.calendar.component(.day, from: date)))
                    .font(.system(size: 12, weight: endpoint ? .semibold : .regular))
                    .foregroundColor(endpoint ? .white : UI.labelPrimary)
            }
            .frame(height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.accessibilityFormatter.string(from: date))
        .accessibilityAddTraits(endpoint ? [.isSelected] : [])
    }

    private func date(at index: Int) -> Date? {
        let monthStart = DateRangePicker.monthStart(for: month)
        let leadingDays = DayMath.calendar.component(.weekday, from: monthStart) - 1
        let day = index - leadingDays + 1
        let count = DayMath.calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        guard day >= 1, day <= count else { return nil }
        return DayMath.calendar.date(byAdding: .day, value: day - 1, to: monthStart)
    }

    private func isEndpoint(_ date: Date) -> Bool {
        DayMath.calendar.isDate(date, inSameDayAs: startDate) ||
            DayMath.calendar.isDate(date, inSameDayAs: endDate)
    }

    private func isWithinRange(_ date: Date) -> Bool {
        let day = DayMath.calendar.startOfDay(for: date)
        let lower = DayMath.calendar.startOfDay(for: min(startDate, endDate))
        let upper = DayMath.calendar.startOfDay(for: max(startDate, endDate))
        return day >= lower && day <= upper
    }
}