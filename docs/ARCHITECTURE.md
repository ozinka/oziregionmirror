# Architecture

## Stack and ownership

Swift Package Manager builds one executable and a small testable core. AppKit owns windows, menus, selection, and lifecycle; SwiftUI renders Controls. ScreenCaptureKit produces a cropped display stream. AVSampleBufferDisplayLayer displays sample buffers without per-frame CPU image conversion. No external dependencies.

| Component | Responsibility |
| --- | --- |
| `RegionCore/CaptureRegion.swift` | Logical crop, validation, AppKit coordinate conversion, output size, Codable preset |
| `RegionCore/MirrorSizing.swift` | Proportional percentage sizing, explicit screen fit, actual pixel scale |
| `RegionCore/RegionEditing.swift` | Edge/move geometry, minimum size and bounds, latest-request queue |
| `RegionOutline.swift` | Dashed click-through border, eight input handles, drag label, Escape cancellation |
| `RegionSelector.swift` | One translucent selection window per display; drag/Escape; completes once |
| `CaptureController.swift` | Shareable display discovery, process exclusion, configuration, start/stop/errors |
| `MirrorView.swift` | Aspect-fit sample rendering, bounded delivery, generation invalidation, opaque concealment |
| `Application.swift` | Main-actor state, controls, stable mirror window, outline, presets, menu bar |
| `Resources/Info.plist` | Stable local bundle identity and minimum OS |
| `scripts/` | Tests and app packaging/ad-hoc signing |

## Coordinate contract

AppKit screen frames use global bottom-left coordinates and may have negative origins. Selection views use display-local bottom-left points. `CaptureRegion` stores display-local **top-left logical points**:

```text
captureX = selection.minX
captureY = screenHeight - selection.maxY
```

The selector clips to its screen bounds before converting. `SCStreamConfiguration.sourceRect` receives the logical crop. Output width/height are physical pixels, computed using the selected screen's backing scale, capped to a longest side of 3840 and rounded down to even dimensions. Screen global origins are used only to place selection/outline windows, never as capture crop origins.

Test actual mixed-DPI capture before changing these rules. Avoid combining `SCDisplay.width` pixels with `NSScreen.frame` points.

Each successful start returns configured capture pixel dimensions to the model and resets mirror size to 100%. `NSWindow.convertFromBacking` converts capture pixels into content points on the mirror's current display. 75% and 50% scale both dimensions. Usable screen size excludes window chrome; oversized requests fit proportionally and show a notice rather than claim 1:1. The content aspect ratio follows capture pixel dimensions, including even rounding. Root and video layers update `contentsScale` when backing properties change. A display move reapplies the chosen percentage; manual resizing switches to a custom scale. Metadata diagnostics use `NSView.convertToBacking` and do not save image data. Resizing never restarts capture or replaces the shared window.

## Usable capture bounds

`NSScreen.regionCaptureBounds` converts the visible desktop rectangle into display-local top-left points via `RegionEditing.captureBounds`. Exclude the menu bar/Dock and inset by 7 points so 14-point handles fit without shifting their centers. Initial selection clips to these bounds; live edits clamp to them; valid legacy presets fit into them on activation; capture rejects out-of-bounds regions. Overlays and the full-screen selector override `constrainFrameRect` because shared geometry already owns positioning. Without this, AppKit can move UI separately from the source crop near the menu bar. The capture-coordinate origin remains the full screen's top-left, not the visible area's origin.

## Capture lifecycle

Controls serialize user starts/stops via `busy`. Start first invalidates old rendering and stops the old stream; it validates the display and crop, excludes the current process ID from the content filter, creates the cropped stream, and starts it. The output remains concealed until start succeeds. A source change reuses the existing mirror NSWindow but currently creates a fresh stream. Seamless `updateConfiguration` / `updateContentFilter` is future work.

Live outline edits stay on one display and use `SCStream.updateConfiguration`, retaining the existing stream/filter and output window. The model coalesces pending edits to the newest region and applies one update at a time, with a 33 ms interval before each application. Stop, new sessions, and display changes cancel/invalidate the drain. Presets cannot be saved while edits are pending. Escape queues the initial region again. Output aspect ratio/dimensions and the chosen (or custom) mirror pixel scale follow region changes. Normal clicks pass through the border; only eight 14-point handle windows and a drag-label window intercept input. The label sits outside the crop when space permits. Handles can be hidden independently of the border.

Screen callbacks arrive on a serial queue. Accept only valid complete screen frames. A lock protects one pending main-queue frame, an enabled flag, and a generation token. Stop invalidates already queued frames. A crop update also invalidates queued callbacks but retains the last displayed cropped frame until the updated stream produces a complete one; do not flush/disable all incoming frames around an update, because an unchanged desktop may then remain blank while ScreenCaptureKit emits idle frames. No update clears the source rectangle or switches to full-display capture. Main-thread rendering additionally checks concealment, so pending frames cannot reveal output while hidden. Layer frame changes and concealment disable implicit animation.

Unexpected stream failure disables output and notifies the main-actor model only if the failing stream is still current. On display configuration change, stop and require reselection rather than assume the old crop is still safe. A revision token invalidates a pending start on display changes; its output stays concealed and the stream is stopped when the pending start completes. Validate this on real hardware in T006.

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
