import XCTest
import CoreGraphics
@testable import RegionCore

final class CaptureRegionTests: XCTestCase {
    func testSelectionFlipsToTopLeftCoordinates() {
        let region = CaptureRegion.fromSelection(CGRect(x: 100, y: 200, width: 600, height: 300),
            displayID: 7, screenSize: CGSize(width: 2560, height: 1440))
        XCTAssertEqual(region.rect, CGRect(x: 100, y: 940, width: 600, height: 300))
        XCTAssertTrue(region.isValid(in: CGSize(width: 2560, height: 1440)))
    }

    func testSelectionClipsAtScreenEdges() {
        let region = CaptureRegion.fromSelection(CGRect(x: -20, y: -10, width: 200, height: 100),
            displayID: 1, screenSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(region.rect, CGRect(x: 0, y: 990, width: 180, height: 90))
    }

    func testInvalidOrStaleRegionsAreRejected() {
        let size = CGSize(width: 1920, height: 1080)
        for rect in [CGRect(x: -1, y: 0, width: 100, height: 100),
                     CGRect(x: 1900, y: 0, width: 100, height: 100),
                     CGRect(x: 0, y: 0, width: 10, height: 100),
                     CGRect(x: 0, y: 0, width: Double.infinity, height: 100)] {
            XCTAssertFalse(CaptureRegion(displayID: 1, rect: rect).isValid(in: size))
        }
    }

    func testRetinaOutputIsBoundedAndEven() {
        let region = CaptureRegion(displayID: 1, rect: CGRect(x: 0, y: 0, width: 2560, height: 1440))
        XCTAssertEqual(region.outputSize(scale: 2), CGSize(width: 3840, height: 2160))
        let odd = CaptureRegion(displayID: 1, rect: CGRect(x: 0, y: 0, width: 601, height: 301))
        XCTAssertEqual(odd.outputSize(scale: 1), CGSize(width: 600, height: 300))
    }

    func testPresetRoundTripPreservesDisplayAndGeometry() throws {
        let preset = RegionPreset(name: "Code", region: CaptureRegion(displayID: 99,
            rect: CGRect(x: 20, y: 30, width: 800, height: 600)))
        let data = try JSONEncoder().encode([preset])
        XCTAssertEqual(try JSONDecoder().decode([RegionPreset].self, from: data), [preset])
    }
}
