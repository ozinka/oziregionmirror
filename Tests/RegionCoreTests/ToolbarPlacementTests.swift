import XCTest
@testable import RegionCore

final class RegionToolbarPlacementTests: XCTestCase {
    private let desktop = CGRect(x: 0, y: 30, width: 1440, height: 840)

    func testLandscapeUsesSpaceBelowAndLeavesHandleGap() {
        let region = CGRect(x: 400, y: 300, width: 600, height: 300)
        let placement = RegionToolbarPlacement.adjacent(to: region, within: desktop)
        XCTAssertFalse(placement.vertical)
        XCTAssertEqual(placement.frame.midX, region.midX)
        XCTAssertEqual(region.minY - placement.frame.maxY, 32)
        XCTAssertFalse(placement.frame.intersects(region))
    }

    func testTallRegionPrefersSideAndCanSwitchToLeft() {
        for x: CGFloat in [400, 1300] {
            let region = CGRect(x: x, y: 50, width: 100, height: 800)
            let placement = RegionToolbarPlacement.adjacent(to: region, within: desktop)
            XCTAssertTrue(placement.vertical)
            XCTAssertTrue(desktop.contains(placement.frame))
            XCTAssertFalse(placement.frame.intersects(region))
            if x == 1300 { XCTAssertLessThan(placement.frame.maxX, region.minX) }
        }
    }

    func testBottomEdgeUsesSideAndWideBottomRegionUsesTop() {
        let side = RegionToolbarPlacement.adjacent(to: CGRect(x: 100, y: 40, width: 600, height: 300), within: desktop)
        XCTAssertTrue(side.vertical)
        let top = RegionToolbarPlacement.adjacent(to: CGRect(x: 10, y: 40, width: 1420, height: 300), within: desktop)
        XCTAssertFalse(top.vertical)
        XCTAssertGreaterThan(top.frame.minY, 340)
    }

    func testFullDesktopAndSmallScreensKeepToolsReachable() {
        for bounds in [desktop, CGRect(x: -320, y: -600, width: 320, height: 240)] {
            let placement = RegionToolbarPlacement.adjacent(to: bounds, within: bounds)
            XCTAssertTrue(bounds.contains(placement.frame))
            XCTAssertFalse(placement.vertical)
        }
    }

    func testPlacementUsesOffsetDisplayBoundsAndClampsAlongEdge() {
        let bounds = CGRect(x: -1600, y: 300, width: 1440, height: 840)
        let region = CGRect(x: -1590, y: 600, width: 100, height: 60)
        let placement = RegionToolbarPlacement.adjacent(to: region, within: bounds)
        XCTAssertTrue(bounds.contains(placement.frame))
        XCTAssertEqual(placement.frame.minX, bounds.minX)
        XCTAssertLessThan(placement.frame.maxY, region.minY)
    }
}
