import AppKit
import AVFoundation
import ScreenCaptureKit
import CoreImage

final class MirrorView: NSView, SCStreamOutput {
    private let videoLayer = AVSampleBufferDisplayLayer()
    private let message = NSTextField(labelWithString: "Select a region to begin")
    private let lock = NSLock()
    private var pending = false
    private var generation = 0
    private var enabled = false
    private var concealed = true
    private var latestSampleBuffer: CMSampleBuffer?
    private var canvas: CanvasView?
    private var presentation: PresentationSession?
    private let imageContext = CIContext(options: [.cacheIntermediates: false])

    func attachPresentation(_ presentation: PresentationSession) {
        self.presentation = presentation
        let canvas = CanvasView(session: presentation, interactive: false)
        canvas.frame = bounds
        canvas.autoresizingMask = [.width, .height]
        addSubview(canvas, positioned: .below, relativeTo: message)
        self.canvas = canvas
        refreshPresentation()
    }

    func refreshPresentation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.isHidden = concealed || presentation?.mode != .live
        canvas?.isHidden = concealed
        canvas?.needsDisplay = true
        if !concealed { canvas?.displayIfNeeded() }
        CATransaction.commit()
    }

    func snapshotFrame() -> CGImage? {
        guard !concealed, let sample = latestSampleBuffer,
              let pixels = CMSampleBufferGetImageBuffer(sample) else { return nil }
        let image = CIImage(cvPixelBuffer: pixels)
        return imageContext.createCGImage(image, from: image.extent)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        videoLayer.videoGravity = .resizeAspect
        layer?.addSublayer(videoLayer)
        message.textColor = .white
        message.font = .systemFont(ofSize: 24, weight: .medium)
        message.alignment = .center
        addSubview(message)
        setConcealed(true, text: "Select a region to begin")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        videoLayer.contentsScale = window?.backingScaleFactor ?? 1
        CATransaction.commit()
        message.frame = CGRect(x: 16, y: bounds.midY - 20, width: bounds.width - 32, height: 40)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateBackingScale()
    }

    private func updateBackingScale() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scale = window?.backingScaleFactor ?? 1
        layer?.contentsScale = scale
        videoLayer.contentsScale = scale
        CATransaction.commit()
        needsLayout = true
    }

    func setEnabled(_ enabled: Bool) {
        lock.lock()
        self.enabled = enabled
        generation += 1
        lock.unlock()
        videoLayer.flushAndRemoveImage()
        if !enabled { latestSampleBuffer = nil }
    }

    func invalidateQueuedFrames() {
        lock.lock()
        generation += 1
        lock.unlock()
    }

    func setConcealed(_ concealed: Bool, text: String = "Sharing hidden") {
        self.concealed = concealed
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.isHidden = concealed || presentation?.mode != .live
        canvas?.isHidden = concealed
        CATransaction.commit()
        if concealed { videoLayer.flushAndRemoveImage(); latestSampleBuffer = nil }
        else if let sample = latestSampleBuffer { enqueue(sample) }
        message.stringValue = text
        message.isHidden = !concealed
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen else { return }
        acceptScreenFrame(sampleBuffer)
    }

    func acceptScreenFrame(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue else { return }
        lock.lock()
        guard enabled && !pending else { lock.unlock(); return }
        pending = true
        let token = generation
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let current = self.enabled && self.generation == token
            self.pending = false
            self.lock.unlock()
            guard current else { return }
            // A static source may send its only complete frame before startup reveals the output.
            self.latestSampleBuffer = sampleBuffer
            guard !self.concealed else { return }
            self.enqueue(sampleBuffer)
        }
    }

    private func enqueue(_ sample: CMSampleBuffer) {
        if videoLayer.status == .failed { videoLayer.flush() }
        if videoLayer.isReadyForMoreMediaData { videoLayer.enqueue(sample) }
    }
}
