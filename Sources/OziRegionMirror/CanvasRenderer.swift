import AppKit
import RegionCore

@MainActor
enum CanvasRenderer {
    static func draw(_ session: PresentationSession, in bounds: CGRect, selection: Bool) {
        let content = CanvasGeometry.contentRect(size: session.canvasSize, in: bounds)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: content).addClip()
        if session.mode == .board {
            NSColor.white.setFill(); content.fill()
        } else if session.mode == .frozen, let image = session.frozenImage {
            drawImage(image, in: content)
        }
        for item in session.elements {
            let rect = CGRect(x: content.minX + item.rect.minX * content.width,
                              y: content.minY + item.rect.minY * content.height,
                              width: item.rect.width * content.width, height: item.rect.height * content.height)
            func point(_ p: CGPoint) -> CGPoint {
                CGPoint(x: content.minX + p.x * content.width, y: content.minY + p.y * content.height)
            }
            let color = NSColor(srgbRed: item.color.red, green: item.color.green, blue: item.color.blue, alpha: 1)
            color.setStroke(); color.setFill()
            let path = NSBezierPath()
            path.lineWidth = max(1, item.width * content.width)
            path.lineCapStyle = .round; path.lineJoinStyle = .round
            switch item.kind {
            case .pen:
                if let first = item.points.first {
                    path.move(to: point(first))
                    for p in item.points.dropFirst() { path.line(to: point(p)) }
                    if item.points.count == 1 {
                        let p = point(first), radius = path.lineWidth / 2
                        NSBezierPath(ovalIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)).fill()
                    } else { path.stroke() }
                }
            case .arrow:
                if let first = item.points.first, let last = item.points.last {
                    let start = point(first), end = point(last)
                    path.move(to: start); path.line(to: end)
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    let length = max(10, path.lineWidth * 4)
                    for offset in [-0.5, 0.5] {
                        path.move(to: end)
                        path.line(to: CGPoint(x: end.x - cos(angle + offset) * length,
                                              y: end.y - sin(angle + offset) * length))
                    }
                    path.stroke()
                }
            case .rectangle: NSBezierPath(rect: rect).stroke(withWidth: path.lineWidth)
            case .ellipse: NSBezierPath(ovalIn: rect).stroke(withWidth: path.lineWidth)
            case .text:
                if let anchor = item.points.first {
                    (item.text as NSString).draw(at: point(anchor), withAttributes: [
                        .font: NSFont.systemFont(ofSize: max(12, item.width * content.width * 6), weight: .semibold),
                        .foregroundColor: color
                    ])
                }
            case .image:
                if let id = item.imageID, let image = session.images[id] { drawImage(image, in: rect) }
                if selection, item.id == session.selectedID {
                    NSColor.systemBlue.setStroke()
                    NSBezierPath(rect: rect).stroke(withWidth: 2)
                    NSColor.systemBlue.setFill()
                    CGRect(x: rect.maxX - 5, y: rect.maxY - 5, width: 10, height: 10).fill()
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawImage(_ image: CGImage, in rect: CGRect) {
        NSImage(cgImage: image, size: .zero).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                                               respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    }

    static func boardPNG(_ session: PresentationSession) -> Data? {
        guard session.mode == .board,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(session.canvasSize.width),
                                           pixelsHigh: Int(session.canvasSize.height), bitsPerSample: 8,
                                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        let context = graphics.cgContext
        context.translateBy(x: 0, y: session.canvasSize.height); context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(session, in: CGRect(origin: .zero, size: session.canvasSize), selection: false)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }
}

private extension NSBezierPath {
    func stroke(withWidth width: CGFloat) { lineWidth = width; stroke() }
}
