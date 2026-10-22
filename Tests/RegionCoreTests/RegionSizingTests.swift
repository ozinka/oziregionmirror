import XCTest
@testable import RegionCore

final class RegionSizingTests: XCTestCase {
    private let bounds = CGRect(x: 7, y: 38, width: 1400, height: 900)
    private let region = CaptureRegion(displayID: 1, rect: CGRect(x: 200, y: 200, width: 400, height: 300))

    func testLockedRatioSurvivesEveryHandleAndExtremeDrag() {
        for ratio in [4.0 / 3, 16.0 / 9, 1.0] {
            let initial = CaptureRegion(displayID: 1, rect: CGRect(x: 200, y: 200, width: 400, height: 400 / ratio))
            for handle in RegionHandle.allCases {
                for delta in [CGSize(width: 5000, height: 5000), CGSize(width: -5000, height: -5000),
                              CGSize(width: 125, height: -80)] {
                    let result = RegionEditing.applying(handle, delta: delta, to: initial, bounds: bounds, aspectRatio: ratio)
                    XCTAssertEqual(result.width / result.height, ratio, accuracy: 0.000001)
                    XCTAssertGreaterThanOrEqual(result.width, 32)
                    XCTAssertGreaterThanOrEqual(result.height, 32)
                    XCTAssertGreaterThanOrEqual(result.x, bounds.minX - 0.000001)
                    XCTAssertGreaterThanOrEqual(result.y, bounds.minY - 0.000001)
                    XCTAssertLessThanOrEqual(result.rect.maxX, bounds.maxX + 0.000001)
                    XCTAssertLessThanOrEqual(result.rect.maxY, bounds.maxY + 0.000001)
                }
            }
        }
    }

    func testCornerKeepsOppositeCornerFixed() {
        let result = RegionEditing.applying(.topLeft, delta: CGSize(width: -70, height: -40),
                                           to: region, bounds: bounds, aspectRatio: 4.0 / 3)
        XCTAssertEqual(result.rect.maxX, region.rect.maxX, accuracy: 0.000001)
        XCTAssertEqual(result.rect.maxY, region.rect.maxY, accuracy: 0.000001)
    }

    func testSideKeepsOppositeEdgeAndPerpendicularCenterFixed() {
        let result = RegionEditing.applying(.right, delta: CGSize(width: 100, height: 0),
                                           to: region, bounds: bounds, aspectRatio: 4.0 / 3)
        XCTAssertEqual(result.x, region.x, accuracy: 0.000001)
        XCTAssertEqual(result.rect.midY, region.rect.midY, accuracy: 0.000001)
    }

    func testStandardSizeUsesExactCapturePixelsOnRetina() throws {
        let result = try XCTUnwrap(RegionEditing.sized(CGSize(width: 960, height: 540), around: region, in: bounds))
        XCTAssertEqual(result.outputSize(scale: 2), CGSize(width: 1920, height: 1080))
        XCTAssertTrue(bounds.contains(result.rect))
        XCTAssertEqual(result.displayID, region.displayID)
    }

    func testOversizeAndInvalidStandardSizesAreRejected() {
        for size in [CGSize(width: 1920, height: 1080), CGSize(width: 20, height: 100),
                     CGSize(width: Double.nan, height: 100)] {
            XCTAssertNil(RegionEditing.sized(size, around: region, in: bounds))
        }
    }

    func testLockingCurrentRatioDoesNotJumpWithoutMovement() {
        for handle in RegionHandle.allCases {
            let result = RegionEditing.applying(handle, delta: .zero, to: region, bounds: bounds,
                                               aspectRatio: region.width / region.height)
            XCTAssertEqual(result, region)
        }
    }
}
