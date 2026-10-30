import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers
import RegionCore

enum PresentationMode: String, CaseIterable { case live = "Live", frozen = "Frozen", board = "Whiteboard" }

@MainActor
final class PresentationSession: ObservableObject {
    @Published private(set) var mode: PresentationMode = .live
    @Published private(set) var enabled = false
    @Published var drawing = false { didSet { gestureEpoch += 1; cancelDraft(); didChange?() } }
    @Published var tool: CanvasTool = .pen { didSet { gestureEpoch += 1; cancelDraft(); didChange?() } }
    @Published var color = CanvasColor()
    @Published var lineWidth: Double = 4
    @Published private(set) var source = CanvasHistory()
    @Published private(set) var board = CanvasHistory()
    private(set) var draft: CanvasElement?
    @Published var selectedID: UUID? { didSet { didChange?() } }
    @Published var notice = ""
    private(set) var frozenImage: CGImage?
    private(set) var images: [UUID: CGImage] = [:]
    private(set) var revision = UUID()
    private(set) var gestureEpoch = 0
    private var previousSourceMode: PresentationMode = .live
    private var previousSourceDrawing = false
    var canvasSize = CGSize(width: 960, height: 540)
    var isConcealed = false
    var didChange: (() -> Void)?
    var history: CanvasHistory { mode == .board ? board : source }
    var elements: [CanvasElement] {
        guard let draft else { return history.elements }
        if history.elements.contains(where: { $0.id == draft.id }) {
            return history.elements.map { $0.id == draft.id ? draft : $0 }
        }
        return history.elements + [draft]
    }

    func begin(size: CGSize) {
        reset(); canvasSize = size; enabled = true; didChange?()
    }

    func reset() {
        enabled = false; drawing = false; mode = .live
        source = CanvasHistory(); board = CanvasHistory()
        frozenImage = nil; images.removeAll(); draft = nil; selectedID = nil
        notice = ""; isConcealed = false; previousSourceMode = .live; previousSourceDrawing = false
        revision = UUID(); didChange?()
    }

    func setMode(_ mode: PresentationMode, snapshot: CGImage? = nil) {
        guard enabled else { return }
        if mode == .frozen, self.mode != .frozen {
            guard let snapshot else { notice = "Wait for a live frame before freezing."; return }
            frozenImage = snapshot
        }
        if mode == .board, self.mode != .board { previousSourceMode = self.mode }
        self.mode = mode; gestureEpoch += 1
        if mode == .live { frozenImage = nil }
        cancelDraft(); selectedID = nil; notice = ""; didChange?()
    }

    func updateDraft(_ element: CanvasElement) { draft = element; didChange?() }
    func cancelDraft() { guard draft != nil else { return }; draft = nil; didChange?() }

    func toggleBoard() {
        if mode == .board {
            setMode(previousSourceMode, snapshot: frozenImage)
            drawing = previousSourceDrawing
        } else {
            previousSourceDrawing = drawing
            setMode(.board)
            drawing = true
        }
    }

    func commitDraft() {
        guard enabled, !isConcealed, let draft else { return }
        var items = history.elements
        if let index = items.firstIndex(where: { $0.id == draft.id }) { items[index] = draft }
        else {
            guard items.count < 256 else { notice = "Canvas limit reached. Clear some items first."; cancelDraft(); return }
            items.append(draft)
        }
        self.draft = nil
        replace(items)
    }

    private func replace(_ elements: [CanvasElement]) {
        if mode == .board { board.replace(with: elements) } else { source.replace(with: elements) }
        collectImages(); didChange?()
    }

    func undo() {
        gestureEpoch += 1
        cancelDraft()
        if mode == .board { board.undo() } else { source.undo() }
        selectedID = nil; didChange?()
    }
    func redo() {
        gestureEpoch += 1
        cancelDraft()
        if mode == .board { board.redo() } else { source.redo() }
        selectedID = nil; didChange?()
    }
    func clear() { gestureEpoch += 1; cancelDraft(); selectedID = nil; replace([]) }
    func deleteSelected() {
        gestureEpoch += 1
        cancelDraft()
        guard let selectedID else { return }
        replace(history.elements.filter { $0.id != selectedID }); self.selectedID = nil
    }

    private func collectImages() {
        let retained = source.retainedImageIDs.union(board.retainedImageIDs)
        images = images.filter { retained.contains($0.key) }
    }

    func insertImage(data: Data) {
        guard enabled, !isConcealed else { return }
        guard data.count <= 32 * 1024 * 1024,
              let input = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(input, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { notice = "Choose an image file smaller than 32 MB."; return }
        collectImages()
        let bytes = images.values.reduce(0) { $0 + $1.bytesPerRow * $1.height }
        guard history.elements.count < 256, bytes + image.bytesPerRow * image.height <= 64 * 1024 * 1024
        else { notice = "Image memory limit reached. Start a new capture to clear stored images."; return }
        let id = UUID()
        images[id] = image
        let aspect = Double(image.width) / Double(image.height)
        var size = CGSize(width: 0.6, height: 0.6 * canvasSize.width / canvasSize.height / aspect)
        if size.height > 0.8 { size.width *= 0.8 / size.height; size.height = 0.8 }
        updateDraft(CanvasElement(kind: .image, rect: CGRect(x: (1 - size.width) / 2, y: (1 - size.height) / 2,
                                                            width: size.width, height: size.height), imageID: id))
        selectedID = draft?.id; commitDraft(); tool = .select; drawing = true; notice = ""
    }

    func pasteImage() {
        guard let data = NSPasteboard.general.data(forType: .png) ?? NSPasteboard.general.data(forType: .tiff)
        else { notice = "Copy an image first, then choose Paste Image."; return }
        insertImage(data: data)
    }

    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]; panel.allowsMultipleSelection = false
        let revision = self.revision
        let mode = self.mode
        panel.begin { [weak self] response in
            guard let self, self.enabled, !self.isConcealed, self.revision == revision, self.mode == mode,
                  response == .OK, let url = panel.url else { return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 32 * 1024 * 1024 else { self.notice = "Choose an image file smaller than 32 MB."; return }
                self.insertImage(data: try Data(contentsOf: url, options: .mappedIfSafe))
            } catch { self.notice = "Could not read this image: \(error.localizedDescription)" }
        }
    }

    func saveBoard() {
        guard enabled, !isConcealed, mode == .board else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = "Whiteboard.png"
        let revision = self.revision
        panel.begin { [weak self] response in
            guard let self, self.enabled, !self.isConcealed, self.revision == revision, self.mode == .board,
                  response == .OK, let url = panel.url else { return }
            do {
                guard let data = CanvasRenderer.boardPNG(self) else { self.notice = "Could not render the whiteboard."; return }
                try data.write(to: url, options: .atomic)
                self.notice = "Whiteboard saved."
            } catch { self.notice = "Could not save the whiteboard: \(error.localizedDescription)" }
        }
    }
}
