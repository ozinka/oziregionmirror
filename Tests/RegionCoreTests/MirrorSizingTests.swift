import XCTest
import CoreGraphics
@testable import RegionCore

final class MirrorSizingTests: XCTestCase {
    func testNaturalSizeOnRetinaDoesNotDownsample() {
        let capture = CGSize(width: 3200, height: 1800)
        let natural = CGSize(width: 1600, height: 900)
        let result = MirrorSizing(naturalSize: natural, requestedScale: 1,
            availableSize: CGSize(width: 1920, height: 1050))
        XCTAssertEqual(result.contentSize, natural)
        XCTAssertEqual(MirrorSizing.scale(capturePixels: capture,
            mirrorPixels: CGSize(width: result.contentSize.width * 2, height: result.contentSize.height * 2)), 1)
    }

    func testSmallerPresetsScaleBothDimensions() {
        for fraction in [0.75, 0.5] {
            let result = MirrorSizing(naturalSize: CGSize(width: 1600, height: 900),
                requestedScale: fraction, availableSize: CGSize(width: 1920, height: 1050))
            XCTAssertEqual(result.contentSize, CGSize(width: 1600 * fraction, height: 900 * fraction))
            XCTAssertEqual(result.actualScale, fraction)
        }
    }

    func testFitOnLowerDensityDisplayReportsActualReduction() {
        let result = MirrorSizing(naturalSize: CGSize(width: 3200, height: 1800), requestedScale: 1,
            availableSize: CGSize(width: 1920, height: 1050))
        XCTAssertEqual(result.actualScale, 1050.0 / 1800, accuracy: 0.0001)
        XCTAssertEqual(result.contentSize.height, 1050, accuracy: 0.001)
        XCTAssertLessThan(result.contentSize.width, 1920)
    }

    func testCustomResizeUsesRenderedPixelScale() {
        XCTAssertEqual(MirrorSizing.scale(capturePixels: CGSize(width: 1600, height: 900),
            mirrorPixels: CGSize(width: 800, height: 600)), 0.5)
    }

    func testSmallRegionIsNotUpscaledBySizingPolicy() {
        let result = MirrorSizing(naturalSize: CGSize(width: 32, height: 32), requestedScale: 0.5,
            availableSize: CGSize(width: 1920, height: 1050))
        XCTAssertEqual(result.contentSize, CGSize(width: 16, height: 16))
    }
}
