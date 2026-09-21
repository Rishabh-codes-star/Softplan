import SwiftUI

/// The timeline canvas, laid out per the Figma frames: app mark + "Softplan"
/// wordmark and a circled + top row, big sticky year, month labels over
/// full-height day gridlines, bars hanging below, red today line behind them.
/// Draw-to-create on empty canvas; the editor is a centered modal.
struct PlannerView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var viewport: Viewport
    @EnvironmentObject var timelineScroll: TimelineScrollState

    @State private var createRange: ClosedRange<Int>?
    @State private var createY: CGFloat = 0
    @State private var createPaletteId: String?
    @State private var expandedEventIDs: Set<UUID> = []

    var body: some View {
        GeometryReader { geo in
            let bodyHeight = max(geo.size.height - UI.gridLineTop, 0)
            let layout = EventLayout.layout(
                events: model.events,
                viewport: viewport,
                expandedEventIDs: expandedEventIDs
            )
            let contentHeight = max(bodyHeight, layout.contentHeight)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    fixedRuler(width: geo.size.width)
                    timelineBody(
                        size: CGSize(width: geo.size.width, height: bodyHeight),
                        layout: layout,
                        contentHeight: contentHeight
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .overlay(alignment: .topLeading) { header }
            .overlay(alignment: .topTrailing) { controls }
            .overlay { editorCard }
            .overlay { refreshOverlay }
            .onAppear {
                viewport.configure(width: geo.size.width)
                timelineScroll.configure(contentHeight: contentHeight, viewportHeight: bodyHeight)
            }
            .onChange(of: geo.size) { _, size in
                viewport.width = size.width
                timelineScroll.configure(
                    contentHeight: contentHeight,
                    viewportHeight: max(size.height - UI.gridLineTop, 0)
                )
            }
            .onChange(of: contentHeight) { _, height in
                timelineScroll.configure(contentHeight: height, viewportHeight: bodyHeight)
            }
        }
    }

    // MARK: Header chrome

    /// The stacked-bars app mark, loaded once.
    ///
    /// Deliberately not `Bundle.module`: that looks for the resource bundle
    /// beside the .app rather than inside Contents/Resources, then falls back to
    /// the absolute path of the machine that built it — and `fatalError`s when
    /// neither exists. Search the places the bundle actually lands instead, and
    /// treat a missing mark as a missing mark rather than a crash.
    private static let appLogo: Image? = {
        var searched: [Bundle] = [.main]
        let roots = [
            Bundle.main.resourceURL,                                  // packaged app
            Bundle.main.bundleURL,                                    // beside the .app
            Bundle.main.executableURL?.deletingLastPathComponent(),   // swift run
        ].compactMap { $0 }

        for root in roots {
            let url = root.appendingPathComponent("Softplan_Softplan.bundle")
            if let bundle = Bundle(url: url) { searched.append(bundle) }
        }

        for bundle in searched {
            if let url = bundle.url(forResource: "AppLogo", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return Image(nsImage: image)
            }
        }
        return nil
    }()

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: UI.wordmarkLogoGap) {
                if let logo = Self.appLogo {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(height: UI.wordmarkLogoHeight)
                        .accessibilityHidden(true)
                }
                Text("Softplan")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(UI.labelPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.top, UI.wordmarkTop)

            Text(String(leftEdgeYear))
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(UI.labelPrimary)
                .padding(.top, 24)
                .accessibilityLabel("Showing year \(leftEdgeYear)")
        }
        .padding(.leading, UI.contentLeading)
        .allowsHitTesting(false)
    }

    private var leftEdgeYear: Int {
        DayMath.calendar.component(.year, from: DayMath.date(from: Int(viewport.day(atX: 60))))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                viewport.centerOnToday()
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(UI.todayRed)
                        .frame(width: 7, height: 7)
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(UI.labelPrimary)
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(
                    Capsule()
                        .fill(Color.white)
                        .overlay(Capsule().strokeBorder(UI.controlBorder, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .help("Jump to today")
            .accessibilityLabel("Jump to today")

            Button {
                let center = Int(viewport.day(atX: CGFloat(viewport.width / 2)))
                model.beginCreate(startDay: center, endDay: center + 30)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(UI.labelPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().strokeBorder(UI.controlBorder, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .help("Add plan")
            .accessibilityLabel("Add plan")
        }
        .padding(.top, UI.wordmarkTop)
        .padding(.trailing, 24)
    }

    @ViewBuilder
    private var editorCard: some View {
        if let state = model.editorState {
            ZStack {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { model.editorState = nil }
                    .accessibilityHidden(true)

                EventFormView(state: state)
                    .environmentObject(model)
                    .id(state.id)
            }
        }
    }

    @ViewBuilder
    private var refreshOverlay: some View {
        if model.isRefreshing {
            Color.white
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeOut(duration: 0.12)))
                .accessibilityHidden(true)
        }
    }

    // MARK: Events

    private func eventsLayer(_ layout: TimelineLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.items) { item in
                EventBarView(item: item) {
                    toggleDescription(for: item.event.id)
                }
                    .frame(width: item.width, height: item.height)
                    .offset(x: item.x, y: item.y)
            }
        }
    }

    private func fixedRuler(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            UI.canvasBackground
            Canvas { context, size in
                GridRenderer.drawRuler(context: &context, size: size, viewport: viewport)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(width: width, height: UI.gridLineTop)
    }

    private func timelineBody(
        size: CGSize,
        layout: TimelineLayout,
        contentHeight: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            timelineContent(size: size, layout: layout, contentHeight: contentHeight)
                .offset(y: -timelineScroll.offset)

            if timelineScroll.maximumOffset > 0 {
                verticalScrollIndicator(viewportHeight: size.height, contentHeight: contentHeight)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(UI.canvasBackground)
        .clipped()
    }

    private func timelineContent(
        size: CGSize,
        layout: TimelineLayout,
        contentHeight: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            UI.canvasBackground
                .contentShape(Rectangle())
                .gesture(createGesture)
                .simultaneousGesture(doubleClickCreateGesture)

            Canvas { context, canvasSize in
                GridRenderer.drawTimeline(context: &context, size: canvasSize, viewport: viewport)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            eventsLayer(layout)

            if let range = createRange {
                createPreview(range)
            }

            if model.events.isEmpty && createRange == nil {
                emptyHint(in: size)
            }
        }
        .frame(width: size.width, height: contentHeight, alignment: .topLeading)
    }

    private func verticalScrollIndicator(viewportHeight: CGFloat, contentHeight: CGFloat) -> some View {
        let trackHeight = max(viewportHeight - 16, 0)
        let thumbHeight = min(trackHeight, max(32, trackHeight * viewportHeight / contentHeight))
        let travel = max(trackHeight - thumbHeight, 0)
        let progress = timelineScroll.maximumOffset > 0
            ? timelineScroll.offset / timelineScroll.maximumOffset
            : 0

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(UI.labelSecondary.opacity(0.45))
            .frame(width: 4, height: thumbHeight)
            .padding(.trailing, 6)
            .padding(.top, 8 + travel * progress)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)
    }

    private func toggleDescription(for eventID: UUID) {
        if expandedEventIDs.contains(eventID) {
            expandedEventIDs.remove(eventID)
        } else {
            expandedEventIDs.insert(eventID)
        }
    }

    // MARK: Draw-to-create

    private var doubleClickCreateGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { value in
                guard model.editorState == nil else { return }
                let day = Int(floor(viewport.day(atX: value.location.x)))
                model.beginCreate(startDay: day, endDay: day + 30)
            }
    }

    private var createGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { g in
                guard model.editorState == nil else { return }
                if createPaletteId == nil {
                    createPaletteId = Palette.leastUsedId(in: model.events)
                }
                let a = viewport.day(atX: g.startLocation.x)
                let b = viewport.day(atX: g.location.x)
                createRange = Int(floor(min(a, b)))...Int(floor(max(a, b)))
                createY = min(g.startLocation.y, g.location.y)
            }
            .onEnded { _ in
                if let r = createRange {
                    model.beginCreate(startDay: r.lowerBound, endDay: r.upperBound)
                }
                createRange = nil
                createPaletteId = nil
            }
    }

    @ViewBuilder
    private func createPreview(_ range: ClosedRange<Int>) -> some View {
        let pal = Palette.color(for: createPaletteId ?? Palette.colors[0].id)
        let x = viewport.x(forDay: Double(range.lowerBound))
        let w = max(viewport.x(forDay: Double(range.upperBound + 1)) - x, 10)
        let preview = PlanEvent(startDay: range.lowerBound, endDay: range.upperBound, paletteId: pal.id)

        ZStack {
            RoundedRectangle(cornerRadius: UI.barCorner, style: .continuous)
                .fill(pal.fill.opacity(0.65))
            RoundedRectangle(cornerRadius: UI.barCorner, style: .continuous)
                .strokeBorder(pal.accent, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            if w >= 150 {
                Text(preview.dateRangeLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(pal.accent)
                    .lineLimit(1)
            }
        }
        .frame(width: w, height: UI.barHeight)
        .offset(x: x, y: snappedRowY(for: createY))
        .allowsHitTesting(false)
    }

    private func snappedRowY(for y: CGFloat) -> CGFloat {
        let row = max(0, ((y - UI.timelineBarsTop) / (UI.barHeight + UI.rowGap)).rounded())
        return UI.timelineBarsTop + row * (UI.barHeight + UI.rowGap)
    }

    // MARK: Empty state

    private func emptyHint(in size: CGSize) -> some View {
        VStack(spacing: 6) {
            Text("Nothing planned yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(UI.labelPrimary)
            Text("Drag anywhere on the canvas to sketch a plan, or press +")
                .font(.system(size: 13))
                .foregroundColor(UI.labelSecondary)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
