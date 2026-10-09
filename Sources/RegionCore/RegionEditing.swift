import Foundation
import CoreGraphics

public enum RegionHandle: CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move
}

public enum RegionEditing {
    /// Deltas use display-local top-left points; each drag is relative to its initial rectangle.
    public static func applying(_ handle: RegionHandle, delta: CGSize,
                                to region: CaptureRegion, screenSize: CGSize) -> CaptureRegion {
        applying(handle, delta: delta, to: region, bounds: CGRect(origin: .zero, size: screenSize))
    }

    /// Usable bounds exclude the menu bar/Dock and leave room for the editing handles.
    public static func captureBounds(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let usable = visibleFrame.intersection(screenFrame).insetBy(dx: 7, dy: 7)
        return CGRect(x: usable.minX - screenFrame.minX, y: screenFrame.maxY - usable.maxY,
                      width: usable.width, height: usable.height)
    }

    public static func fitting(_ region: CaptureRegion, in bounds: CGRect) -> CaptureRegion? {
        guard bounds.width >= 32, bounds.height >= 32, region.width >= 32, region.height >= 32 else { return nil }
        let width = min(region.width, bounds.width)
        let height = min(region.height, bounds.height)
        return CaptureRegion(displayID: region.displayID, rect: CGRect(
            x: clamp(region.x, bounds.minX, bounds.maxX - width),
            y: clamp(region.y, bounds.minY, bounds.maxY - height), width: width, height: height))
    }

    public static func applying(_ handle: RegionHandle, delta: CGSize,
                                to region: CaptureRegion, bounds: CGRect) -> CaptureRegion {
        let rect = region.rect
        if handle == .move {
            return CaptureRegion(displayID: region.displayID, rect: CGRect(
                x: clamp(rect.minX + delta.width, bounds.minX, bounds.maxX - rect.width),
                y: clamp(rect.minY + delta.height, bounds.minY, bounds.maxY - rect.height),
                width: rect.width, height: rect.height))
        }
        var left = rect.minX
        var right = rect.maxX
        var top = rect.minY
        var bottom = rect.maxY
        if [.topLeft, .left, .bottomLeft].contains(handle) {
            left = clamp(left + delta.width, bounds.minX, right - 32)
        }
        if [.topRight, .right, .bottomRight].contains(handle) {
            right = clamp(right + delta.width, left + 32, bounds.maxX)
        }
        if [.topLeft, .top, .topRight].contains(handle) {
            top = clamp(top + delta.height, bounds.minY, bottom - 32)
        }
        if [.bottomLeft, .bottom, .bottomRight].contains(handle) {
            bottom = clamp(bottom + delta.height, top + 32, bounds.maxY)
        }
        return CaptureRegion(displayID: region.displayID,
            rect: CGRect(x: left, y: top, width: right - left, height: bottom - top))
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

/// Main-actor callers serialize work and replace pending drag positions with the newest one.
public struct LatestRegionQueue {
    private var pending: CaptureRegion?
    public init() {}
    public mutating func submit(_ region: CaptureRegion) { pending = region }
    public mutating func take() -> CaptureRegion? {
        defer { pending = nil }
        return pending
    }
    public mutating func clear() { pending = nil }
}
