import AppKit
import RegionCore

extension NSScreen {
    var regionCaptureBounds: CGRect {
        RegionEditing.captureBounds(screenFrame: frame, visibleFrame: visibleFrame)
    }
}
