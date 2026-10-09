import XCTest
import CoreGraphics
@testable import RegionCore

final class RegionEditingTests: XCTestCase {
    private let screen = CGSize(width: 1920, height: 1080)
    private let original = CaptureRegion(displayID: 7, rect: CGRect(x: 200, y: 150, width: 600, height: 400))

    func testMovePreservesSizeAndDisplay() {
        let moved = RegionEditing.applying(.move, delta: CGSize(width: 90, height: -50), to: original, screenSize: screen)
        XCTAssertEqual(moved.rect, CGRect(x: 290, y: 100, width: 600, height: 400))
        XCTAssertEqual(moved.displayID, 7)
    }

    func testMoveClampsAtEveryScreenEdge() {
        for delta in [CGSize(width: -9999, height: -9999), CGSize(width: 9999, height: 9999)] {
            let moved = RegionEditing.applying(.move, delta: delta, to: original, screenSize: screen)
            XCTAssertTrue(moved.isValid(in: screen))
            XCTAssertEqual(moved.rect.size, original.rect.size)
        }
        let last = RegionEditing.applying(.move, delta: CGSize(width: 9999, height: 9999), to: original, screenSize: screen)
        XCTAssertEqual(last.rect.maxX, screen.width)
        XCTAssertEqual(last.rect.maxY, screen.height)
    }

    func testAllEightHandlesMoveOnlyTheirSelectedEdges() {
        let cases: [(RegionHandle, CGRect)] = [
            (.topLeft, CGRect(x: 210, y: 170, width: 590, height: 380)),
            (.top, CGRect(x: 200, y: 170, width: 600, height: 380)),
            (.topRight, CGRect(x: 200, y: 170, width: 610, height: 380)),
            (.right, CGRect(x: 200, y: 150, width: 610, height: 400)),
            (.bottomRight, CGRect(x: 200, y: 150, width: 610, height: 420)),
            (.bottom, CGRect(x: 200, y: 150, width: 600, height: 420)),
            (.bottomLeft, CGRect(x: 210, y: 150, width: 590, height: 420)),
            (.left, CGRect(x: 210, y: 150, width: 590, height: 400))
        ]
        for (handle, expected) in cases {
            XCTAssertEqual(RegionEditing.applying(handle, delta: CGSize(width: 10, height: 20),
                to: original, screenSize: screen).rect, expected)
        }
    }

    func testCrossingOppositeEdgeStopsAtMinimumSize() {
        let left = RegionEditing.applying(.topLeft, delta: CGSize(width: 9999, height: 9999),
            to: original, screenSize: screen)
        XCTAssertEqual(left.rect.size, CGSize(width: 32, height: 32))
        XCTAssertEqual(left.rect.maxX, original.rect.maxX)
        XCTAssertEqual(left.rect.maxY, original.rect.maxY)
        let right = RegionEditing.applying(.bottomRight, delta: CGSize(width: -9999, height: -9999),
            to: original, screenSize: screen)
        XCTAssertEqual(right.rect.size, CGSize(width: 32, height: 32))
        XCTAssertEqual(right.rect.origin, original.rect.origin)
    }

    func testEveryResizeHandleStaysInsideDisplay() {
        for handle in RegionHandle.allCases where handle != .move {
            for delta in [CGSize(width: -9999, height: -9999), CGSize(width: 9999, height: 9999)] {
                XCTAssertTrue(RegionEditing.applying(handle, delta: delta, to: original, screenSize: screen).isValid(in: screen))
            }
        }
    }

    func testZeroDeltaRestoresDragStart() {
        XCTAssertEqual(RegionEditing.applying(.bottomRight, delta: .zero, to: original, screenSize: screen), original)
    }

    func testPendingQueueKeepsLatestPositionAndDrainsOnce() {
        var queue = LatestRegionQueue()
        queue.submit(original)
        let latest = RegionEditing.applying(.move, delta: CGSize(width: 100, height: 100), to: original, screenSize: screen)
        queue.submit(latest)
        XCTAssertEqual(queue.take(), latest)
        XCTAssertNil(queue.take())
        queue.submit(original)
        queue.clear()
        XCTAssertNil(queue.take())
    }

    func testUsableBoundsExcludeMenuBarDockAndHandleMargin() {
        let bounds = RegionEditing.captureBounds(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 50, width: 1920, height: 999))
        XCTAssertEqual(bounds, CGRect(x: 7, y: 38, width: 1906, height: 985))
    }

    func testUsableBoundsAreLocalToOffsetDisplay() {
        let bounds = RegionEditing.captureBounds(
            screenFrame: CGRect(x: -1920, y: 300, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 350, width: 1920, height: 999))
        XCTAssertEqual(bounds, CGRect(x: 7, y: 38, width: 1906, height: 985))
    }

    func testBottomDraggedAboveMenuBarStopsWithoutMovingTopEdge() {
        let bounds = CGRect(x: 7, y: 38, width: 1906, height: 985)
        let atTop = CaptureRegion(displayID: 7, rect: CGRect(x: 200, y: 38, width: 600, height: 400))
        for handle in [RegionHandle.bottom, .bottomLeft, .bottomRight] {
            let result = RegionEditing.applying(handle, delta: CGSize(width: 0, height: -9999), to: atTop, bounds: bounds)
            XCTAssertEqual(result.y, 38)
            XCTAssertEqual(result.height, 32)
            XCTAssertTrue(bounds.contains(result.rect))
        }
    }

    func testMovingAndResizingCannotEnterMenuBar() {
        let bounds = CGRect(x: 7, y: 38, width: 1906, height: 985)
        for handle in RegionHandle.allCases {
            let result = RegionEditing.applying(handle, delta: CGSize(width: -9999, height: -9999),
                to: original, bounds: bounds)
            XCTAssertTrue(bounds.contains(result.rect))
            XCTAssertGreaterThanOrEqual(result.y, 38)
        }
    }

    func testLegacyFullDisplayPresetFitsIntoUsableBounds() {
        let bounds = CGRect(x: 7, y: 38, width: 1906, height: 985)
        let preset = CaptureRegion(displayID: 7, rect: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(RegionEditing.fitting(preset, in: bounds)?.rect, bounds)
        XCTAssertEqual(RegionEditing.fitting(original, in: bounds), original)
    }
}
