import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import RegionCore

@main
struct PresentationCheck {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        checkToolbar()
        let session = PresentationSession()
        session.begin(size: CGSize(width: 200, height: 100))
        session.drawing = true
        let view = CanvasView(session: session, interactive: true)
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 200, height: 100),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        func mouse(_ type: NSEvent.EventType, _ x: Double, _ y: Double) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: CGPoint(x: x * 200, y: (1 - y) * 100), modifierFlags: [],
                               timestamp: 0, windowNumber: window.windowNumber, context: nil,
                               eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
        }
        session.tool = .rectangle
        view.mouseDown(with: mouse(.leftMouseDown, 0.1, 0.2))
        view.mouseDragged(with: mouse(.leftMouseDragged, 0.4, 0.5))
        view.mouseUp(with: mouse(.leftMouseUp, 0.4, 0.5))
        precondition(session.history.elements.count == 1)
        let rectangle = session.history.elements[0].rect
        precondition(abs(rectangle.minX - 0.1) < 0.001 && abs(rectangle.minY - 0.2) < 0.001)
        session.undo(); precondition(session.history.elements.isEmpty)
        session.redo(); precondition(session.history.elements.count == 1)
        view.mouseDown(with: mouse(.leftMouseDown, 0.1, 0.1))
        session.tool = .arrow
        view.mouseUp(with: mouse(.leftMouseUp, 0.5, 0.5))
        precondition(session.history.elements.count == 1 && session.draft == nil)
        view.mouseDown(with: mouse(.leftMouseDown, 0.1, 0.1))
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: "",
                                     charactersIgnoringModifiers: "", isARepeat: false, keyCode: 53)!
        view.keyDown(with: escape)
        view.mouseUp(with: mouse(.leftMouseUp, 0.9, 0.9))
        precondition(session.history.elements.count == 1 && session.draft == nil)

        let fixture = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 20, pixelsHigh: 10,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<10 { for x in 0..<20 { fixture.setColor(y < 5 ? NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1) : NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), atX: x, y: y) } }
        let imageData = fixture.representation(using: .png, properties: [:])!
        session.setMode(.frozen, snapshot: fixture.cgImage!)
        session.toggleBoard()
        precondition(session.mode == .board && session.history.elements.isEmpty)
        session.insertImage(data: imageData)
        precondition(session.board.elements.count == 1 && session.images.count == 1)
        let item = session.board.elements[0]
        let rendered = NSBitmapImageRep(data: CanvasRenderer.boardPNG(session)!)!
        precondition(rendered.pixelsWide == 200 && rendered.pixelsHigh == 100)
        let top = rendered.colorAt(x: 100, y: 30)!.usingColorSpace(.sRGB)!
        let bottom = rendered.colorAt(x: 100, y: 70)!.usingColorSpace(.sRGB)!
        precondition(top.redComponent > 0.8 && top.greenComponent < 0.2, "Image top must stay red")
        precondition(bottom.greenComponent > 0.8 && bottom.redComponent < 0.2, "Image bottom must stay green")
        precondition(rendered.colorAt(x: 1, y: 1)!.usingColorSpace(.sRGB)!.redComponent > 0.9)
        view.mouseDown(with: mouse(.leftMouseDown, 0.4, 0.4))
        view.mouseDragged(with: mouse(.leftMouseDragged, 0.5, 0.5))
        view.mouseUp(with: mouse(.leftMouseUp, 0.5, 0.5))
        precondition(session.board.elements[0].rect.minX > item.rect.minX)
        session.undo(); precondition(session.board.elements[0].rect == item.rect)
        session.selectedID = item.id
        view.mouseDown(with: mouse(.leftMouseDown, item.rect.maxX, item.rect.maxY))
        view.mouseUp(with: mouse(.leftMouseUp, 0.9, 0.9))
        precondition(session.board.elements[0].rect.width > item.rect.width)
        session.clear(); precondition(session.images.count == 1 && session.board.elements.isEmpty)
        session.undo(); precondition(session.board.elements.count == 1)
        for tool in [CanvasTool.pen, .arrow, .rectangle, .ellipse] {
            session.tool = tool
            view.mouseDown(with: mouse(.leftMouseDown, 0.05, 0.05))
            view.mouseDragged(with: mouse(.leftMouseDragged, 0.1, 0.1))
            view.mouseUp(with: mouse(.leftMouseUp, 0.2, 0.2))
        }
        session.updateDraft(CanvasElement(kind: .text, points: [CGPoint(x: 0.05, y: 0.8)], text: "Board"))
        session.commitDraft()
        let marked = NSBitmapImageRep(data: CanvasRenderer.boardPNG(session)!)!
        let ink = marked.colorAt(x: 20, y: 10)!.usingColorSpace(.sRGB)!
        precondition(ink.redComponent > 0.8 && ink.greenComponent < 0.3)
        session.toggleBoard()
        precondition(session.mode == .frozen && session.frozenImage != nil && session.source.elements.count == 1)
        session.setMode(.live); precondition(session.frozenImage == nil)
        precondition(session.source.elements.count == 1, "Resume must preserve source annotations")
        precondition(CanvasRenderer.boardPNG(session) == nil)

        // Exercise the real source overlay, including a live arrow before any freeze.
        session.begin(size: CGSize(width: 200, height: 100))
        let editor = AnnotationEditor(session: session)
        let screen = NSScreen.main!
        let region = CaptureRegion(displayID: 0, rect: CGRect(x: 100, y: 150, width: 200, height: 100))
        session.drawing = true
        session.tool = .arrow
        editor.show(region: region, on: screen)
        let input = NSApp.windows.first { ($0.contentView as? CanvasView)?.interactive == true && $0.isVisible }!
        let inputView = input.contentView as! CanvasView
        precondition(!input.ignoresMouseEvents && input.backgroundColor.alphaComponent > 0,
                     "Live drawing must have a hittable window background")
        session.didChange = { editor.redraw() }
        inputView.mouseDown(with: mouse(.leftMouseDown, 0.1, 0.5))
        inputView.mouseUp(with: mouse(.leftMouseUp, 0.9, 0.5))
        precondition(session.source.elements.count == 1 && session.source.elements[0].kind == .arrow)
        precondition(session.mode == .live)
        session.setMode(.frozen, snapshot: fixture.cgImage!)
        session.setMode(.live)
        precondition(session.drawing && session.source.elements.count == 1)
        session.drawing = false
        editor.show(region: region, on: screen)
        precondition(input.isVisible && input.ignoresMouseEvents, "Finished annotations must be click-through")
        session.toggleBoard()
        precondition(session.drawing && session.board.elements.isEmpty)
        session.toggleBoard()
        precondition(!session.drawing && session.source.elements.count == 1)
        session.drawing = true
        editor.show(region: region, on: screen)
        precondition(!input.ignoresMouseEvents)
        session.undo(); precondition(session.source.elements.isEmpty)
        session.redo(); precondition(session.source.elements.count == 1)
        session.clear(); precondition(session.source.elements.isEmpty)
        session.didChange = nil
        editor.hide()

        let mirror = MirrorView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let output = MirrorWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 100),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
        output.isReleasedWhenClosed = false
        output.contentView = mirror
        precondition(output.park())
        mirror.attachPresentation(session)
        mirror.layoutSubtreeIfNeeded()
        mirror.setEnabled(true)
        mirror.setConcealed(false)
        session.undo() // Restore the arrow after the Clear check above.
        mirror.refreshPresentation()
        let outputCanvas = mirror.subviews.compactMap { $0 as? CanvasView }.first!
        func annotationPixel() -> NSColor {
            let bitmap = outputCanvas.bitmapImageRepForCachingDisplay(in: outputCanvas.bounds)!
            outputCanvas.cacheDisplay(in: outputCanvas.bounds, to: bitmap)
            return bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)!.usingColorSpace(.sRGB)!
        }
        precondition(annotationPixel().redComponent > 0.8, "Live output must render annotations without freezing")
        session.clear(); mirror.refreshPresentation()
        precondition(annotationPixel().alphaComponent < 0.01, "Clear must remove old pixels from the live overlay")
        session.undo(); mirror.refreshPresentation()
        precondition(annotationPixel().redComponent > 0.8, "Undo Clear must restore live annotations")
        var pixelBuffer: CVPixelBuffer?
        precondition(CVPixelBufferCreate(nil, 200, 100, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &pixelBuffer) == kCVReturnSuccess)
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        memset(CVPixelBufferGetBaseAddress(pixelBuffer!), 255, CVPixelBufferGetBytesPerRow(pixelBuffer!) * 100)
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer!, formatDescriptionOut: &format)
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixelBuffer!, formatDescription: format!,
                                                sampleTiming: &timing, sampleBufferOut: &sample)
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sample!, createIfNecessary: true)! as NSArray
        let dictionary = attachments[0] as! NSMutableDictionary
        dictionary[SCStreamFrameInfo.status.rawValue] = SCFrameStatus.complete.rawValue
        mirror.setConcealed(true)
        mirror.acceptScreenFrame(sample!)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(mirror.snapshotFrame() == nil)
        mirror.setConcealed(false)
        precondition(mirror.snapshotFrame() != nil, "A complete live frame must be freezable")
        session.setMode(.frozen, snapshot: mirror.snapshotFrame())
        mirror.refreshPresentation()
        mirror.setConcealed(true)
        let canvas = mirror.subviews.first { $0 is CanvasView }!
        let layers = mirror.layer!.sublayers!
        var canvasBranch = canvas.layer!
        while let parent = canvasBranch.superlayer, parent !== mirror.layer! { canvasBranch = parent }
        let canvasIndex = layers.firstIndex { $0 === canvasBranch }!
        let videoIndex = layers.firstIndex { $0 is AVSampleBufferDisplayLayer }!
        precondition(canvasIndex > videoIndex, "Annotations must composite above video")
        precondition(canvas.isHidden && mirror.snapshotFrame() == nil)
        mirror.setEnabled(false)
        session.reset()
        precondition(session.images.isEmpty && session.frozenImage == nil && session.source.elements.isEmpty && session.board.elements.isEmpty)
        mirror.setEnabled(true)
        mirror.setConcealed(false)
        mirror.acceptScreenFrame(sample!)
        mirror.setEnabled(false)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(mirror.snapshotFrame() == nil)
        output.orderOut(nil)
        print("PASS: native canvas gestures, Undo/Redo, cancellation, independent source/board, image orientation/move/resize, in-memory board PNG, sample-buffer freeze, concealment and teardown")
    }
}
