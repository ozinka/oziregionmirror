import SwiftUI
import AppKit
import RegionCore

@MainActor
final class PresentationToolbar {
    private var window: ToolbarPanel?
    private var contentVertical: Bool?
    private var draggedOrigin: CGPoint?
    private var draggedVertical = false
    private let state = ToolbarState()
    private let session: PresentationSession
    private let action: (ToolbarAction) -> Void

    init(session: PresentationSession, action: @escaping (ToolbarAction) -> Void) {
        self.session = session
        self.action = action
    }

    func show(region: CaptureRegion, on screen: NSScreen, locked: Bool, hidden: Bool) {
        let rect = CGRect(x: screen.frame.minX + region.x, y: screen.frame.maxY - region.y - region.height,
                          width: region.width, height: region.height)
        let visible = screen.visibleFrame.insetBy(dx: 4, dy: 4)
        let placement = RegionToolbarPlacement.adjacent(to: rect, within: visible)
        let vertical = draggedOrigin == nil ? placement.vertical : draggedVertical
        var frame = CGRect(origin: draggedOrigin ?? placement.frame.origin,
                           size: draggedOrigin == nil ? placement.frame.size : (window?.frame.size ?? placement.frame.size))
        frame.origin = clamped(frame.origin, size: frame.size, to: visible)
        if draggedOrigin != nil { draggedOrigin = frame.origin }
        if state.locked != locked { state.locked = locked }
        if state.hidden != hidden { state.hidden = hidden }
        if window == nil {
            let panel = ToolbarPanel(contentRect: placement.frame, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.title = "Presentation Tools"
            window = panel
        }
        if contentVertical != vertical || window?.contentView == nil {
            window?.contentView = NSHostingView(rootView: PresentationTools(session: session, state: state,
                vertical: vertical, action: action, move: { [weak self] origin in
                    guard let self, let window = self.window else { return }
                    let origin = self.clamped(origin, size: window.frame.size, to: visible)
                    self.draggedOrigin = origin
                    self.draggedVertical = vertical
                    window.setFrameOrigin(origin)
                }))
            contentVertical = vertical
        }
        if window?.frame != frame { window?.setFrame(frame, display: true) }
        if window?.isVisible != true { window?.orderFrontRegardless() }
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
        contentVertical = nil
        draggedOrigin = nil
    }

    private func clamped(_ origin: CGPoint, size: CGSize, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(origin.x, bounds.minX), max(bounds.minX, bounds.maxX - size.width)),
                y: min(max(origin.y, bounds.minY), max(bounds.minY, bounds.maxY - size.height)))
    }
}

private final class ToolbarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

enum ToolbarAction { case drawing, freeze, board, controls, hide, stop }

@MainActor
private final class ToolbarState: ObservableObject {
    @Published var locked = false
    @Published var hidden = false
}

private struct PresentationTools: View {
    @ObservedObject var session: PresentationSession
    @ObservedObject var state: ToolbarState
    let vertical: Bool
    let action: (ToolbarAction) -> Void
    let move: (CGPoint) -> Void
    @State private var showingStyle = false
    @State private var showingNotice = false

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        layout {
            ToolbarGrip(move: move).frame(width: vertical ? 44 : 24, height: vertical ? 24 : 44)
            ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
                let layout = vertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
                layout {
                    icon("cursorarrow", "Use desktop: finish drawing and keep annotations visible", selected: !session.drawing) {
                        if session.drawing { action(.drawing) }
                    }
                    ForEach(CanvasTool.allCases, id: \.self) { tool in
                        icon(symbol(tool), hint(tool), selected: session.drawing && session.tool == tool) {
                            session.tool = tool
                            if !session.drawing { action(.drawing) }
                        }
                    }
                    icon(session.mode == .frozen ? "play.fill" : "pause.fill", session.mode == .frozen ? "Resume live video; keep annotations" : "Freeze video; keep the current drawing tool",
                         selected: session.mode == .frozen) { action(.freeze) }.disabled(session.mode == .board)
                    icon("rectangle.on.rectangle", session.mode == .board ? "Return to source and its annotations" : "Open a separate whiteboard",
                         selected: session.mode == .board) { action(.board) }
                    icon("arrow.uturn.backward", "Undo", enabled: session.history.canUndo, action: session.undo)
                    icon("arrow.uturn.forward", "Redo", enabled: session.history.canRedo, action: session.redo)
                    icon("paintpalette", "Color and Line Width") { showingStyle.toggle() }
                        .popover(isPresented: $showingStyle, arrowEdge: vertical ? .leading : .bottom) { styleOptions }
                    Menu {
                        Button("Open Image…", action: session.openImage)
                        Button("Paste Image", action: session.pasteImage)
                        Button("Delete Selected Image", action: session.deleteSelected).disabled(session.selectedID == nil)
                        Divider()
                        Button("Save Board PNG…", action: session.saveBoard).disabled(session.mode != .board)
                    } label: { Image(systemName: "photo").frame(width: 28, height: 28) }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Images and Board Export").disabled(state.locked)
                    Menu {
                        Button("Clear Canvas", action: session.clear).disabled(session.history.elements.isEmpty || state.locked)
                        Divider()
                        Button(state.hidden ? "Resume View" : "Hide View") { action(.hide) }
                        Button("Controls…") { action(.controls) }
                        Button("Stop Sharing") { action(.stop) }
                        if !session.notice.isEmpty {
                            Divider()
                            Button("Show Message…") { showingNotice = true }
                        }
                    } label: {
                        Image(systemName: session.notice.isEmpty ? "ellipsis" : "exclamationmark.circle")
                            .foregroundStyle(session.notice.isEmpty ? Color.primary : Color.orange)
                            .frame(width: 28, height: 28)
                    }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("More Actions")
                }.padding(8)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.12)))
        .alert("Presentation", isPresented: $showingNotice) { Button("OK", role: .cancel) {} } message: { Text(session.notice) }
        .onChange(of: session.notice) { value in if !value.isEmpty { showingNotice = true } }
    }

    private func icon(_ symbol: String, _ title: String, selected: Bool = false, enabled: Bool = true,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .background(selected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).help(title).accessibilityLabel(title).disabled(!enabled || state.locked)
    }

    private var styleOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorPicker("Color", selection: Binding(get: {
                Color(red: session.color.red, green: session.color.green, blue: session.color.blue)
            }, set: { color in
                if let rgb = NSColor(color).usingColorSpace(.sRGB) {
                    session.color = CanvasColor(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
                }
            }), supportsOpacity: false)
            .help("Choose the color for new annotations")
            Picker("Line Width", selection: $session.lineWidth) {
                ForEach([2.0, 4.0, 8.0, 12.0], id: \.self) { Text("\(Int($0)) px").tag($0) }
            }
            .help("Choose the width for new annotations")
        }.padding().frame(width: 220)
    }

    private func hint(_ tool: CanvasTool) -> String {
        switch tool {
        case .pen: return "Pen: drag to draw on live video or a frozen frame"
        case .arrow: return "Arrow: drag from the tail to the arrowhead"
        case .rectangle: return "Rectangle: drag between opposite corners"
        case .ellipse: return "Ellipse: drag to set its bounds"
        case .text: return "Text: click where the text should appear"
        case .select: return "Images: drag to move; drag the blue corner to resize"
        }
    }

    private func symbol(_ tool: CanvasTool) -> String {
        switch tool {
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .select: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

private struct ToolbarGrip: NSViewRepresentable {
    let move: (CGPoint) -> Void
    func makeNSView(context: Context) -> ToolbarGripView { ToolbarGripView(move: move) }
    func updateNSView(_ view: ToolbarGripView, context: Context) { view.move = move }
}

final class ToolbarGripView: NSView {
    var move: (CGPoint) -> Void
    private var initialPointer: CGPoint?
    private var initialOrigin: CGPoint?

    init(move: @escaping (CGPoint) -> Void) {
        self.move = move
        super.init(frame: .zero)
        toolTip = "Drag to move the presentation toolbar"
        setAccessibilityLabel("Move presentation toolbar")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.secondaryLabelColor.setFill()
        for x in [-3.0, 3.0] {
            for y in [-6.0, 0.0, 6.0] {
                NSBezierPath(ovalIn: CGRect(x: bounds.midX + x - 1.5, y: bounds.midY + y - 1.5,
                                           width: 3, height: 3)).fill()
            }
        }
    }
    override func mouseDown(with event: NSEvent) {
        initialPointer = window?.convertPoint(toScreen: event.locationInWindow)
        initialOrigin = window?.frame.origin
    }
    override func mouseDragged(with event: NSEvent) {
        guard let initialPointer, let initialOrigin, let window else { return }
        let pointer = window.convertPoint(toScreen: event.locationInWindow)
        move(CGPoint(x: initialOrigin.x + pointer.x - initialPointer.x,
                     y: initialOrigin.y + pointer.y - initialPointer.y))
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        initialPointer = nil; initialOrigin = nil
    }
}
