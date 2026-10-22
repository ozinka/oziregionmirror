import AppKit
import RegionCore

/// Keeps one ordered output window across visible and parked presentation.
final class MirrorWindow: NSWindow {
    private(set) var isParked = false
    private var visibleFrame: NSRect?
    private var applyingOutputFrame = false

    override var canBecomeKey: Bool { !isParked && super.canBecomeKey }
    override var canBecomeMain: Bool { !isParked && super.canBecomeMain }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        isParked || applyingOutputFrame
            ? frameRect : super.constrainFrameRect(frameRect, to: screen)
    }

    @discardableResult
    func park() -> Bool {
        guard let destination = MirrorPlacement.parkedFrame(size: frame.size, displayFrames: NSScreen.screens.map(\.frame))
        else { return false }
        if !isParked { visibleFrame = frame }
        isParked = true
        if isMiniaturized { deminiaturize(nil) }
        if isKeyWindow { resignKey() }
        if isMainWindow { resignMain() }
        alphaValue = 1
        isOpaque = true
        hasShadow = false
        level = .normal
        if frame != destination { setFrame(destination, display: false) }
        if !isVisible { orderFront(nil) }
        return true
    }

    func restoreFromParking() {
        guard isParked else { return }
        // Move to a live display before the model converts the requested backing size.
        let screen = NSScreen.screens.first { screen in
            visibleFrame.map { screen.frame.intersects($0) } ?? false
        } ?? NSScreen.main
        var destination = visibleFrame ?? frame
        destination.size = frame.size
        if let visible = screen?.visibleFrame {
            destination.origin.x = max(visible.minX, min(destination.minX, visible.maxX - destination.width))
            destination.origin.y = visible.maxY - destination.height
        }
        isParked = false
        hasShadow = true
        setOutputFrame(destination)
        visibleFrame = nil
    }

    /// Explicit output sizing may exceed the desktop without silently reducing resolution.
    func setOutputFrame(_ frame: NSRect) {
        guard frame != self.frame else { return }
        applyingOutputFrame = true
        setFrame(frame, display: true)
        applyingOutputFrame = false
    }

    func setOutputContentSize(_ size: NSSize) {
        guard contentView?.bounds.size != size else { return }
        applyingOutputFrame = true
        setContentSize(size)
        applyingOutputFrame = false
    }

}
