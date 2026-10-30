import Foundation
import CoreGraphics

public enum CanvasTool: String, CaseIterable, Sendable {
    case pen = "Pen", arrow = "Arrow", rectangle = "Rectangle", ellipse = "Ellipse"
    case text = "Text", select = "Move Image"
}

public struct CanvasColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public init(red: Double = 1, green: Double = 0.15, blue: Double = 0.1) {
        self.red = red; self.green = green; self.blue = blue
    }
}

public struct CanvasElement: Identifiable, Equatable {
    public enum Kind: Equatable { case pen, arrow, rectangle, ellipse, text, image }
    public var id = UUID()
    public var kind: Kind
    public var points: [CGPoint]
    public var rect: CGRect
    public var color: CanvasColor
    public var width: Double
    public var text: String
    public var imageID: UUID?

    public init(kind: Kind, points: [CGPoint] = [], rect: CGRect = .zero,
                color: CanvasColor = CanvasColor(), width: Double = 0.004,
                text: String = "", imageID: UUID? = nil) {
        self.kind = kind; self.points = points; self.rect = rect
        self.color = color; self.width = width; self.text = text; self.imageID = imageID
    }
}

/// Each committed gesture is one history entry; unfinished gestures never enter history.
public struct CanvasHistory {
    public private(set) var elements: [CanvasElement] = []
    private var past: [[CanvasElement]] = []
    private var future: [[CanvasElement]] = []
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public var retainedImageIDs: Set<UUID> {
        Set(([elements] + past + future).flatMap { $0.compactMap(\.imageID) })
    }
    public init() {}

    public mutating func replace(with elements: [CanvasElement]) {
        guard elements != self.elements, elements.count <= 256 else { return }
        past.append(self.elements)
        if past.count > 50 { past.removeFirst() }
        self.elements = elements
        future.removeAll()
    }

    public mutating func undo() {
        guard let previous = past.popLast() else { return }
        future.append(elements); elements = previous
    }

    public mutating func redo() {
        guard let next = future.popLast() else { return }
        past.append(elements); elements = next
    }
}

public enum CanvasGeometry {
    public static func contentRect(size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let result = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: bounds.midX - result.width / 2, y: bounds.midY - result.height / 2,
                      width: result.width, height: result.height)
    }

    public static func normalized(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return .zero }
        return CGPoint(x: min(1, max(0, (point.x - rect.minX) / rect.width)),
                       y: min(1, max(0, (point.y - rect.minY) / rect.height)))
    }

    public static func rectangle(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    public static func moved(_ rect: CGRect, by delta: CGSize) -> CGRect {
        CGRect(x: min(max(0, rect.minX + delta.width), max(0, 1 - rect.width)),
               y: min(max(0, rect.minY + delta.height), max(0, 1 - rect.height)),
               width: rect.width, height: rect.height)
    }

    public static func resized(_ rect: CGRect, to point: CGPoint) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }
        let ratio = rect.width / rect.height
        let maximum = min(1 - rect.minX, (1 - rect.minY) * ratio)
        let width = min(maximum, max(0.02, point.x - rect.minX, (point.y - rect.minY) * ratio))
        return CGRect(x: rect.minX, y: rect.minY, width: width, height: width / ratio)
    }
}
