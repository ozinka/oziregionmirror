import Foundation
import CoreGraphics

public enum MirrorPlacement {
    /// Output placement uses global AppKit points, independently of the source crop.
    public static func parkedFrame(size: CGSize, displayFrames: [CGRect]) -> CGRect? {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              !displayFrames.isEmpty,
              displayFrames.allSatisfy({
                  [$0.minX, $0.minY, $0.width, $0.height, $0.maxX, $0.maxY].allSatisfy(\.isFinite)
                      && $0.width > 0 && $0.height > 0
              }) else { return nil }
        let desktop = displayFrames.dropFirst().reduce(displayFrames[0]) { $0.union($1) }
        let frame = CGRect(x: desktop.minX, y: desktop.minY - size.height - 50,
                           width: size.width, height: size.height)
        guard frame.minY.isFinite, displayFrames.allSatisfy({ !$0.intersects(frame) }) else { return nil }
        return frame
    }
}
