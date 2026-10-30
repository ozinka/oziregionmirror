import Foundation

public struct RegionToolbarPlacement: Equatable {
    public let frame: CGRect
    public let vertical: Bool

    // All input and output rectangles use global AppKit coordinates.
    public static func adjacent(to region: CGRect, within visible: CGRect) -> RegionToolbarPlacement {
        let gap: CGFloat = 32
        let horizontal = CGSize(width: min(484, visible.width), height: min(44, visible.height))
        let vertical = CGSize(width: min(44, visible.width), height: min(484, visible.height))
        let below = CGRect(x: region.midX - horizontal.width / 2, y: region.minY - gap - horizontal.height,
                           width: horizontal.width, height: horizontal.height)
        let above = CGRect(x: below.minX, y: region.maxY + gap, width: horizontal.width, height: horizontal.height)
        let right = CGRect(x: region.maxX + gap, y: region.midY - vertical.height / 2,
                           width: vertical.width, height: vertical.height)
        let left = CGRect(x: region.minX - gap - vertical.width, y: right.minY,
                          width: vertical.width, height: vertical.height)
        let candidates: [(CGRect, Bool)] = region.height > region.width
            ? [(right, true), (left, true), (below, false), (above, false)]
            : [(below, false), (right, true), (left, true), (above, false)]
        for (frame, upright) in candidates {
            let fits = upright ? frame.minX >= visible.minX && frame.maxX <= visible.maxX
                : frame.minY >= visible.minY && frame.maxY <= visible.maxY
            if fits { return RegionToolbarPlacement(frame: clamped(frame, to: visible), vertical: upright) }
        }
        // A crop can occupy the whole desktop; keep the tools reachable in that case.
        return RegionToolbarPlacement(frame: clamped(below, to: visible), vertical: false)
    }

    private static func clamped(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        CGRect(x: min(max(frame.minX, bounds.minX), bounds.maxX - frame.width),
               y: min(max(frame.minY, bounds.minY), bounds.maxY - frame.height),
               width: frame.width, height: frame.height)
    }
}
