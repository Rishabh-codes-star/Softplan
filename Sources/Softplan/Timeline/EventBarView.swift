import SwiftUI
import AppKit

/// One plan bar: tinted fill, dark ink title, saturated accent dates and
/// description. Drag the body to move, drag the soft white edge pills to
/// resize; click a wide plan to expand its description.
struct EventBarView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var viewport: Viewport
    let item: LaidOutEvent
    let onToggleDescription: () -> Void

    @State private var dragBase: PlanEvent?
    @State private var movePreviewOffset: CGFloat = 0
    @State private var moveSettleWorkItem: DispatchWorkItem?
    @State private var hovering = false

    private static let moveSettleDuration: TimeInterval = 0.14

    private var pal: PaletteColor { Palette.color(for: item.event.paletteId) }
    private var expanded: Bool { item.notesLines > 0 }
    private var hasExpandableDescription: Bool {
        !item.event.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && item.width >= 220
    }
    private var hasResizeHandles: Bool { item.width >= 72 }
    private var contentInset: CGFloat { hasResizeHandles ? 36 : 18 }
    private var compactContentInset: CGFloat { hasResizeHandles ? 30 : 10 }
    private var handleHeight: CGFloat {
        min(max(item.height - 36, 32), 46)
    }

    var body: some View {
        ZStack(alignment: expanded ? .topLeading : .leading) {
            RoundedRectangle(cornerRadius: UI.barCorner, style: .continuous)
                .fill(pal.fill)

            textContent
        }
        .overlay(alignment: .leading) { handle(edge: .leading) }
        .overlay(alignment: .trailing) { handle(edge: .trailing) }
        .contentShape(RoundedRectangle(cornerRadius: UI.barCorner, style: .continuous))
        .offset(x: movePreviewOffset)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Edit…") { model.beginEdit(item.event) }
            Divider()
            Button("Delete", role: .destructive) { model.delete(item.event.id) }
        }
        .onTapGesture {
            if hasExpandableDescription {
                onToggleDescription()
            } else {
                model.beginEdit(item.event)
            }
        }
        .gesture(moveGesture)
        // The bar is one thing to a screen reader, not a pile of shapes: its
        // pieces are merged into a single element carrying the plan's details,
        // with the edit and delete paths exposed as actions since dragging and
        // the context menu are mouse-only.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        // Merging the children hides the description text, and it is only drawn
        // on wide, expanded bars anyway — carry it as the value so a screen
        // reader gets it in every state.
        .accessibilityValue(spokenDescription)
        .accessibilityHint(hasExpandableDescription ? "Shows the description" : "Opens the editor")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Edit") { model.beginEdit(item.event) }
        .accessibilityAction(named: "Delete") { model.delete(item.event.id) }
    }

    private var spokenDescription: String {
        item.event.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Website launch, 14 September to 03 October, 20 days".
    private var spokenSummary: String {
        let title = item.event.title.isEmpty ? "Untitled" : item.event.title
        let days = item.event.durationDays
        return "\(title), \(item.event.spokenDateRange), \(days) day\(days == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var textContent: some View {
        if item.width >= 120 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.event.title.isEmpty ? "Untitled" : item.event.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(pal.ink)
                        .lineLimit(1)
                    if expanded {
                        Spacer(minLength: 0)
                        editButton
                    }
                }
                Text(item.event.dateRangeLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(pal.accent)
                    .lineLimit(1)
                if expanded {
                    // Trimmed, like the text EventLayout measured for notesLines;
                    // a leading blank line would otherwise eat the last real one.
                    Text(spokenDescription)
                        .font(.system(size: 13.5))
                        .foregroundColor(pal.accent)
                        .lineSpacing(2)
                        .lineLimit(item.notesLines)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, contentInset)
            .padding(.vertical, expanded ? 16 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        } else if item.width >= 56 {
            Text(item.event.title.isEmpty ? "Untitled" : item.event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(pal.ink)
                .lineLimit(1)
                .padding(.horizontal, compactContentInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
        }
    }

    private var editButton: some View {
        Button {
            model.beginEdit(item.event)
        } label: {
            Label("Edit", systemImage: "pencil")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(pal.ink)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.78))
                )
        }
        .buttonStyle(.plain)
        .help("Edit plan")
    }

    // MARK: Move

    /// The model's copy of this plan rather than `item.event`: a gesture
    /// callback can still hold the `item` captured before the last move landed.
    private var currentEvent: PlanEvent {
        model.events.first { $0.id == item.event.id } ?? item.event
    }

    /// Lands a move whose settle animation is still running. A new drag that
    /// starts inside that window used to cancel it, silently dropping the move
    /// that had just finished.
    private func finishPendingMove() {
        guard let pending = moveSettleWorkItem else { return }
        pending.perform()  // applies and commits the move, clears drag state
        pending.cancel()   // and stops the scheduled copy from running again
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { g in
                finishPendingMove()
                if dragBase == nil { dragBase = currentEvent }
                movePreviewOffset = g.translation.width
            }
            .onEnded { value in
                guard let base = dragBase else { return }
                let dayDelta = Int((Double(value.translation.width) / viewport.pixelsPerDay).rounded())
                let snappedOffset = CGFloat(dayDelta) * CGFloat(viewport.pixelsPerDay)

                // Keep the preview alive until it reaches the exact persisted position.
                withAnimation(.easeOut(duration: Self.moveSettleDuration)) {
                    movePreviewOffset = snappedOffset
                }

                let workItem = DispatchWorkItem {
                    var movedEvent = base
                    movedEvent.startDay = base.startDay + dayDelta
                    movedEvent.endDay = base.endDay + dayDelta

                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.movePreviewOffset = 0
                        if dayDelta != 0 {
                            self.model.updateLive(movedEvent)
                        }
                    }
                    if dayDelta != 0 {
                        self.model.commit(movedEvent.id)
                    }
                    self.dragBase = nil
                    self.moveSettleWorkItem = nil
                }
                moveSettleWorkItem = workItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Self.moveSettleDuration,
                    execute: workItem
                )
            }
    }

    // MARK: Resize handles — soft white pills inset at the edges (mock style)

    private enum Edge { case leading, trailing }

    @ViewBuilder
    private func handle(edge: Edge) -> some View {
        if hasResizeHandles {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(hovering ? 0.6 : 0))
                .frame(width: 8, height: handleHeight)
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
                }
                .gesture(resizeGesture(edge: edge))
                .accessibilityHidden(true)
        }
    }

    private func resizeGesture(edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { g in
                // Same race as a double move: a resize begun mid-settle would
                // otherwise start from the pre-move dates and be overwritten
                // when the settle fires.
                finishPendingMove()
                if dragBase == nil { dragBase = currentEvent }
                guard let base = dragBase else { return }
                let delta = Int((Double(g.translation.width) / viewport.pixelsPerDay).rounded())
                var e = base
                switch edge {
                case .leading:
                    e.startDay = min(base.startDay + delta, base.endDay)
                case .trailing:
                    e.endDay = max(base.endDay + delta, base.startDay)
                }
                model.updateLive(e)
            }
            .onEnded { _ in
                model.commit(item.event.id)
                dragBase = nil
                NSCursor.arrow.set()
            }
    }
}
