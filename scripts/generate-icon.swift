import AppKit

// Original vector artwork, rendered at each macOS icon resolution.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(size: Int, name: String) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()

    let background = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864),
        xRadius: 192, yRadius: 192)
    NSGradient(starting: NSColor(srgbRed: 0.08, green: 0.19, blue: 0.27, alpha: 1),
        ending: NSColor(srgbRed: 0.025, green: 0.06, blue: 0.12, alpha: 1))!
        .draw(in: background, angle: -65)

    let source = NSBezierPath(roundedRect: NSRect(x: 210, y: 390, width: 470, height: 350),
        xRadius: 30, yRadius: 30)
    NSColor(srgbRed: 0.30, green: 0.95, blue: 0.65, alpha: 1).setStroke()
    source.lineWidth = 22
    source.setLineDash([32, 20], count: 2, phase: 0)
    source.stroke()

    let mirror = NSBezierPath(roundedRect: NSRect(x: 362, y: 248, width: 470, height: 350),
        xRadius: 38, yRadius: 38)
    NSColor(srgbRed: 0.045, green: 0.11, blue: 0.18, alpha: 1).setFill()
    mirror.fill()
    NSGradient(starting: NSColor(srgbRed: 0.28, green: 0.93, blue: 0.70, alpha: 1),
        ending: NSColor(srgbRed: 0.22, green: 0.66, blue: 0.99, alpha: 1))!
        .draw(in: NSBezierPath(roundedRect: NSRect(x: 382, y: 268, width: 430, height: 310),
            xRadius: 23, yRadius: 23), angle: -45)

    // Matching corner marks connect the selected region to its mirrored output.
    NSColor.white.withAlphaComponent(0.95).setStroke()
    for (x, y, dx, dy) in [(CGFloat(430), CGFloat(530), CGFloat(1), CGFloat(-1)),
                            (764, 316, -1, 1)] {
        let corner = NSBezierPath()
        corner.move(to: NSPoint(x: x, y: y + dy * 64))
        corner.line(to: NSPoint(x: x, y: y))
        corner.line(to: NSPoint(x: x + dx * 64, y: y))
        corner.lineWidth = 18
        corner.lineJoinStyle = .round
        corner.lineCapStyle = .round
        corner.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent(name))
}

for points in [16, 32, 128, 256, 512] {
    try render(size: points, name: "icon_\(points)x\(points).png")
    try render(size: points * 2, name: "icon_\(points)x\(points)@2x.png")
}
