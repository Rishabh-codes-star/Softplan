import SwiftUI
import AppKit

/// Hosts SwiftUI content inside an NSView that captures trackpad pinch
/// (`magnify`) and two-finger scroll (`scrollWheel`) — events SwiftUI cannot
/// observe directly. Unhandled events bubble up from the hosting view's
/// responder chain into this container.
struct PanZoomHost<Content: View>: NSViewRepresentable {
    var onScroll: (_ dx: CGFloat, _ dy: CGFloat, _ locationX: CGFloat, _ command: Bool, _ shift: Bool) -> Void
    var onMagnify: (_ magnification: CGFloat, _ locationX: CGFloat) -> Void
    @ViewBuilder var content: () -> Content

    func makeNSView(context: Context) -> PanZoomNSView<Content> {
        let view = PanZoomNSView<Content>()
        let hosting = NSHostingView(rootView: content())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        view.hosting = hosting
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        return view
    }

    func updateNSView(_ nsView: PanZoomNSView<Content>, context: Context) {
        nsView.hosting?.rootView = content()
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
    }
}

final class PanZoomNSView<Content: View>: NSView {
    var hosting: NSHostingView<Content>?
    var onScroll: ((CGFloat, CGFloat, CGFloat, Bool, Bool) -> Void)?
    var onMagnify: ((CGFloat, CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onScroll?(
            event.scrollingDeltaX,
            event.scrollingDeltaY,
            p.x,
            event.modifierFlags.contains(.command),
            event.modifierFlags.contains(.shift)
        )
    }

    override func magnify(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onMagnify?(event.magnification, p.x)
    }
}
