import AppKit
import AVFoundation
import ScreenCaptureKit

final class MirrorView: NSView, SCStreamOutput {
    private let videoLayer = AVSampleBufferDisplayLayer()
    private let message = NSTextField(labelWithString: "Select a region to begin")
    private let lock = NSLock()
    private var pending = false
    private var generation = 0
    private var enabled = false
    private var concealed = true

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
        videoLayer.isHidden = concealed
        CATransaction.commit()
        if concealed { videoLayer.flushAndRemoveImage() }
        message.stringValue = text
        message.isHidden = !concealed
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
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
            guard current && !self.concealed else { return }
            if self.videoLayer.status == .failed { self.videoLayer.flush() }
            if self.videoLayer.isReadyForMoreMediaData { self.videoLayer.enqueue(sampleBuffer) }
        }
    }
}
