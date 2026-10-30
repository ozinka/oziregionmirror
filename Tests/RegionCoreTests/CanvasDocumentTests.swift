import XCTest
@testable import RegionCore

final class CanvasDocumentTests: XCTestCase {
    func testUndoRedoAndNewBranch() {
        var history = CanvasHistory()
        let first = CanvasElement(kind: .pen, points: [CGPoint(x: 0.1, y: 0.2)])
        let second = CanvasElement(kind: .arrow)
        history.replace(with: [first])
        history.replace(with: [first, second])
        history.undo()
        XCTAssertEqual(history.elements, [first]); XCTAssertTrue(history.canRedo)
        history.redo()
        XCTAssertEqual(history.elements, [first, second])
        history.undo(); history.replace(with: [])
        XCTAssertFalse(history.canRedo)
        history.undo(); XCTAssertEqual(history.elements, [first])
    }

    func testClearKeepsImagesAvailableForUndo() {
        let id = UUID()
        var history = CanvasHistory()
        let image = CanvasElement(kind: .image, imageID: id)
        history.replace(with: [image]); history.replace(with: [])
        XCTAssertTrue(history.retainedImageIDs.contains(id))
        history.undo(); XCTAssertEqual(history.elements, [image])
        history.undo(); XCTAssertTrue(history.retainedImageIDs.contains(id))
    }

    func testHistoryAndElementLimitsAreBounded() {
        var history = CanvasHistory()
        for index in 0..<70 {
            history.replace(with: [CanvasElement(kind: .text, text: "\(index)")])
        }
        for _ in 0..<50 { XCTAssertTrue(history.canUndo); history.undo() }
        XCTAssertFalse(history.canUndo)
        let current = history.elements
        history.replace(with: (0..<257).map { _ in CanvasElement(kind: .pen) })
        XCTAssertEqual(history.elements, current)
    }

    func testLetterboxedPointsStayNormalizedAcrossOutputSizes() {
        let source = CGSize(width: 1920, height: 1080)
        let small = CanvasGeometry.contentRect(size: source, in: CGRect(x: 0, y: 0, width: 800, height: 800))
        let large = CanvasGeometry.contentRect(size: source, in: CGRect(x: 0, y: 0, width: 1600, height: 1600))
        XCTAssertEqual(small, CGRect(x: 0, y: 175, width: 800, height: 450))
        XCTAssertEqual(CanvasGeometry.normalized(CGPoint(x: 200, y: 287.5), in: small),
                       CanvasGeometry.normalized(CGPoint(x: 400, y: 575), in: large))
        XCTAssertEqual(CanvasGeometry.normalized(CGPoint(x: -20, y: -20), in: small), .zero)
    }

    func testImagesMoveAndResizeWithinCanvasWithoutLosingAspect() {
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.2)
        XCTAssertEqual(CanvasGeometry.moved(rect, by: CGSize(width: 20, height: -20)),
                       CGRect(x: 0.6, y: 0, width: 0.4, height: 0.2))
        let resized = CanvasGeometry.resized(rect, to: CGPoint(x: 4, y: 4))
        XCTAssertEqual(resized.width / resized.height, 2, accuracy: 0.00001)
        XCTAssertLessThanOrEqual(resized.maxX, 1)
        XCTAssertLessThanOrEqual(resized.maxY, 1)
        XCTAssertEqual(resized.origin, rect.origin)
    }

    func testSourceAndBoardHistoriesRemainIndependent() {
        var source = CanvasHistory(), board = CanvasHistory()
        source.replace(with: [CanvasElement(kind: .arrow)])
        board.replace(with: [CanvasElement(kind: .rectangle)])
        board.undo()
        XCTAssertEqual(source.elements.count, 1)
        XCTAssertTrue(board.elements.isEmpty)
    }
}
