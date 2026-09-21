import Foundation
import CoreGraphics

struct LaidOutEvent: Identifiable {
    let event: PlanEvent
    let row: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    /// How many lines of the description the expanded bar reserves (0 = hidden).
    let notesLines: Int
    var id: UUID { event.id }
}

struct TimelineLayout {
    let items: [LaidOutEvent]
    let contentHeight: CGFloat
}

enum EventLayout {
    /// Greedy first-fit stacking in pixel space, with variable row heights.
    /// A plan grows for its description only after the user expands it.
    static func layout(
        events: [PlanEvent],
        viewport: Viewport,
        expandedEventIDs: Set<UUID>
    ) -> TimelineLayout {
        let sorted = events.sorted { a, b in
            if a.startDay != b.startDay { return a.startDay < b.startDay }
            return a.id.uuidString < b.id.uuidString
        }

        struct Placed {
            let event: PlanEvent
            let x: CGFloat
            let width: CGFloat
            let height: CGFloat
            let lines: Int
            let row: Int
        }

        var rowRightEdge: [CGFloat] = []
        var placed: [Placed] = []

        for e in sorted {
            let x = viewport.x(forDay: Double(e.startDay))
            let w = max(CGFloat(Double(e.durationDays) * viewport.pixelsPerDay), UI.minBarWidth)

            let notes = e.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            var lines = 0
            if expandedEventIDs.contains(e.id), !notes.isEmpty, w >= 220 {
                let charsPerLine = max(Int((w - 36) / 6.8), 12)
                lines = estimatedLineCount(notes, charactersPerLine: charsPerLine)
            }
            let h = UI.barHeight + (lines > 0 ? CGFloat(lines) * 19 + 14 : 0)

            let row: Int
            if let free = rowRightEdge.firstIndex(where: { $0 + 8 <= x }) {
                row = free
                rowRightEdge[free] = x + w
            } else {
                row = rowRightEdge.count
                rowRightEdge.append(x + w)
            }
            placed.append(Placed(event: e, x: x, width: w, height: h, lines: lines, row: row))
        }

        var rowHeights = [CGFloat](repeating: UI.barHeight, count: rowRightEdge.count)
        for p in placed {
            rowHeights[p.row] = max(rowHeights[p.row], p.height)
        }
        var rowY: [CGFloat] = []
        var y = UI.timelineBarsTop
        for h in rowHeights {
            rowY.append(y)
            y += h + UI.rowGap
        }

        let limit = CGFloat(viewport.width)
        let items = placed.compactMap { p -> LaidOutEvent? in
            guard p.x < limit + 60, p.x + p.width > -60 else { return nil }
            return LaidOutEvent(
                event: p.event, row: p.row, x: p.x, y: rowY[p.row],
                width: p.width, height: p.height, notesLines: p.lines
            )
        }
        return TimelineLayout(
            items: items,
            contentHeight: max(y, UI.timelineBarsTop + UI.barHeight)
        )
    }

    private static func estimatedLineCount(_ text: String, charactersPerLine: Int) -> Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { count, line in
            count + max(1, (line.count + charactersPerLine - 1) / charactersPerLine)
        }
    }
}
