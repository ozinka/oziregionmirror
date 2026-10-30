# Architecture

## Stack and ownership

Swift Package Manager builds one executable and a small testable core. AppKit owns windows, menus, selection, and lifecycle; SwiftUI renders Controls. ScreenCaptureKit produces a cropped display stream. AVSampleBufferDisplayLayer displays sample buffers without per-frame CPU image conversion. No external dependencies.

| Component | Responsibility |
| --- | --- |
| `RegionCore/CaptureRegion.swift` | Logical crop, validation, AppKit coordinate conversion, output size, Codable preset |
| `RegionCore/MirrorSizing.swift` | Proportional percentage sizing, explicit screen fit, actual pixel scale |
| `RegionCore/MirrorPlacement.swift` | Output placement outside the union of all AppKit display frames |
| `MirrorWindow.swift` | Stable output identity, parked/visible presentation, explicit unconstrained output sizing |
| `RegionCore/RegionEditing.swift` | Edge/move geometry, minimum size and bounds, latest-request queue |
| `RegionOutline.swift` | Dashed click-through border, eight input handles, drag label, Escape cancellation |
| `RegionSelector.swift` | One translucent selection window per display; drag/Escape; completes once |
| `CaptureController.swift` | Shareable display discovery, process exclusion, configuration, start/stop/errors |
| `MirrorView.swift` | Aspect-fit sample rendering, bounded delivery, generation invalidation, opaque concealment |
| `RegionCore/CanvasDocument.swift` | Normalized vector/image geometry and bounded per-gesture history |
| `PresentationSession.swift` | Live/frozen/board state, separate histories, bounded in-memory image assets, user-directed import/export |
| `CanvasView.swift` / `CanvasRenderer.swift` | Shared output/editor rendering, explicit input gestures and region-aligned editor window |
| `PresentationControls.swift` | Tools, color/width, Undo/Redo, freeze/board and image controls |
| `Application.swift` | Main-actor state, controls, stable mirror window, outline, presets, menu bar |
| `Resources/Info.plist` | Stable local bundle identity and minimum OS |
| `scripts/` | Tests and app packaging/ad-hoc signing |

## Application presence and Controls sizing

The outline's move-label click emits a callback through AppModel to the existing delegate showControls action, which deminiaturizes, orders forward and activates Controls. Activation occurs on mouse-up only if the move label did not cross a 3-point drag threshold; Escape cancels the interaction without activating Controls. Resize handles and the click-through outline/interior do not emit this request. This avoids stealing drag focus from Escape handling. We do not set legacy window sharing flags to claim that Controls cannot be selected or captured by Teams. ScreenCaptureKit picker exclusions are controlled by the capturing app, not a global policy that this app can apply to another process.

The menu-bar Dock toggle switches regular/accessory activation policy and persists `hideDockIcon` in bundle UserDefaults; startup applies it before running the application. Status menu remains available in either policy. Menu titles read actual policy when opening. Icon artwork is assigned once at launch. Controls reports its natural SwiftUI content height through a preference to the delegate, which resizes the existing window while preserving the top edge and clamping to the usable desktop. Content height is capped at 760 points with scrolling only for overflow; fixed width 620. No timer, polling or capture-stream changes.

## Coordinate contract

Successful capture starts park the existing output window below the union of all connected display frames with a 50-point gap. This is global AppKit geometry, independent of the source crop. A parked window remains ordered, opaque, unminimized and non-key, with its frame constraint bypassed. Show Mirror returns it to a live display; the model reapplies the selected scale using the actual destination backing conversion. Active close-button requests park instead of destroying the window. Reopening the application shows Controls. Geometry/backing notifications reapply sizing or placement without timers. Privacy Hide still conceals outgoing content; it does not toggle parking. Stop/error/display changes conceal first, then restore and order out parked output. Display changes still stop capture and require reselection. The output has only visible and parked presentation; the sample rendering and entire-process exclusion remain unchanged. Teams interoperability is pending acceptance.

AppKit screen frames use global bottom-left coordinates and may have negative origins. Selection views use display-local bottom-left points. `CaptureRegion` stores display-local **top-left logical points**:

```text
captureX = selection.minX
captureY = screenHeight - selection.maxY
```

The selector clips to its screen bounds before converting. `SCStreamConfiguration.sourceRect` receives the logical crop. Output width/height are physical pixels, computed using the selected screen's backing scale, capped to a longest side of 3840 and rounded down to even dimensions. Screen global origins are used only to place selection/outline windows, never as capture crop origins.

Test actual mixed-DPI capture before changing these rules. Avoid combining `SCDisplay.width` pixels with `NSScreen.frame` points.

Each successful start returns configured capture pixel dimensions to the model and resets mirror size to 100%. `NSWindow.convertFromBacking` converts capture pixels into content points on the mirror's current display. 75% and 50% scale both dimensions. Explicit output sizes bypass frame constraints and do not fit down to the desktop; oversized visible output keeps its title bar accessible and offers parking. The content aspect ratio follows capture pixel dimensions, including even rounding. Root and video layers update `contentsScale` when backing properties change. A display move reapplies the chosen percentage; manual resizing switches to a custom scale. Metadata diagnostics use `NSView.convertToBacking` and do not save image data. Resizing never restarts capture or replaces the shared window. Physical backing preservation while parking on mixed-DPI configurations remains a manual acceptance item.

## Usable capture bounds

`NSScreen.regionCaptureBounds` converts the visible desktop rectangle into display-local top-left points via `RegionEditing.captureBounds`. Exclude the menu bar/Dock and inset by 7 points so 14-point handles fit without shifting their centers. Initial selection clips to these bounds; live edits clamp to them; valid legacy presets fit into them on activation; capture rejects out-of-bounds regions. Overlays and the full-screen selector override `constrainFrameRect` because shared geometry already owns positioning. Without this, AppKit can move UI separately from the source crop near the menu bar. The capture-coordinate origin remains the full screen's top-left, not the visible area's origin.

## Standard sizes and aspect lock

Standard resolutions are capture pixels, divided by source backing scale before `RegionEditing.sized` validates exact logical dimensions and clamps their centered position. Unavailable sizes are disabled. Saved-region dimension labels derive pixels using the current source display scale and existing output cap; persistence remains logical points. Aspect lock lives in model/outline session state, with no preset migration. `RegionEditing.applying` optionally projects corner deltas onto a fixed-ratio diagonal; side edits retain the perpendicular center. Opposite anchors, bounds and minimum dimensions constrain size together. Move/Escape behavior is unchanged. Standard sizes/ratio changes use the same coalesced update queue. New selection/preset/standard size resets the lock.

## Capture lifecycle

Before asynchronous capture startup, the model conceals and orders out prior output presentation, restores any parked geometry without ordering it on screen, then parks the window before ordering it. It does not call `makeKeyAndOrderFront` while starting. Permission waits therefore do not require a visible output placeholder. Successful startup sizes and reveals content in the already parked output; a failed start restores and orders it out. Explicit Show Mirror remains the normal live output presentation action.

Controls serialize user starts/stops via `busy`. Start first invalidates old rendering and stops the old stream; it validates the display and crop, excludes the current process ID from the content filter, creates the cropped stream, and starts it. The output remains concealed until start succeeds. A source change reuses the existing mirror NSWindow but currently creates a fresh stream. Seamless `updateConfiguration` / `updateContentFilter` is future work.

Live outline edits stay on one display and use `SCStream.updateConfiguration`, retaining the existing stream/filter and output window. The model coalesces pending edits to the newest region and applies one update at a time, with a 33 ms interval before each application. Stop, new sessions, and display changes cancel/invalidate the drain. Presets cannot be saved while edits are pending. Escape queues the initial region again. Output aspect ratio/dimensions and the chosen (or custom) mirror pixel scale follow region changes. Normal clicks pass through the border; only eight 14-point handle windows and a drag-label window intercept input. The label sits outside the crop when space permits. Handles can be hidden independently of the border.

Screen callbacks arrive on a serial queue. Accept only valid complete screen frames. A lock protects one pending main-queue frame, an enabled flag, and a generation token. Stop invalidates already queued frames. A crop update also invalidates queued callbacks but retains the last displayed cropped frame until the updated stream produces a complete one; do not flush/disable all incoming frames around an update, because an unchanged desktop may then remain blank while ScreenCaptureKit emits idle frames. No update clears the source rectangle or switches to full-display capture. Main-thread rendering additionally checks concealment, so pending frames cannot reveal output while hidden. Layer frame changes and concealment disable implicit animation.

Unexpected stream failure disables output and notifies the main-actor model only if the failing stream is still current. On display configuration change, stop and require reselection rather than assume the old crop is still safe. A revision token invalidates a pending start on display changes; its output stays concealed and the stream is stopped when the pending start completes. Validate this on real hardware in T006.

## Presentation layers and image lifetime

The user explicitly enables Draw on Region. A separate borderless input window covers the source crop while editing; it draws markup and, in static modes, the frozen image or board. It is not a second output mirror. It belongs to the excluded process, so it cannot enter the raw source stream. The live input window has a 1% black background while drawing so transparent pixels still receive mouse input. Finish Drawing or Escape with no active gesture releases input; in live mode, committed source annotations remain in a clear, mouse-ignoring local window. This window renders only markup, never a duplicate live video frame. Hide, selection and teardown remove it. Each canvas redraw clears its previous pixels before rendering. Escape during a gesture discards the draft. A nonactivating floating PresentationToolbar sits above the editor; Controls keeps its normal window level. Toolbar actions use weak model callbacks and observe the existing session. RegionToolbarPlacement uses global AppKit geometry only at this window boundary: prefer below, or a side for tall crops, then other available edges; clamp to visible desktop bounds when there is no outside room. The panel follows source edits until moved by its six-dot grip. Manual placement and orientation remain fixed within the source display for the session, including tool/mode/region updates; selection or teardown resets placement. The panel disappears during selection and session teardown, and retains Hide/Resume access while concealed. Small desktops scroll the icon strip. Entire-process capture exclusion covers the toolbar, its menus and popovers. Crop editing is locked while drawing or in static presentation modes; selecting a new source resets the presentation session.

The stable output MirrorView keeps AVSampleBufferDisplayLayer for live video and adds a layer-backed CanvasView above it, below the concealment message. Both output and editor use CanvasRenderer and the same normalized top-left document; aspect-fit content geometry accounts for letterboxing. Draft edits are rendered in both views but committed once per gesture. Image selection borders/handles appear only in the editor. Explicit display invalidation updates output markup while the output window is parked. WindowServer/Teams cadence remains a manual gate.

Each complete accepted sample replaces one retained latest CMSampleBuffer (and its CVPixelBuffer) on the main queue. A complete frame arriving during concealed startup is retained but not displayed, so a static source can be shown/frozen without requiring another source change. Snapshot access is denied while concealed. Freeze Frame converts that buffer to a CGImage once through CIContext. Static modes hide the live video layer but keep the stream running; returning to live uses current capture. Source/frozen markup shares a history; whiteboard has an independent history and restores the prior source mode and drawing state. Freeze/resume changes only the source background mode, preserving the current drawing state and source annotations. All assets and snapshots are session-local and released on stop, capture error, display changes or source replacement. Concealment hides every output layer and exits editor input. Pending frame generations cannot restore stopped output.

Core document history retains at most 50 changes and 256 elements per canvas; gestures cap pen paths at 2048 normalized points. Image file/clipboard data is capped at 32 MB, ImageIO decodes the first image frame to at most 2048 pixels per side, and retained decoded assets (including Undo/Redo references) share a 64 MB budget. Import callbacks validate session identity and canvas mode; interrupted gestures use a separate epoch. No automatic image persistence is added.

PNG export exists only for the whiteboard, through an explicit NSSavePanel destination. It uses the same renderer at configured capture pixel dimensions, omits editor handles, and never exports a captured live/frozen background. Input images can be included in the board only after an explicit user import. This is the sole user-directed image write; screen captures remain in memory.

## Privacy and persistence

Exclude the **entire own process**, including dynamically created windows. Fail capture if the process cannot be resolved. Do not rely on a window sharing flag that Teams may ignore or that could also prevent legitimate mirror sharing.

Hide uses an opaque replacement, not blur or a frozen screenshot. Stop removes the video image. The source stream continues while hidden, but samples are not displayed or saved. Teams may buffer frames already received; the app cannot retract those.

Presets are Codable JSON under `regionPresets.v1` in bundle UserDefaults. They contain UUID/name/display ID/crop only. No pixels, audio, logging of screen content, telemetry, or network operations. Current CGDirectDisplayID persistence is provisional; durable UUID migration belongs to T009.

## Known engineering limits

- Swift language mode 5 via tools-version 5.9; actor/concurrency migration is not part of the initial prototype.
- Minimum macOS 13 is a target, not a tested compatibility claim.
- Ad-hoc signatures may cause TCC permission churn on rebuild.
- Mirror minimized/occluded behavior, sample timing, Teams visibility, display scaling and real performance are unverified.
- Selection windows are borderless with an explicit canBecomeKey override; verify Escape/first-responder behavior during manual checks.
