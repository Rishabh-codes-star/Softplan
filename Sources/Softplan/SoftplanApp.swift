import SwiftUI
import AppKit

@main
struct SoftplanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var viewport = Viewport()

    var body: some Scene {
        WindowGroup("Softplan") {
            ContentView()
                .environmentObject(model)
                .environmentObject(viewport)
                .frame(minWidth: 900, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 760)
        .commands {
            // Creating a plan was mouse-only: drag the canvas or hit the +.
            CommandGroup(replacing: .newItem) {
                Button("New Plan") {
                    let center = Int(viewport.day(atX: CGFloat(viewport.width / 2)))
                    model.beginCreate(startDay: center, endDay: center + 30)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Timeline") {
                Button("Jump to Today") { viewport.centerOnToday() }
                    .keyboardShortcut("t", modifiers: .command)
                Divider()
                Button("Zoom In") { viewport.zoomAroundCenter(factor: 1.35) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { viewport.zoomAroundCenter(factor: 1 / 1.35) }
                    .keyboardShortcut("-", modifiers: .command)
            }
            CommandGroup(after: .windowArrangement) {
                Divider()
                Button("Refresh Plans") { model.reloadEvents() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var viewport: Viewport
    @StateObject private var timelineScroll = TimelineScrollState()

    var body: some View {
        PanZoomHost { dx, dy, x, command, shift in
            if command {
                // Mouse users: ⌘ + scroll to zoom at the cursor.
                viewport.zoom(factor: exp(Double(dy) * 0.01), anchorX: x)
            } else if shift || abs(dx) > abs(dy) {
                // Horizontal trackpad gestures, or Shift + wheel, pan through time.
                let d = abs(dx) > abs(dy) ? dx : dy
                viewport.pan(byPixels: d)
            } else {
                timelineScroll.scroll(byPixels: dy)
            }
        } onMagnify: { magnification, x in
            viewport.zoom(factor: 1 + Double(magnification), anchorX: x)
        } content: {
            // PanZoomHost hosts this in a fresh NSHostingView, which starts a new
            // SwiftUI hierarchy — the surrounding environment does not carry over.
            PlannerView()
                .environmentObject(model)
                .environmentObject(viewport)
                .environmentObject(timelineScroll)
        }
        .ignoresSafeArea()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
