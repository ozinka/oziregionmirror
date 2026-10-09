import AppKit
import ScreenCaptureKit
import RegionCore

@MainActor
final class CaptureController: NSObject, SCStreamDelegate {
    private var stream: SCStream?
    private var displayID: UInt32?
    private let output: MirrorView
    var didFail: ((Error) -> Void)?

    init(output: MirrorView) { self.output = output }

    static func recoveryMessage(for error: Error) -> String {
        let failure = error as NSError
        guard failure.domain == SCStreamErrorDomain,
              failure.code == SCStreamError.Code.userDeclined.rawValue else {
            return error.localizedDescription
        }
        return "macOS denied Screen Recording access to this build. Quit OziRegionMirror, turn its Screen Recording permission off and on, then reopen the app. If it is already enabled but still fails, remove the old entry and add the current OziRegionMirror.app again. Local ad-hoc rebuilds can invalidate the previous permission."
    }

    func start(region: CaptureRegion) async throws -> CGSize {
        await stop()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { $0.displayID == region.displayID }),
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == region.displayID
              }), region.isValid(in: screen.frame.size), screen.regionCaptureBounds.contains(region.rect) else {
            throw NSError(domain: "OziRegionMirror", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "The saved display or region is unavailable. Select a new region."])
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApps.isEmpty else {
            throw NSError(domain: "OziRegionMirror", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "Cannot exclude this app from capture. Launch the packaged .app and try again."])
        }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let size = region.outputSize(scale: screen.backingScaleFactor)
        let config = configuration(region: region, size: size)
        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        try newStream.addStreamOutput(output, type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "local.oziregionmirror.frames", qos: .userInteractive))
        stream = newStream
        displayID = region.displayID
        output.setEnabled(true)
        do { try await newStream.startCapture() }
        catch { await stop(); throw error }
        return size
    }

    func update(region: CaptureRegion) async throws -> CGSize {
        guard let current = stream, displayID == region.displayID,
              let screen = NSScreen.screens.first(where: {
                  ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == region.displayID
              }), region.isValid(in: screen.frame.size), screen.regionCaptureBounds.contains(region.rect) else { throw CancellationError() }
        let size = region.outputSize(scale: screen.backingScaleFactor)
        output.invalidateQueuedFrames()
        try await current.updateConfiguration(configuration(region: region, size: size))
        guard stream === current, displayID == region.displayID else { throw CancellationError() }
        return size
    }

    private func configuration(region: CaptureRegion, size: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.sourceRect = region.rect
        config.width = Int(size.width)
        config.height = Int(size.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 3
        config.showsCursor = true
        config.capturesAudio = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        return config
    }

    func stop() async {
        output.setEnabled(false)
        let previous = stream
        stream = nil
        displayID = nil
        try? await previous?.stopCapture()
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream else { return }
            self.stream = nil
            self.displayID = nil
            self.output.setEnabled(false)
            self.didFail?(error)
        }
    }
}
