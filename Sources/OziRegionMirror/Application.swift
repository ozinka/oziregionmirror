import AppKit
import SwiftUI
import Combine
import RegionCore

@MainActor
final class AppModel: NSObject, ObservableObject, NSWindowDelegate {
    var didRequestControls: (() -> Void)?
    @Published var status = "Select a region, then share the mirror window in Teams."
    @Published var active = false
    @Published var busy = false
    @Published var hidden = false
    @Published var presets: [RegionPreset] = []
    @Published var presetName = ""
    @Published var mirrorScaleLabel = ""
    @Published var mirrorScaleNotice = ""
    @Published var mirrorScalePercent: Int?
    @Published var editingRegion = true
    @Published var adjustingRegion = false
    @Published private(set) var regionRatio = "Free"
    @Published private(set) var parkedMirror = false
    private var capturePixels: CGSize?
    private var requestedMirrorScale: Double?
    private var applyingMirrorSize = false
    private var region: CaptureRegion?
    private let selector = RegionSelector()
    private let mirror = MirrorView(frame: CGRect(x: 0, y: 0, width: 960, height: 540))
    private var mirrorWindow: MirrorWindow!
    private let outline = RegionOutline()
    private var regionUpdates = LatestRegionQueue()
    private var regionUpdateTask: Task<Void, Never>?
    private lazy var capture = CaptureController(output: mirror)
    private let presetKey = "regionPresets.v1"
    private var captureRevision = 0

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: presetKey),
           let saved = try? JSONDecoder().decode([RegionPreset].self, from: data) { presets = saved }
        mirrorWindow = MirrorWindow(contentRect: mirror.frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        mirrorWindow.title = "OziRegionMirror — Share this window"
        mirrorWindow.contentView = mirror
        mirrorWindow.contentMinSize = CGSize(width: 16, height: 16)
        mirrorWindow.delegate = self
        mirrorWindow.isReleasedWhenClosed = false
        mirrorWindow.center()
        capture.didFail = { [weak self] error in
            guard let self else { return }
            self.active = false
            self.captureRevision += 1
            self.invalidateRegionUpdates()
            self.outline.hide()
            self.mirror.setConcealed(true, text: "Capture stopped")
            self.dismissMirror()
            self.status = CaptureController.recoveryMessage(for: error)
        }
        outline.didEdit = { [weak self] region in self?.enqueueRegionUpdate(region) }
        outline.didRequestControls = { [weak self] in self?.didRequestControls?() }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.displayConfigurationChanged()
                }
            }
    }

    func selectRegion() {
        guard !busy else { return }
        outline.setEditing(false)
        selector.select { [weak self] region in
            guard let self else { return }
            guard let region else {
                self.outline.setEditing(self.editingRegion)
                return
            }
            self.start(region)
        }
    }

    func start(_ requestedRegion: CaptureRegion) {
        guard !busy else { return }
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == requestedRegion.displayID
        }), requestedRegion.isValid(in: screen.frame.size),
           let region = RegionEditing.fitting(requestedRegion, in: screen.regionCaptureBounds) else {
            status = "The display or region is unavailable. Select a new region."
            return
        }
        regionRatio = "Free"
        outline.aspectRatio = nil
        invalidateRegionUpdates()
        captureRevision += 1
        let revision = captureRevision
        busy = true
        active = false
        hidden = false
        outline.hide()
        mirror.setConcealed(true, text: "Starting capture…")
        dismissMirror()
        // Order the output only after moving it off the desktop, including while permission is pending.
        applyingMirrorSize = true
        parkedMirror = mirrorWindow.park()
        applyingMirrorSize = false
        Task {
            defer { busy = false }
            do {
                let pixels = try await capture.start(region: region)
                guard captureRevision == revision else {
                    await capture.stop()
                    return
                }
                self.region = region
                capturePixels = pixels
                active = true
                mirrorWindow.contentAspectRatio = pixels
                parkMirror()
                setMirrorScale(100)
                mirror.setConcealed(false)
                outline.show(region, editing: editingRegion)
                status = "Live • \(Int(region.width)) × \(Int(region.height)) points • 30 fps target"
            } catch {
                active = false
                mirror.setConcealed(true, text: "Capture unavailable")
                dismissMirror()
                if captureRevision == revision {
                    status = CaptureController.recoveryMessage(for: error)
                }
            }
        }
    }

    func stop() {
        guard !busy else { return }
        selector.cancel()
        captureRevision += 1
        invalidateRegionUpdates()
        busy = true
        active = false
        hidden = false
        outline.hide()
        mirror.setConcealed(true, text: "Sharing stopped")
        dismissMirror()
        Task { await capture.stop(); busy = false }
        status = "Stopped. The mirror window contains no captured image."
    }

    private func displayConfigurationChanged() {
        guard active || busy else { return }
        selector.cancel()
        captureRevision += 1
        invalidateRegionUpdates()
        active = false
        hidden = false
        outline.hide()
        mirror.setConcealed(true, text: "Display configuration changed")
        dismissMirror()
        if !busy {
            busy = true
            Task { await capture.stop(); busy = false }
        }
        status = "Display configuration changed. Select the region again."
    }

    func toggleHidden() {
        guard active && !busy else { return }
        hidden.toggle()
        mirror.setConcealed(hidden)
    }

    private func dismissMirror() {
        applyingMirrorSize = true
        mirrorWindow.orderOut(nil)
        mirrorWindow.restoreFromParking()
        parkedMirror = false
        applyingMirrorSize = false
        mirrorScaleNotice = ""
    }

    func toggleParkedMirror() {
        guard active, !busy, !adjustingRegion else { return }
        if parkedMirror { showMirror() } else { parkMirror() }
    }

    private func parkMirror() {
        let scale = requestedMirrorScale ?? capturePixels.map {
            MirrorSizing.scale(capturePixels: $0, mirrorPixels: mirror.convertToBacking(mirror.bounds).size)
        } ?? 1
        applyingMirrorSize = true
        parkedMirror = mirrorWindow.park()
        applyingMirrorSize = false
        if parkedMirror { applyMirrorScale(scale) }
        else { mirrorScaleNotice = "The mirror could not be parked. It remains available on the desktop." }
    }

    private func showMirror() {
        let scale = requestedMirrorScale ?? capturePixels.map {
            MirrorSizing.scale(capturePixels: $0, mirrorPixels: mirror.convertToBacking(mirror.bounds).size)
        } ?? 1
        applyingMirrorSize = true
        mirrorWindow.restoreFromParking()
        parkedMirror = false
        applyingMirrorSize = false
        applyMirrorScale(scale)
        mirrorWindow.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if active, !busy { parkMirror() }
        else if !busy { sender.orderOut(nil) }
        return false
    }

    func toggleRegionEditing() {
        guard active && !busy else { return }
        editingRegion.toggle()
        outline.setEditing(editingRegion)
    }

    private func invalidateRegionUpdates() {
        regionUpdates.clear()
        regionUpdateTask?.cancel()
        regionUpdateTask = nil
        adjustingRegion = false
    }

    private func enqueueRegionUpdate(_ region: CaptureRegion) {
        guard active && !busy else { return }
        regionUpdates.submit(region)
        guard regionUpdateTask == nil else { return }
        adjustingRegion = true
        let revision = captureRevision
        regionUpdateTask = Task {
            defer {
                if captureRevision == revision { regionUpdateTask = nil; adjustingRegion = false }
            }
            while active && captureRevision == revision && !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 33_000_000) }
                catch { return }
                guard active, captureRevision == revision, !Task.isCancelled,
                      let next = regionUpdates.take() else { return }
                do {
                    let pixels = try await capture.update(region: next)
                    guard active, captureRevision == revision, !Task.isCancelled else { return }
                    let customScale = capturePixels.map {
                        MirrorSizing.scale(capturePixels: $0, mirrorPixels: mirror.convertToBacking(mirror.bounds).size)
                    } ?? 1
                    let chosenScale = requestedMirrorScale ?? customScale
                    let customSizing = requestedMirrorScale == nil
                    let changedSize = capturePixels != pixels
                    self.region = next
                    capturePixels = pixels
                    if changedSize {
                        applyingMirrorSize = true
                        mirrorWindow.contentAspectRatio = pixels
                        applyingMirrorSize = false
                        applyMirrorScale(chosenScale)
                        if customSizing { requestedMirrorScale = nil }
                    }
                    mirror.setConcealed(hidden)
                    status = "Live • \(Int(next.width)) × \(Int(next.height)) points • 30 fps target"
                } catch {
                    guard active, captureRevision == revision, !Task.isCancelled else { return }
                    stop()
                    status = CaptureController.recoveryMessage(for: error)
                    return
                }
            }
        }
    }

    func setMirrorScale(_ percent: Int) {
        applyMirrorScale(Double(percent) / 100)
    }

    private func applyMirrorScale(_ fraction: Double) {
        guard let pixels = capturePixels, active,
              let screen = mirrorWindow.screen ?? NSScreen.main else { return }
        requestedMirrorScale = fraction
        let naturalSize = mirrorWindow.convertFromBacking(CGRect(origin: .zero, size: pixels)).size
        let chrome = mirrorWindow.frameRect(forContentRect: CGRect(origin: .zero, size: naturalSize)).height - naturalSize.height
        let visible = screen.visibleFrame
        let contentSize = CGSize(width: naturalSize.width * fraction, height: naturalSize.height * fraction)
        applyingMirrorSize = true
        mirrorWindow.setOutputContentSize(contentSize)
        var frame = mirrorWindow.frame
        frame.origin.x = max(visible.minX, min(frame.minX, visible.maxX - frame.width))
        frame.origin.y = frame.height > visible.height ? visible.maxY - frame.height
            : max(visible.minY, min(frame.minY, visible.maxY - frame.height))
        if parkedMirror { mirrorWindow.park() }
        else { mirrorWindow.setOutputFrame(frame) }
        applyingMirrorSize = false
        mirrorScaleNotice = !parkedMirror && (contentSize.width > visible.width || contentSize.height + chrome > visible.height)
            ? "The mirror exceeds this desktop at the selected size. Park Mirror keeps the desktop clear without reducing detail."
            : ""
        updateMirrorScaleLabel()
    }

    private func updateMirrorScaleLabel() {
        guard let pixels = capturePixels else { return }
        let backing = mirror.convertToBacking(mirror.bounds).size
        let scale = MirrorSizing.scale(capturePixels: pixels, mirrorPixels: backing)
        mirrorScalePercent = [100, 75, 50].first { abs(scale - Double($0) / 100) < 0.001 }
        mirrorScaleLabel = "Capture \(Int(pixels.width)) × \(Int(pixels.height)) px → Mirror \(Int(backing.width.rounded())) × \(Int(backing.height.rounded())) px • \(String(format: "%.1f", scale * 100))%"
    }

    func windowDidResize(_ notification: Notification) {
        guard !applyingMirrorSize, !parkedMirror else { return }
        requestedMirrorScale = nil
        mirrorScaleNotice = ""
        updateMirrorScaleLabel()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard !applyingMirrorSize else { return }
        if let scale = requestedMirrorScale {
            applyMirrorScale(scale)
        } else { updateMirrorScaleLabel() }
    }

    func windowDidMove(_ notification: Notification) {
        guard parkedMirror, !applyingMirrorSize else { return }
        applyingMirrorSize = true
        mirrorWindow.park()
        applyingMirrorSize = false
    }

    func windowDidChangeBackingProperties(_ notification: Notification) {
        windowDidChangeScreen(notification)
    }

    static let standardSizes: [CGSize] = [
        CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080),
        CGSize(width: 2560, height: 1440), CGSize(width: 3840, height: 2160),
        CGSize(width: 1024, height: 768)
    ]

    private func screen(for region: CaptureRegion) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == region.displayID
        }
    }

    func presetDimensions(_ preset: RegionPreset) -> String {
        let region = preset.region
        let points = "\(Int(region.width.rounded())) × \(Int(region.height.rounded())) pt"
        guard let screen = screen(for: region) else { return "\(points) • display unavailable" }
        let pixels = region.outputSize(scale: screen.backingScaleFactor)
        return "\(points) • \(Int(pixels.width)) × \(Int(pixels.height)) px"
    }

    private func standardRegion(_ pixels: CGSize) -> CaptureRegion? {
        guard let region, let screen = screen(for: region), active, !busy, !adjustingRegion else { return nil }
        return RegionEditing.sized(CGSize(width: pixels.width / screen.backingScaleFactor,
                                         height: pixels.height / screen.backingScaleFactor),
                                   around: region, in: screen.regionCaptureBounds)
    }

    func canApplyStandardSize(_ pixels: CGSize) -> Bool { standardRegion(pixels) != nil }

    func applyStandardSize(_ pixels: CGSize) {
        guard let updated = standardRegion(pixels) else { return }
        regionRatio = "Free"
        outline.aspectRatio = nil
        outline.show(updated, editing: editingRegion)
        enqueueRegionUpdate(updated)
    }

    func setRegionRatio(_ choice: String) {
        guard active, !busy, !adjustingRegion, let region, let screen = screen(for: region) else { return }
        let ratios = ["16:9": 16.0 / 9, "4:3": 4.0 / 3, "1:1": 1.0]
        guard choice != "Free" else {
            regionRatio = choice
            outline.aspectRatio = nil
            return
        }
        let ratio = choice == "Current" ? region.width / region.height : ratios[choice]
        guard let ratio else { return }
        let bounds = screen.regionCaptureBounds
        let width = min(max(region.width, max(32, 32 * ratio)), bounds.width, bounds.height * ratio)
        guard let updated = RegionEditing.sized(CGSize(width: width, height: width / ratio),
                                                around: region, in: bounds) else { return }
        regionRatio = choice
        outline.aspectRatio = ratio
        outline.show(updated, editing: editingRegion)
        enqueueRegionUpdate(updated)
    }

    func savePreset() {
        guard let region, !adjustingRegion else { return }
        let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && presets.count < 10 else { return }
        presets.append(RegionPreset(name: name, region: region))
        persistPresets()
        presetName = ""
    }

    func deletePreset(_ preset: RegionPreset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) { UserDefaults.standard.set(data, forKey: presetKey) }
    }

}

private struct ControlsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct ControlsView: View {
    @ObservedObject var model: AppModel
    var contentHeightChanged: (CGFloat) -> Void = { _ in }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("OziRegionMirror").font(.title.bold())
                Text(model.status).textSelection(.enabled)
                HStack {
                    Button("Select Region", action: model.selectRegion).keyboardShortcut("n")
                    Button(model.hidden ? "Resume View" : "Hide View", action: model.toggleHidden)
                        .disabled(!model.active).keyboardShortcut("b")
                    Button("Stop", action: model.stop).disabled(!model.active)
                }.disabled(model.busy)
                Button(model.editingRegion ? "Hide Region Handles" : "Edit Region", action: model.toggleRegionEditing)
                    .disabled(!model.active || model.busy)
                HStack {
                    Button(model.parkedMirror ? "Show Mirror" : "Park Mirror", action: model.toggleParkedMirror)
                        .disabled(!model.active || model.busy || model.adjustingRegion)
                    if model.parkedMirror {
                        Text("Mirror is off the desktop.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("If Teams does not list the mirror, show it, select it in Teams, then park it again. Hide View conceals shared content.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Menu("Standard Size") {
                        ForEach(AppModel.standardSizes.indices, id: \.self) { index in
                            let size = AppModel.standardSizes[index]
                            Button("\(Int(size.width)) × \(Int(size.height)) px") { model.applyStandardSize(size) }
                                .disabled(!model.canApplyStandardSize(size))
                        }
                    }
                    Picker("Aspect ratio", selection: Binding(get: { model.regionRatio }, set: model.setRegionRatio)) {
                        ForEach(["Free", "Current", "16:9", "4:3", "1:1"], id: \.self) { Text($0).tag($0) }
                    }
                }.disabled(!model.active || model.busy || model.adjustingRegion)
                HStack {
                    Text("Mirror size")
                    ForEach([100, 75, 50], id: \.self) { percent in
                        Button("\(percent)%") { model.setMirrorScale(percent) }
                            .fontWeight(model.mirrorScalePercent == percent ? .bold : .regular)
                    }
                }.disabled(!model.active || model.busy)
                if !model.mirrorScaleLabel.isEmpty {
                    Text(model.mirrorScaleLabel).font(.caption).textSelection(.enabled)
                }
                if !model.mirrorScaleNotice.isEmpty {
                    Text(model.mirrorScaleNotice).font(.callout).foregroundStyle(.orange)
                }
                Text("100% maps each captured pixel to one mirror pixel. 75% and 50% reduce detail. Capture is capped at 3840 px on its longest side.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Saved Regions (\(model.presets.count)/10)").font(.headline)
                HStack {
                    TextField("Region name", text: $model.presetName)
                    Button("Save", action: model.savePreset)
                        .disabled(!model.active || model.adjustingRegion || model.presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.presets.count >= 10)
                }
                ForEach(model.presets) { preset in
                    HStack {
                        Button(preset.name) { model.start(preset.region) }.disabled(model.busy)
                            .lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 12)
                        Text("\(model.presetDimensions(preset)) • (\(Int(preset.region.x)), \(Int(preset.region.y)))")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize().multilineTextAlignment(.trailing)
                            .help("Position: \(Int(preset.region.x)) × \(Int(preset.region.y)) pt")
                        Button("Delete") { model.deletePreset(preset) }
                    }
                }
                Button("Open Screen Recording Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }.padding(24).frame(width: 620)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: ControlsHeightKey.self, value: geometry.size.height)
                })
        }.onPreferenceChange(ControlsHeightKey.self, perform: contentHeightChanged)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var controls: NSWindow!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Refresh the running Dock icon even when Launch Services caches an older local build.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        model = AppModel()
        controls = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        controls.title = "OziRegionMirror Controls"
        controls.isReleasedWhenClosed = false
        model.didRequestControls = { [weak self] in self?.showControls() }
        controls.contentView = NSHostingView(rootView: ControlsView(model: model, contentHeightChanged: { [weak self] height in
            self?.resizeControls(to: height)
        }))
        controls.center()
        showControls()
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Controls…", action: #selector(showControls), keyEquivalent: "")
        menu.addItem(withTitle: "Select Region…", action: #selector(selectRegion), keyEquivalent: "n")
        menu.addItem(withTitle: "Hide / Resume View", action: #selector(toggleHidden), keyEquivalent: "b")
        menu.addItem(withTitle: "Stop", action: #selector(stop), keyEquivalent: ".")
        menu.addItem(withTitle: "Show / Hide Region Handles", action: #selector(toggleRegionEditing), keyEquivalent: "e")
        menu.addItem(withTitle: "Show Mirror", action: #selector(toggleParkedMirror), keyEquivalent: "")
        let sizeItem = NSMenuItem(title: "Mirror Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu(title: "Mirror Size")
        for percent in [100, 75, 50] {
            let item = NSMenuItem(title: "\(percent)%", action: #selector(resizeMirror(_:)), keyEquivalent: "")
            item.tag = percent
            item.target = self
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Dock Icon", action: #selector(toggleDockIcon), keyEquivalent: "")
        menu.addItem(withTitle: "Quit OziRegionMirror", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "OziRegionMirror")
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = menu.copy() as? NSMenu
        appItem.submenu?.delegate = self
        mainMenu.addItem(appItem)
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func resizeControls(to height: CGFloat) {
        guard height > 0, let controls else { return }
        let visible = (controls.screen ?? NSScreen.main)?.visibleFrame ?? controls.frame
        let chrome = controls.frame.height - controls.contentLayoutRect.height
        let target = min(ceil(height), 760, visible.height - chrome - 20)
        var frame = controls.frameRect(forContentRect: CGRect(x: 0, y: 0, width: 620, height: target))
        frame.origin.x = min(max(controls.frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = max(visible.minY, min(controls.frame.maxY, visible.maxY) - frame.height)
        if controls.frame != frame { controls.setFrame(frame, display: true) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.first { $0.action == #selector(toggleParkedMirror) }?.title =
            model.parkedMirror ? "Show Mirror" : "Park Mirror"
        menu.items.first { $0.action == #selector(toggleDockIcon) }?.title =
            NSApp.activationPolicy() == .regular ? "Hide Dock Icon" : "Show Dock Icon"
    }

    @objc private func toggleDockIcon() {
        let hide = NSApp.activationPolicy() == .regular
        if NSApp.setActivationPolicy(hide ? .accessory : .regular) {
            UserDefaults.standard.set(hide, forKey: "hideDockIcon")
        }
    }

    @objc private func showControls() {
        if controls.isMiniaturized { controls.deminiaturize(nil) }
        controls.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func selectRegion() { model.selectRegion() }
    @objc private func toggleHidden() { model.toggleHidden() }
    @objc private func stop() { model.stop() }
    @objc private func toggleRegionEditing() { model.toggleRegionEditing() }
    @objc private func toggleParkedMirror() { model.toggleParkedMirror() }
    @objc private func resizeMirror(_ sender: NSMenuItem) { model.setMirrorScale(sender.tag) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControls()
        return false
    }
}

@main
struct OziRegionMirrorApplication {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(UserDefaults.standard.bool(forKey: "hideDockIcon") ? .accessory : .regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
