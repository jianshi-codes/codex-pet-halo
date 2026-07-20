import AppKit

final class HaloPanel: NSPanel {
    var calibrationEnabled = false
    var calibrationDragHandler: ((NSPoint) -> Void)?

    private var dragStartMouseLocation: NSPoint?
    private var dragStartOrigin: NSPoint?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard calibrationEnabled else {
            super.mouseDown(with: event)
            return
        }
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartOrigin = frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard calibrationEnabled,
              let dragStartMouseLocation,
              let dragStartOrigin
        else {
            super.mouseDragged(with: event)
            return
        }
        let current = NSEvent.mouseLocation
        calibrationDragHandler?(
            NSPoint(
                x: dragStartOrigin.x + current.x - dragStartMouseLocation.x,
                y: dragStartOrigin.y + current.y - dragStartMouseLocation.y
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartOrigin = nil
        if !calibrationEnabled {
            super.mouseUp(with: event)
        }
    }
}
