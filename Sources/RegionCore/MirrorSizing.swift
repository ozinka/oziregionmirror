import Foundation
import CoreGraphics

public struct MirrorSizing {
    public let contentSize: CGSize
    public let actualScale: Double

    /// Natural size is already converted from capture pixels into window points.
    public init(naturalSize: CGSize, requestedScale: Double, availableSize: CGSize) {
        let fit = min(availableSize.width / naturalSize.width,
                      availableSize.height / naturalSize.height)
        actualScale = min(requestedScale, fit)
        contentSize = CGSize(width: naturalSize.width * actualScale,
                             height: naturalSize.height * actualScale)
    }

    public static func scale(capturePixels: CGSize, mirrorPixels: CGSize) -> Double {
        min(mirrorPixels.width / capturePixels.width, mirrorPixels.height / capturePixels.height)
    }
}
