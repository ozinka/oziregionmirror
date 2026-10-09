import AppKit
import RegionCore

@MainActor
final class RegionSelector {
    private var windows: [NSWindow] = []
    private var completion: ((CaptureRegion?) -> Void)?

    func select(completion: @escaping (CaptureRegion?) -> Void) {
        cancel()
        self.completion = completion
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { continue }
            let window = SelectionWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            let allowed = screen.regionCaptureBounds
            view.selectionBounds = CGRect(x: allowed.minX, y: screen.frame.height - allowed.maxY,
                                          width: allowed.width, height: allowed.height)
            view.finish = { [weak self] rect in
                let region = rect.map { CaptureRegion.fromSelection($0, displayID: id, screenSize: screen.frame.size) }
                self?.complete(region)
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windows.append(window)
        }
    }

    func cancel() { complete(nil) }

    private func complete(_ region: CaptureRegion?) {
        let callback = completion
        completion = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        callback?(region)
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

private final class SelectionView: NSView {
    var finish: ((CGRect?) -> Void)?
    var selectionBounds = CGRect.zero
    private var anchor: CGPoint?
    private var selection: CGRect = .zero
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(anchor.x, point.x), y: min(anchor.y, point.y),
                           width: abs(point.x - anchor.x), height: abs(point.y - anchor.y)).intersection(selectionBounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        if !selection.isNull && selection.width >= 32 && selection.height >= 32 { finish?(selection) }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { finish?(nil) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        NSColor.systemGreen.setStroke()
        if !selection.isNull {
            let path = NSBezierPath(rect: selection)
            path.lineWidth = 3
            path.stroke()
        }
        let text = "Drag to select a region • Esc to cancel"
        text.draw(at: CGPoint(x: 24, y: bounds.height - 60), withAttributes: [
            .foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 22, weight: .semibold)
        ])
    }
}
