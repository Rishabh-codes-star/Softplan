import SwiftUI

final class TimelineScrollState: ObservableObject {
    @Published private(set) var offset: CGFloat = 0
    @Published private(set) var maximumOffset: CGFloat = 0

    func configure(contentHeight: CGFloat, viewportHeight: CGFloat) {
        let maximum = max(contentHeight - viewportHeight, 0)
        if maximumOffset != maximum {
            maximumOffset = maximum
        }
        let clampedOffset = min(max(offset, 0), maximum)
        if offset != clampedOffset {
            offset = clampedOffset
        }
    }

    func scroll(byPixels delta: CGFloat) {
        guard maximumOffset > 0 else { return }
        offset = min(max(offset - delta, 0), maximumOffset)
    }
}