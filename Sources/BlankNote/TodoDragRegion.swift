import AppKit
import SwiftUI

/// Start a native item drag instead of allowing a hosting view to promote
/// the mouse gesture into a window move.
struct TodoDragRegion: NSViewRepresentable {
    let payload: String
    let label: String
    var onDoubleClick: (() -> Void)?

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {
        view.payload = payload
        view.label = label
        view.onDoubleClick = onDoubleClick
    }

    final class DragView: NSView, NSDraggingSource {
        var payload = ""
        var label = ""
        var onDoubleClick: (() -> Void)?
        private var canStartDrag = false
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            canStartDrag = event.clickCount == 1
            if event.clickCount == 2 { onDoubleClick?() }
        }

        override func mouseUp(with event: NSEvent) { canStartDrag = false }

        override func mouseDragged(with event: NSEvent) {
            // A mouseDragged event already distinguishes this from a click.
            // Start immediately so fast drags still enter the destination
            // before mouse-up, including when the first event has zero delta.
            guard canStartDrag else { return }
            canStartDrag = false
            let pasteboard = NSPasteboardItem()
            pasteboard.setString(payload, forType: .string)
            let item = NSDraggingItem(pasteboardWriter: pasteboard)
            let size = NSSize(width: 260, height: 46)
            let preview = NSImage(size: size, flipped: false) { rect in
                NSColor.windowBackgroundColor.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
                (self.label as NSString).draw(in: rect.insetBy(dx: 10, dy: 8), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor
                ])
                return true
            }
            item.setDraggingFrame(NSRect(origin: convert(event.locationInWindow, from: nil), size: size), contents: preview)
            beginDraggingSession(with: [item], event: event, source: self)
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? [.move, .copy] : []
        }

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}
