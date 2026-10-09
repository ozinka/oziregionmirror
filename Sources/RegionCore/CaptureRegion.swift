import Foundation
import CoreGraphics

/// Display-local logical points, with the origin at the top left.
public struct CaptureRegion: Codable, Equatable {
    public let displayID: UInt32
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(displayID: UInt32, rect: CGRect) {
        self.displayID = displayID
        x = rect.minX
        y = rect.minY
        width = rect.width
        height = rect.height
    }

    public var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    public func isValid(in size: CGSize) -> Bool {
        [x, y, width, height, size.width, size.height].allSatisfy { $0.isFinite }
            && x >= 0 && y >= 0 && width >= 32 && height >= 32
            && rect.maxX <= size.width && rect.maxY <= size.height
    }

    public static func fromSelection(_ selection: CGRect, displayID: UInt32,
                                     screenSize: CGSize) -> CaptureRegion {
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: screenSize))
        return CaptureRegion(displayID: displayID,
            rect: CGRect(x: clipped.minX, y: screenSize.height - clipped.maxY,
                         width: clipped.width, height: clipped.height))
    }

    public func outputSize(scale: Double, maximumDimension: Double = 3840) -> CGSize {
        let ratio = min(scale, maximumDimension / max(width, height))
        return CGSize(width: max(2, floor(width * ratio / 2) * 2),
                      height: max(2, floor(height * ratio / 2) * 2))
    }
}

public struct RegionPreset: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public let region: CaptureRegion

    public init(name: String, region: CaptureRegion) {
        id = UUID()
        self.name = name
        self.region = region
    }
}
