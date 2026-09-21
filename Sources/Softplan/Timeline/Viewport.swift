import AppKit
import Combine
import Foundation
import QuartzCore

/// The window onto time. Two numbers define it:
/// `pixelsPerDay` (zoom) and `leftDay` (the fractional day index at x = 0).
final class Viewport: ObservableObject {
    @Published var pixelsPerDay: Double = 1.4 {
        didSet { schedulePersist() }
    }
    @Published var leftDay: Double = 0 {
        didSet { schedulePersist() }
    }

    var width: Double = 1200 {
        didSet {
            // A zero-width layout pass — a window opening, or minimising — would
            // collapse pixelsPerDay to zero and turn every day↔pixel conversion
            // into an infinity, which Int() then traps on. Assigning here does
            // not re-enter didSet.
            if !(width >= 1) { width = 1 }
            clamp()
        }
    }

    /// Fully zoomed out: ~12 years across the window. Fully in: one week.
    var minPPD: Double { width / (365.25 * 12) }
    var maxPPD: Double { width / 7 }

    private enum Key {
        static let pixelsPerDay = "viewport.ppd"
        static let leftDay = "viewport.leftDay"
    }

    private var restored = false
    private var configured = false
    private var animationTimer: Timer?
    private var persistWorkItem: DispatchWorkItem?
    private var terminationObserver: NSObjectProtocol?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let ppd = defaults.double(forKey: Key.pixelsPerDay)
        if ppd > 0 {
            pixelsPerDay = ppd
            leftDay = defaults.double(forKey: Key.leftDay)
            restored = true
        }
        // A pending coalesced write would be lost on quit otherwise.
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persist()
        }
    }

    deinit {
        animationTimer?.invalidate()
        persistWorkItem?.cancel()
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }

    /// Called once the timeline knows its real width.
    func configure(width: Double) {
        self.width = width
        if !configured && !restored {
            // First launch: ~2 years visible, today centered. Uses the stored
            // width, which the setter has already floored.
            pixelsPerDay = self.width / 730
            leftDay = Double(DayMath.today()) - (self.width / 2) / pixelsPerDay
        }
        configured = true
        clamp()
    }

    // MARK: Mapping

    func x(forDay day: Double) -> CGFloat {
        CGFloat((day - leftDay) * pixelsPerDay)
    }

    func day(atX x: CGFloat) -> Double {
        guard pixelsPerDay > 0 else { return leftDay }
        return leftDay + Double(x) / pixelsPerDay
    }

    // MARK: Interaction

    func pan(byPixels dx: CGFloat) {
        stopAnimation()
        leftDay -= Double(dx) / pixelsPerDay
        clamp()
    }

    func zoom(factor: Double, anchorX: CGFloat) {
        stopAnimation()
        let f = max(factor, 0.2)
        let anchorDay = day(atX: anchorX)
        pixelsPerDay = min(max(pixelsPerDay * f, minPPD), maxPPD)
        leftDay = anchorDay - Double(anchorX) / pixelsPerDay
        clamp()
    }

    func zoomAroundCenter(factor: Double) {
        zoom(factor: factor, anchorX: CGFloat(width / 2))
    }

    func centerOnToday() {
        center(onDay: Double(DayMath.today()))
    }

    func center(onDay day: Double) {
        animateLeftDay(to: day + 0.5 - (width / 2) / pixelsPerDay)
    }

    // MARK: Internals

    private func clamp() {
        let today = Double(DayMath.today())
        let horizon = 365.25 * 80
        let visible = width / pixelsPerDay
        leftDay = min(max(leftDay, today - horizon), today + horizon - visible)
    }

    private func animateLeftDay(to target: Double) {
        stopAnimation()

        // Someone who has asked the system for less motion gets the jump cut.
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            leftDay = target
            clamp()
            return
        }

        let start = leftDay
        let t0 = CACurrentMediaTime()
        let duration = 0.45
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = min((CACurrentMediaTime() - t0) / duration, 1)
            let eased = 1 - pow(1 - t, 3)
            self.leftDay = start + (target - start) * eased
            if t >= 1 {
                timer.invalidate()
                self.clamp()
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    /// Panning moves `leftDay` every frame; one UserDefaults write per frame is
    /// pure churn, so writes coalesce to the pause after a gesture.
    private func schedulePersist() {
        persistWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func persist() {
        persistWorkItem?.cancel()
        persistWorkItem = nil
        defaults.set(pixelsPerDay, forKey: Key.pixelsPerDay)
        defaults.set(leftDay, forKey: Key.leftDay)
    }
}
