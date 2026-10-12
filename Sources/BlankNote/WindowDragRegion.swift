import AppKit
import SwiftUI

/// A dedicated title hit area, separate from every note control and todo row.
struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> TitleDragView { TitleDragView() }
    func updateNSView(_ nsView: TitleDragView, context: Context) {}

    final class TitleDragView: NSView {
        private var initialMouse: NSPoint?
        private var initialOrigin: NSPoint?
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            initialMouse = window.convertPoint(toScreen: event.locationInWindow)
            initialOrigin = window.frame.origin
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let initialMouse, let initialOrigin else { return }
            let current = window.convertPoint(toScreen: event.locationInWindow)
            window.setFrameOrigin(NSPoint(
                x: initialOrigin.x + current.x - initialMouse.x,
                y: initialOrigin.y + current.y - initialMouse.y
            ))
        }

        override func mouseUp(with event: NSEvent) {
            initialMouse = nil
            initialOrigin = nil
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}
