import AppKit
import RegionCore

@MainActor
func checkToolbar() {
    guard let screen = NSScreen.main else { preconditionFailure("A desktop is required") }
    let session = PresentationSession()
    session.begin(size: CGSize(width: 600, height: 300))
    let toolbar = PresentationToolbar(session: session) { _ in }
    let region = CaptureRegion(displayID: 0, rect: CGRect(x: 100, y: 150, width: 600, height: 200))
    toolbar.show(region: region, on: screen, locked: false, hidden: false)
    let panel = NSApp.windows.first { $0.title == "Presentation Tools" && $0.isVisible }!
    panel.contentView!.layoutSubtreeIfNeeded()
    precondition(panel.level.rawValue > NSWindow.Level.floating.rawValue)
    precondition(panel.styleMask.contains(.nonactivatingPanel))
    precondition(panel.canBecomeKey && !panel.canBecomeMain)
    precondition(screen.visibleFrame.contains(panel.frame))
    precondition(panel.contentView!.bounds.size == panel.frame.size)
    func grip(in view: NSView) -> ToolbarGripView? {
        if let view = view as? ToolbarGripView { return view }
        return view.subviews.compactMap { grip(in: $0) }.first
    }
    guard let handle = grip(in: panel.contentView!) else { preconditionFailure("Six-dot grip must be present") }
    precondition(handle.toolTip == "Drag to move the presentation toolbar")
    let before = panel.frame
    func event(_ type: NSEvent.EventType, at point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                           windowNumber: panel.windowNumber, context: nil, eventNumber: 0,
                           clickCount: 1, pressure: 1)!
    }
    let start = handle.convert(CGPoint(x: handle.bounds.midX, y: handle.bounds.midY), to: nil)
    handle.mouseDown(with: event(.leftMouseDown, at: start))
    handle.mouseUp(with: event(.leftMouseUp, at: CGPoint(x: start.x + 40, y: start.y + 40)))
    precondition(panel.frame.origin != before.origin, "Grip must move the toolbar")
    let moved = panel.frame
    toolbar.show(region: region, on: screen, locked: false, hidden: false)
    precondition(panel.frame == moved, "State refresh must not undo manual placement")
    toolbar.show(region: region, on: screen, locked: true, hidden: true)
    precondition(NSApp.windows.filter { $0.title == "Presentation Tools" && $0.isVisible }.count == 1)
    precondition(panel.isVisible, "Resume View must remain reachable when concealed")
    let tall = CaptureRegion(displayID: 0, rect: CGRect(x: 100, y: 100, width: 100, height: 600))
    toolbar.show(region: tall, on: screen, locked: false, hidden: false)
    precondition(panel.frame == moved, "Region changes must retain manual placement")
    toolbar.hide()
    toolbar.show(region: tall, on: screen, locked: false, hidden: false)
    let tallPanel = NSApp.windows.first { $0.title == "Presentation Tools" && $0.isVisible }!
    tallPanel.contentView!.layoutSubtreeIfNeeded()
    precondition(tallPanel.frame.height > tallPanel.frame.width, "Tall regions should use a side toolbar")
    precondition(tallPanel.contentView!.bounds.size == tallPanel.frame.size)
    precondition(screen.visibleFrame.contains(tallPanel.frame))
    toolbar.hide()
    precondition(!panel.isVisible)
    toolbar.show(region: region, on: screen, locked: false, hidden: false)
    precondition(NSApp.windows.filter { $0.title == "Presentation Tools" && $0.isVisible }.count == 1)
    toolbar.hide()
    print("PASS: native toolbar placement, layout, identity, concealment access and teardown")
}
