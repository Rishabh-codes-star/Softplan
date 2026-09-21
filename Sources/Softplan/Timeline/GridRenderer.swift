import SwiftUI

/// Draws the time grid in the Figma style: labels along a row near the top,
/// tall major ticks at month/year starts, and fine minor lines running the
/// full height of the canvas. Granularity adapts to zoom:
/// day lines → month lines → year lines. The red today line sits behind bars.
enum GridRenderer {
    /// Which unit the grid resolves to at the current zoom. Both the ruler and
    /// the canvas below it must agree, so the thresholds live in one place.
    private enum Tier {
        case days, months, years

        init(pixelsPerDay ppd: Double) {
            if ppd >= 2.6 {
                self = .days
            } else if ppd * 30.44 >= 11 {
                self = .months
            } else {
                self = .years
            }
        }
    }

    // MARK: Ruler — the fixed strip carrying month and year labels

    static func drawRuler(context: inout GraphicsContext, size: CGSize, viewport: Viewport) {
        let (d0, d1) = visibleDays(size: size, viewport: viewport)
        let ppd = viewport.pixelsPerDay

        func vline(_ x: CGFloat) {
            stroke(&context, x: x, from: UI.majorTickTop, to: size.height, color: UI.gridMajor, width: 1.2)
        }

        func label(_ text: String, at x: CGFloat, size fontSize: CGFloat, primary: Bool) {
            let t = Text(text)
                .font(.system(size: fontSize, weight: primary ? .semibold : .medium))
                .foregroundColor(primary ? UI.labelPrimary : UI.labelSecondary)
            context.draw(t, at: CGPoint(x: x + 6, y: UI.gridLabelBaseline), anchor: .bottomLeading)
        }

        switch Tier(pixelsPerDay: ppd) {
        case .days:
            var (mStart, month, _) = DayMath.monthStart(containing: d0)
            while mStart <= d1 {
                let mx = viewport.x(forDay: Double(mStart))
                vline(mx)
                label(shortMonthName(month), at: mx, size: 17, primary: true)
                mStart = DayMath.nextMonthStart(after: mStart)
                month = month == 12 ? 1 : month + 1
            }

        case .months:
            let monthWidth = ppd * 30.44
            var (mStart, month, year) = DayMath.monthStart(containing: d0)
            while mStart <= d1 {
                let mx = viewport.x(forDay: Double(mStart))
                if month == 1 {
                    vline(mx)
                    label(String(year), at: mx, size: 17, primary: true)
                } else if monthWidth >= 44 {
                    label(shortMonthName(month), at: mx, size: 13, primary: false)
                }
                mStart = DayMath.nextMonthStart(after: mStart)
                if month == 12 { month = 1; year += 1 } else { month += 1 }
            }

        case .years:
            var (yStart, year) = DayMath.yearStart(containing: d0)
            while yStart <= d1 {
                let yx = viewport.x(forDay: Double(yStart))
                vline(yx)
                if ppd * 365.25 >= 40 {
                    label(String(year), at: yx, size: 17, primary: true)
                }
                yStart = DayMath.nextYearStart(after: yStart)
                year += 1
            }
        }

        drawTodayLine(&context, size: size, viewport: viewport, top: UI.majorTickTop - 8)
    }

    // MARK: Canvas — full-height gridlines behind the bars

    static func drawTimeline(context: inout GraphicsContext, size: CGSize, viewport: Viewport) {
        let (d0, d1) = visibleDays(size: size, viewport: viewport)
        let ppd = viewport.pixelsPerDay

        func vline(_ x: CGFloat, major: Bool) {
            stroke(
                &context, x: x, from: 0, to: size.height,
                color: major ? UI.gridMajor : UI.gridMinor,
                width: major ? 1.2 : 0.75
            )
        }

        switch Tier(pixelsPerDay: ppd) {
        case .days:
            var (mStart, _, _) = DayMath.monthStart(containing: d0)
            while mStart <= d1 {
                vline(viewport.x(forDay: Double(mStart)), major: true)
                for day in 1..<DayMath.daysInMonth(startingAt: mStart) {
                    vline(viewport.x(forDay: Double(mStart + day)), major: false)
                }
                mStart = DayMath.nextMonthStart(after: mStart)
            }

        case .months:
            var (mStart, month, _) = DayMath.monthStart(containing: d0)
            while mStart <= d1 {
                vline(viewport.x(forDay: Double(mStart)), major: month == 1)
                mStart = DayMath.nextMonthStart(after: mStart)
                month = month == 12 ? 1 : month + 1
            }

        case .years:
            let quarterWidth = ppd * 91.3
            var (yStart, _) = DayMath.yearStart(containing: d0)
            while yStart <= d1 {
                vline(viewport.x(forDay: Double(yStart)), major: true)
                if quarterWidth >= 8 {
                    let next = DayMath.nextYearStart(after: yStart)
                    for quarter in 1...3 {
                        let day = yStart + Int(Double(next - yStart) * Double(quarter) / 4.0)
                        vline(viewport.x(forDay: Double(day)), major: false)
                    }
                }
                yStart = DayMath.nextYearStart(after: yStart)
            }
        }

        drawTodayLine(&context, size: size, viewport: viewport, top: 0)
    }

    // MARK: Shared drawing

    /// Day indices just outside the visible edges, so partially visible months
    /// and their labels are still drawn.
    private static func visibleDays(size: CGSize, viewport: Viewport) -> (Int, Int) {
        (
            Int(floor(viewport.day(atX: 0))) - 1,
            Int(ceil(viewport.day(atX: size.width))) + 1
        )
    }

    private static func stroke(
        _ context: inout GraphicsContext,
        x: CGFloat, from top: CGFloat, to bottom: CGFloat,
        color: Color, width: CGFloat
    ) {
        var path = Path()
        path.move(to: CGPoint(x: x, y: top))
        path.addLine(to: CGPoint(x: x, y: bottom))
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private static func drawTodayLine(
        _ context: inout GraphicsContext,
        size: CGSize,
        viewport: Viewport,
        top: CGFloat
    ) {
        let x = viewport.x(forDay: Double(DayMath.today()))
        guard x > -2, x < size.width + 2 else { return }
        stroke(&context, x: x, from: top, to: size.height, color: UI.todayRed, width: 1.5)
    }

    private static func shortMonthName(_ month: Int) -> String {
        DayMath.shortMonthNames.indices.contains(month - 1) ? DayMath.shortMonthNames[month - 1] : ""
    }
}
