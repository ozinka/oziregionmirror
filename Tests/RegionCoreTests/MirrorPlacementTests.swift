import XCTest
@testable import RegionCore

final class MirrorPlacementTests: XCTestCase {
    func testParkingAvoidsAllDisplaysIncludingOneBelowPrimary() throws {
        let displays = [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                        CGRect(x: -400, y: -1440, width: 2560, height: 1440),
                        CGRect(x: -1680, y: 200, width: 1680, height: 1050)]
        let size = CGSize(width: 3840, height: 2160)
        let parked = try XCTUnwrap(MirrorPlacement.parkedFrame(size: size, displayFrames: displays))
        XCTAssertEqual(parked.size, size)
        XCTAssertEqual(parked.maxY, -1490)
        XCTAssertTrue(displays.allSatisfy { !$0.intersects(parked) })
    }

    func testParkingUsesDesktopCoordinatesWithoutResizingOversizedOutput() throws {
        let display = CGRect(x: 300, y: -200, width: 1200, height: 800)
        let parked = try XCTUnwrap(MirrorPlacement.parkedFrame(size: CGSize(width: 6000, height: 4000),
                                                            displayFrames: [display]))
        XCTAssertEqual(parked, CGRect(x: 300, y: -4250, width: 6000, height: 4000))
    }

    func testDisplayOrderDoesNotChangeParking() {
        let displays = [CGRect(x: 0, y: 0, width: 1920, height: 1080),
                        CGRect(x: 1920, y: -400, width: 1920, height: 1080)]
        let size = CGSize(width: 1280, height: 720)
        XCTAssertEqual(MirrorPlacement.parkedFrame(size: size, displayFrames: displays),
                       MirrorPlacement.parkedFrame(size: size, displayFrames: displays.reversed()))
    }

    func testUnavailableOrInvalidGeometryCannotProduceAParkingPosition() {
        let display = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        XCTAssertNil(MirrorPlacement.parkedFrame(size: CGSize(width: 100, height: 100), displayFrames: []))
        for size in [CGSize.zero, CGSize(width: -1, height: 100),
                     CGSize(width: CGFloat.nan, height: 100), CGSize(width: 100, height: CGFloat.infinity)] {
            XCTAssertNil(MirrorPlacement.parkedFrame(size: size, displayFrames: [display]))
        }
        XCTAssertNil(MirrorPlacement.parkedFrame(size: CGSize(width: 100, height: 100),
                                               displayFrames: [CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100)]))
    }
}
