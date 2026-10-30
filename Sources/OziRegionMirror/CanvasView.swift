import AppKit
import RegionCore

@MainActor
final class CanvasView: NSView {
    let session: PresentationSession
    let interactive: Bool
    var finishDrawing: (() -> Void)?
    private var start: CGPoint?
    private var original: CanvasElement?
    private var resizingImage = false
    private var points: [CGPoint] = []
    private var gestureRevision: Int?

    init(session: PresentationSession, interactive: Bool) {
        self.session = session; self.interactive = interactive
        super.init(frame: .zero)
        wantsLayer = true
        if interactive { toolTip = "Draw inside the region. Escape cancels a gesture or finishes drawing. Drag an image to move it; drag its blue corner to resize." }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { interactive }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateBackingScale() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); updateBackingScale() }
    override func setFrameSize(_ newSize: NSSize) { super.setFrameSize(newSize); needsDisplay = true }

    private func updateBackingScale() {
        layer?.contentsScale = window?.backingScaleFactor ?? 1
        needsDisplay = true
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { interactive }
    override func hitTest(_ point: NSPoint) -> NSView? { interactive ? super.hitTest(point) : nil }
    override func resetCursorRects() { if interactive { addCursorRect(bounds, cursor: session.tool == .select ? .arrow : .crosshair) } }

    override func draw(_ dirtyRect: NSRect) {
        // Clear old strokes when undoing, moving images or returning to a live source.
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        CanvasRenderer.draw(session, in: bounds, selection: interactive && session.drawing)
    }

    private func normalized(_ event: NSEvent) -> CGPoint {
        CanvasGeometry.normalized(convert(event.locationInWindow, from: nil),
                                  in: CanvasGeometry.contentRect(size: session.canvasSize, in: bounds))
    }

    override func mouseDown(with event: NSEvent) {
        guard interactive, session.enabled, !session.isConcealed, session.drawing else { return }
        window?.makeKey(); window?.makeFirstResponder(self)
        let content = CanvasGeometry.contentRect(size: session.canvasSize, in: bounds)
        guard content.contains(convert(event.locationInWindow, from: nil)) else { return }
        session.cancelDraft()
        let p = normalized(event)
        start = p; original = nil; resizingImage = false; points = [p]; gestureRevision = session.gestureEpoch
        if session.tool == .select {
            // Check the selected resize corner before searching image bodies underneath it.
            let images = session.history.elements.filter { $0.kind == .image }
            if let item = images.first(where: { $0.id == session.selectedID }),
               abs((p.x - item.rect.maxX) * content.width) <= 12,
               abs((p.y - item.rect.maxY) * content.height) <= 12 {
                original = item; resizingImage = true
            } else {
                original = images.reversed().first { $0.rect.contains(p) }
                session.selectedID = original?.id
            }
        } else if session.tool != .text {
            session.selectedID = nil
            updateGesture(to: p)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard validGesture else { return }
        updateGesture(to: normalized(event))
    }

    private var validGesture: Bool {
        start != nil && session.enabled && !session.isConcealed && session.drawing && gestureRevision == session.gestureEpoch
    }

    private func updateGesture(to p: CGPoint) {
        guard let start else { return }
        if session.tool == .select {
            guard var item = original else { return }
            item.rect = resizingImage ? CanvasGeometry.resized(item.rect, to: p)
                : CanvasGeometry.moved(item.rect, by: CGSize(width: p.x - start.x, height: p.y - start.y))
            session.updateDraft(item)
            return
        }
        let kind: CanvasElement.Kind
        switch session.tool {
        case .pen: kind = .pen
        case .arrow: kind = .arrow
        case .rectangle: kind = .rectangle
        case .ellipse: kind = .ellipse
        default: return
        }
        if kind == .pen {
            if let last = points.last, hypot(p.x - last.x, p.y - last.y) > 0.001, points.count < 2048 { points.append(p) }
        } else { points = [start, p] }
        var item = CanvasElement(kind: kind, points: points, rect: CanvasGeometry.rectangle(from: start, to: p),
                                 color: session.color, width: session.lineWidth / max(32, session.canvasSize.width))
        if let draft = session.draft { item.id = draft.id }
        session.updateDraft(item)
    }

    override func mouseUp(with event: NSEvent) {
        guard validGesture else { cancelGesture(); return }
        if session.tool == .text, let start {
            let revision = session.gestureEpoch
            let alert = NSAlert()
            alert.messageText = "Add Text"
            alert.addButton(withTitle: "Add"); alert.addButton(withTitle: "Cancel")
            let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 300, height: 24))
            field.placeholderString = "Annotation text"
            alert.accessoryView = field; alert.window.initialFirstResponder = field
            if alert.runModal() == .alertFirstButtonReturn, session.enabled, session.drawing,
               session.gestureEpoch == revision, !field.stringValue.isEmpty {
                session.updateDraft(CanvasElement(kind: .text, points: [start], color: session.color,
                    width: session.lineWidth / max(32, session.canvasSize.width), text: String(field.stringValue.prefix(500))))
                session.commitDraft()
            }
        } else {
            updateGesture(to: normalized(event)); session.commitDraft()
        }
        start = nil; original = nil; points.removeAll()
    }

    func cancelGesture() {
        start = nil; original = nil; points.removeAll(); gestureRevision = nil
        session.cancelDraft()
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "z" {
            cancelGesture()
            if event.modifierFlags.contains(.shift) { session.redo() } else { session.undo() }
        } else if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "v" {
            cancelGesture(); session.pasteImage()
        } else if event.keyCode == 53 {
            if start != nil { cancelGesture() } else { finishDrawing?() }
        } else if event.keyCode == 51 || event.keyCode == 117 { session.deleteSelected() }
        else { super.keyDown(with: event) }
    }
}

@MainActor
final class AnnotationEditor {
    private var window: AnnotationInputWindow?
    private var view: CanvasView?
    private let session: PresentationSession
    var finishDrawing: (() -> Void)?

    init(session: PresentationSession) { self.session = session }

    func show(region: CaptureRegion, on screen: NSScreen) {
        if window == nil {
            let window = AnnotationInputWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.backgroundColor = .clear; window.isOpaque = false; window.hasShadow = false
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = CanvasView(session: session, interactive: true)
            view.finishDrawing = { [weak self] in self?.finishDrawing?() }
            window.contentView = view
            self.window = window; self.view = view
        }
        let frame = CGRect(x: screen.frame.minX + region.x, y: screen.frame.maxY - region.y - region.height,
                           width: region.width, height: region.height)
        if window?.frame != frame { window?.setFrame(frame, display: true) }
        // Fully transparent window pixels pass clicks through on macOS. A faint
        // background makes the live editor hittable; process exclusion keeps it out of capture.
        window?.backgroundColor = session.drawing ? NSColor.black.withAlphaComponent(0.01) : .clear
        window?.ignoresMouseEvents = !session.drawing
        if !session.drawing, window?.isKeyWindow == true { window?.resignKey() }
        if window?.isVisible == false { window?.orderFrontRegardless() }
        view?.needsDisplay = true
    }

    func redraw() {
        guard let view else { return }
        view.needsDisplay = true; view.window?.invalidateCursorRects(for: view)
    }
    func hide() {
        window?.orderOut(nil)
        let previous = view
        window = nil; view = nil
        previous?.cancelGesture()
    }
}

private final class AnnotationInputWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
