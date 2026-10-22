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
                                to region: CaptureRegion, bounds: CGRect, aspectRatio: Double? = nil) -> CaptureRegion {
        let rect = region.rect
        if handle == .move {
            return CaptureRegion(displayID: region.displayID, rect: CGRect(
                x: clamp(rect.minX + delta.width, bounds.minX, bounds.maxX - rect.width),
                y: clamp(rect.minY + delta.height, bounds.minY, bounds.maxY - rect.height),
                width: rect.width, height: rect.height))
        }
        if let ratio = aspectRatio, ratio.isFinite, ratio > 0 {
            return resizing(handle, delta: delta, region: region, bounds: bounds, ratio: ratio)
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

    /// Exact dimensions are never silently reduced. The region is centered, then moved inside bounds.
    public static func sized(_ size: CGSize, around region: CaptureRegion, in bounds: CGRect) -> CaptureRegion? {
        guard size.width.isFinite, size.height.isFinite, size.width >= 32, size.height >= 32,
              size.width <= bounds.width, size.height <= bounds.height else { return nil }
        return CaptureRegion(displayID: region.displayID, rect: CGRect(
            x: clamp(region.rect.midX - size.width / 2, bounds.minX, bounds.maxX - size.width),
            y: clamp(region.rect.midY - size.height / 2, bounds.minY, bounds.maxY - size.height),
            width: size.width, height: size.height))
    }

    private static func resizing(_ handle: RegionHandle, delta: CGSize, region: CaptureRegion,
                                 bounds: CGRect, ratio: Double) -> CaptureRegion {
        let left = [.topLeft, .left, .bottomLeft].contains(handle)
        let right = [.topRight, .right, .bottomRight].contains(handle)
        let top = [.topLeft, .top, .topRight].contains(handle)
        let bottom = [.bottomLeft, .bottom, .bottomRight].contains(handle)
        let ax = left ? 1.0 : right ? 0.0 : 0.5
        let ay = top ? 1.0 : bottom ? 0.0 : 0.5
        let anchor = CGPoint(x: region.x + ax * region.width, y: region.y + ay * region.height)
        let dx = delta.width * (left ? -1 : 1)
        let dy = delta.height * (top ? -1 : 1)
        let change: Double
        if (left || right) && (top || bottom) {
            // Project corner movement onto the fixed-ratio diagonal.
            change = (dx + dy / ratio) / (1 + 1 / (ratio * ratio))
        } else {
            change = (left || right) ? dx : dy * ratio
        }
        var maximum = Double.infinity
        if ax > 0 { maximum = min(maximum, (anchor.x - bounds.minX) / ax) }
        if ax < 1 { maximum = min(maximum, (bounds.maxX - anchor.x) / (1 - ax)) }
        if ay > 0 { maximum = min(maximum, (anchor.y - bounds.minY) * ratio / ay) }
        if ay < 1 { maximum = min(maximum, (bounds.maxY - anchor.y) * ratio / (1 - ay)) }
        let minimum = max(32, 32 * ratio)
        guard maximum >= minimum else { return region }
        let width = clamp(region.width + change, minimum, maximum)
        let height = width / ratio
        return CaptureRegion(displayID: region.displayID, rect: CGRect(
            x: anchor.x - ax * width, y: anchor.y - ay * height, width: width, height: height))
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
