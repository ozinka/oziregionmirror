# RegionMirror native implementation investigation

Date: 2026-10-22. Task: T017 research. No application implementation change.

## Result

Static native analysis establishes an off-screen output-window implementation in RegionMirror 1.5.1 (38), beyond the earlier diagnostic-string evidence. The program keeps an opaque, ordered window, moves it below the primary display without changing its frame size, and continues assigning captured images independently of its hidden-window flag. A separate window provides the optional Presenter View.

These are findings about executable code paths, not observations of a live RegionMirror session or successful Teams reception. No RegionMirror windows were present during a read-only WindowServer inventory. Picker discovery, actual rendering cadence, backing scale after parking, receiver quality, sleep and multiple displays remain unverified.

## Target and tools

- Source: `/Applications/RegionMirror.app`, version 1.5.1, build 38.
- Universal executable SHA-256: `a729038e77525ea237a30d81df56eb6207465f6570fe239d00680a6a13833333`.
- Extracted ARM64 slice SHA-256: `96f7e77ee9059080ab4f716fe1b977261eb0b5d469480d949eef0d30e3e2a073`.
- REA 6.7.0, installed from the official `rea-agents` npm package with install scripts disabled.
- Node.js 24.11.1 ARM64, downloaded from nodejs.org; archive checksum matched its published checksum file.
- Ghidra 12.1.4 from the official NSA GitHub release. Archive SHA-256 matched `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`.
- Built the supplied decompiler sources for `mac_arm_64` using `make ghidra_opt ARCH_TYPE="-arch arm64" OSDIR=mac_arm_64`. Existing Homebrew OpenJDK 27 was reused.
- `rea doctor --provider ghidra --json` passed all nine scoped checks. Default Ghidra auto-analysis completed; no analyzer was disabled.
- Cross-checked relevant ARM64 instructions and Objective-C metadata with the installed Xcode utilities. Decompiler signatures and Swift floating-point arguments are imperfect; geometry conclusions below were checked against the instructions, not inferred from pseudocode parameter names.

Tools are installed locally in ignored `build/research-tools/`; they are development tools, not application dependencies. No global agent registration, system Node replacement, paid tool, or application bundle modification was needed. REA's runtime analysis helper uses temporary directories. The analysis session was closed and reported `open: false`, `cleanup_pending: false`.

## Off-screen placement

| Evidence | Address in ARM64 slice | Finding |
| --- | --- | --- |
| `OffScreenCapableWindow.constrainFrameRect:toScreen:` | `0x100017b5c` | A single `ret` instruction preserves the incoming rectangle. AppKit's normal frame constraint is bypassed. |
| Parking routine | `0x100020228` | Looks through `NSScreen.screens` for frame origin `(0, 0)`, then falls back to `NSScreen.main`. |
| Parking geometry and attributes | `0x1000203ac`–`0x100020458` | Preserves the current frame width and height; sets `x = screen.frame.minX`, `y = screen.frame.minY - window.frame.height - 50`; normal window level, movable, no shadow, `setFrame(..., display: false)`, alpha `1`; sets `isWindowHidden`. |
| No-screen fallback | `0x100020544` | Calls `setFrameOrigin` with `(-5000, -5000)` and sets the hidden flag. |
| Capture-start path | `0x100018ec0`; placement call at `0x10001976c` | Sizes the window, calls `makeKeyAndOrderFront`, then calls the parking routine. |
| Close-button delegate | `0x10001ed24` | Parks the window and returns false from `windowShouldClose:`. Closing does not destroy this output window on this path. |
| Geometry/style updates | `0x100022ff4`, `0x10001a3ec` | Reapply parking after changing geometry or presentation when `isWindowHidden` is set. |

The inspected parking routine does not call `orderOut`, minimize the window, lower alpha to zero, or stop the capture stream. Keeping it ordered and opaque is an inference about the intended sharing workflow supported by the explicit calls above; actual picker enumeration was not measured.

Coordinates here are AppKit desktop coordinates, with a bottom-left origin. They are not our display-local top-left capture coordinates. Parking output must not change the source crop.

Important limitation: the routine does not compute the union of all display frames or test the destination against every display. A secondary screen below the primary can potentially overlap the parked frame. That is a geometry risk inferred from the code, not a reproduced RegionMirror defect. The fixed fallback is also not a universal nonintersection guarantee.

## Frame delivery and optional preview

The sample-buffer callback at `0x100015a40` delegates to `0x10001653c`. For screen samples, that path converts the pixel buffer through `CIImage`/`CIContext` to a `CGImage`, creates an `NSImage`/`NSBitmapImageRep`, and forwards it to the capture delegate.

The delegate path at `0x10001b200` applies a `1/60` second time gate and schedules a main-queue update through `0x100020e98` to `0x10001b51c`. This is a configured throttle, not a measured 60 fps result. The inspected main-queue body checks `isCapturing`, then updates `mirrorView.image`; it does not gate that assignment on `isWindowHidden` or window occlusion. It also forwards the image to `sharedRegionWindow` when present. This explains how the implementation intends to feed the parked output independently of the preview; it does not prove WindowServer or Teams receives every image.

`AppDelegate.togglePresenterView` reaches `0x10008f658`, which toggles `SharedRegionWindow` using `windowIsVisible`. The menu title explicitly changes between Show Presenter View and Hide Presenter View. This is distinct from parking `MirrorWindowController.window`. Method names such as `showSharedRegion` should not be mistaken for proof that this auxiliary window is the primary shared output.

Useful rendering evidence:

- Mirror construction at `0x100017f5c` enables a layer-backed opaque content view and sets its contents scale from the main screen, falling back to 2. It disables layer rasterization and asynchronous drawing.
- Mirror-view setup at `0x1000181fc` sets both minification and magnification filters to `kCAFilterNearest`, disables additional rasterization and edge antialiasing, and configures an `NSImageView` with edge constraints.
- Sizing at `0x10001fc94` derives window dimensions from the supplied region and optional title-bar height. The inspected sizing routine contains no desktop-fit reduction.

These are comparison candidates, not evidence that RegionMirror has better quality or performance. Nearest filtering can make noninteger scaling jagged; it cannot recover pixels already lost. Our `AVSampleBufferDisplayLayer` path also avoids the per-frame image conversion seen here, so replacing our rendering architecture is not justified by these findings.

## Implications for OziRegionMirror

The next bounded implementation candidate is a reversible off-screen presentation mode on the existing stable mirror window, followed by actual Teams acceptance. It can use public AppKit APIs and does not require REA at runtime.

1. Preserve output-window identity and intended backing-pixel dimensions. Keep a visible-output fallback; do not use desktop-fit shrinking to make the output unobtrusive.
2. Add an explicit parked presentation state and bypass AppKit frame constraints only as needed for that state. Position outside the union of connected display frames, with an explicit nonintersection check.
3. Keep the output ordered, unminimized and opaque while parked. Restore a valid visible frame on request. Recheck backing scale after movement; reference frame size alone does not guarantee physical-pixel size.
4. Recompute or restore placement on display changes, focus/reopen and output resizing. Preserve existing immediate concealment on stop/error and the entire-process source exclusion.
5. Keep privacy concealment separate: our Hide View must still clear/cover outgoing content. Parking merely removes the output from the working desktop.
6. Treat any small local preview as independent of output dimensions. A second preview window is optional; it is not required to test parking.

Acceptance remains dynamic content in the Teams receiver, picker discovery before and after parking, stable window identity, fine-text comparison at equal backing dimensions, restore/focus behavior, resize, sleep and multiple displays. No architecture decision or manual acceptance is made by this research.

## Local evidence and reuse

The ignored `build/regionmirror-research/` directory contains the ARM64 analysis copy, 34-record REA Evidence export (`evidence.json`), immutable analysis snapshot (`analysis-snapshot.json`), individual tool responses, Xcode disassembly/metadata, scoped doctor result and read-only window inventory. No screen images or video were saved. Binary and decompiler artifacts remain local and untracked; this document records findings rather than copying proprietary implementation into our source.

Important response files: `park-window.json`, `constrain-frame.json`, `window-should-close.json`, `start-capture.json`, `mirror-constructor.json`, `register-notifications.json`, `frame-delivery-body.json`, `frame-render-body.json`, `toggle-presenter-body.json`. REA normalized addresses in this report are tied to the ARM64 digest above.

Run the installed CLI from the repository root:

```bash
bash build/research-tools/rea --version
bash build/research-tools/rea doctor --provider ghidra --json
bash build/research-tools/rea function "$PWD/build/regionmirror-research/RegionMirror-arm64" 0x100020228 --provider ghidra --snapshot "$PWD/build/regionmirror-research/analysis-snapshot.json" --format json
```

The tools and raw evidence are intentionally outside the tracked source tree and will be removed if `build/` is deleted. REA does not need to be registered with an agent to use these CLI commands.

## Tool references

- [REA native analysis](https://github.com/morluto/rea/blob/main/docs/native-investigation.md)
- [REA Ghidra setup and ARM64 build instructions](https://github.com/morluto/rea/blob/main/docs/installation.md#ghidra)
- [Ghidra 12.1.4 release and archive checksum](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build)
- [Node.js 24.11.1 checksums](https://nodejs.org/dist/v24.11.1/SHASUMS256.txt)
