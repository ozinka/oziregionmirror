import AppKit
import RegionCore

@MainActor
final class RegionOutline {
    var didEdit: ((CaptureRegion) -> Void)?
    private var region: CaptureRegion?
    private var screen: NSScreen?
    private var border: NSWindow?
    private var handles: [(RegionHandle, NSWindow)] = []
    private var editing = true

    func show(_ region: CaptureRegion, editing: Bool) {
        hide()
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == region.displayID
        }) else { return }
        self.screen = screen
        self.region = region
        self.editing = editing
        let border = makeWindow(interactive: false)
        border.contentView = OutlineBorderView()
        self.border = border
        for handle in RegionHandle.allCases {
            let window = makeWindow(interactive: true)
            let view = RegionHandleView(handle: handle)
            view.begin = { [weak self] in self?.region }
            view.change = { [weak self] initial, delta in
                guard let self, let screen = self.screen else { return }
                let updated = RegionEditing.applying(handle, delta: delta, to: initial, bounds: screen.regionCaptureBounds)
                self.setRegion(updated)
                self.didEdit?(updated)
            }
            view.cancel = { [weak self] initial in
                self?.setRegion(initial)
                self?.didEdit?(initial)
            }
            window.contentView = view
            handles.append((handle, window))
        }
        setRegion(region)
    }

    func setEditing(_ editing: Bool) {
        self.editing = editing
        if let region { setRegion(region) }
    }

    func hide() {
        border?.orderOut(nil)
        border = nil
        handles.forEach { $0.1.orderOut(nil) }
        handles.removeAll()
        region = nil
        screen = nil
    }

    private func setRegion(_ region: CaptureRegion) {
        self.region = region
        guard let screen else { return }
        let rect = CGRect(x: screen.frame.minX + region.x,
            y: screen.frame.maxY - region.y - region.height,
            width: region.width, height: region.height)
        let visible = screen.visibleFrame
        border?.setFrame(rect.insetBy(dx: -2, dy: -2), display: true)
        border?.orderFrontRegardless()
        for (handle, window) in handles {
            var point: CGPoint
            switch handle {
            case .topLeft: point = CGPoint(x: rect.minX, y: rect.maxY)
            case .top: point = CGPoint(x: rect.midX, y: rect.maxY)
            case .topRight: point = CGPoint(x: rect.maxX, y: rect.maxY)
            case .right: point = CGPoint(x: rect.maxX, y: rect.midY)
            case .bottomRight: point = CGPoint(x: rect.maxX, y: rect.minY)
            case .bottom: point = CGPoint(x: rect.midX, y: rect.minY)
            case .bottomLeft: point = CGPoint(x: rect.minX, y: rect.minY)
            case .left: point = CGPoint(x: rect.minX, y: rect.midY)
            case .move:
                let y = rect.maxY + 28 <= visible.maxY ? rect.maxY + 16
                    : (rect.minY - 28 >= visible.minY ? rect.minY - 16 : rect.maxY - 22)
                point = CGPoint(x: rect.midX, y: y)
            }
            let size = handle == .move ? CGSize(width: min(240, max(100, rect.width - 28)), height: 24)
                : CGSize(width: 14, height: 14)
            point.x = min(max(point.x - size.width / 2, visible.minX), visible.maxX - size.width)
            point.y = min(max(point.y - size.height / 2, visible.minY), visible.maxY - size.height)
            window.setFrame(CGRect(origin: point, size: size), display: true)
            if editing { window.orderFrontRegardless() } else { window.orderOut(nil) }
        }
    }

    private func makeWindow(interactive: Bool) -> NSWindow {
        let window = RegionHandleWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = !interactive
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return window
    }
}

private final class RegionHandleWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    // The shared geometry already constrains these overlays; independent AppKit shifts misalign them.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

private final class OutlineBorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemGreen.setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        path.lineWidth = 2
        path.setLineDash([7, 5], count: 2, phase: 0)
        path.stroke()
    }
}

private final class RegionHandleView: NSView {
    let handle: RegionHandle
    var begin: (() -> CaptureRegion?)?
    var change: ((CaptureRegion, CGSize) -> Void)?
    var cancel: ((CaptureRegion) -> Void)?
    private var initial: CaptureRegion?
    private var anchor: CGPoint = .zero

    init(handle: RegionHandle) { self.handle = handle; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        let cursor: NSCursor
        switch handle {
        case .move: cursor = .openHand
        case .top, .bottom: cursor = .resizeUpDown
        case .left, .right: cursor = .resizeLeftRight
        default: cursor = .crosshair
        }
        addCursorRect(bounds, cursor: cursor)
    }

    override func mouseDown(with event: NSEvent) {
        initial = begin?()
        anchor = NSEvent.mouseLocation
        window?.makeKey()
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let initial else { return }
        let point = NSEvent.mouseLocation
        change?(initial, CGSize(width: point.x - anchor.x, height: anchor.y - point.y))
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        initial = nil
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, let initial {
            self.initial = nil
            cancel?(initial)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemGreen.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3).fill()
        if handle == .move {
            let text = "Drag to move • Esc to cancel"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.black
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: max(3, (bounds.width - size.width) / 2), y: (bounds.height - size.height) / 2),
                      withAttributes: attributes)
        } else {
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
            path.lineWidth = 1
            path.stroke()
        }
    }
}
