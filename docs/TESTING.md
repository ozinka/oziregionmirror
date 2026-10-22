# Validation

## Automated

```sh
bash scripts/check.sh
bash scripts/build-app.sh
codesign --verify --deep --strict build/OziRegionMirror.app
plutil -lint Resources/Info.plist
```

Geometry tests cover bottom-left to top-left conversion, edge clipping, invalid/out-of-display rectangles, bounded even Retina output, and preset JSON round-trip. They do not prove ScreenCaptureKit's output coordinates or Teams compatibility.

## Critical manual checks (record completed evidence below)

| Check | Procedure | Expected |
| --- | --- | --- |
| Permission | Start without permission; deny; grant in Settings; relaunch | Clear actionable message; no stale image; capture after permission |
| Selection | Draw in every drag direction; select edge crop; Escape on each display | Correct crop; tiny selection ignored; Escape removes all overlays |
| Retina | Place distinct labels at four crop corners on Retina and non-Retina | Correct orientation and bounds, readable text |
| Displays | Repeat on displays above/left of primary and mixed scaling | No primary-screen offset or scale error |
| Recursion | Move output and Controls into selected region | Neither appears recursively; ordinary desktop content remains |
| Teams | Share mirror in a real call, confirm from another participant | Stable correct crop and useful readability |
| Source change | Select a different region/preset during Teams sharing | Same output window; short blank transition; no full-screen flash |
| Live editing | Drag label and all eight handles; cross minimum size/screen edges; Escape mid-drag | Region clamps safely, Escape restores initial geometry, stream stays active, last drag position wins |
| Click-through | Click/type in apps inside outline; hide/show editing handles | Border never swallows interior input; only label/handles intercept input |
| Controls access | Cover, close or minimize Controls; focus another app; click green move label; drag it and press Escape | Click restores/raises Controls without moving crop; drag does not raise Controls; Escape restores geometry and does not raise Controls; ordinary interior clicks pass through |
| Update races | Resize quickly, hide/resume, then Stop; select a new region or disconnect display during updates | No pending edit resurrects capture or reveals hidden pixels; final applied crop matches outline |
| Mirror size | Start capture, choose 100%/75%/50%; resize manually; restore 100% | Starts parked at capture-pixel 1:1; actual dimensions/scale update; oversized output is not silently downsampled |
| Parked output | Start dynamic content, Show Mirror, select it in Teams, Park Mirror; repeat Show/Park and close the visible mirror | Same window remains shareable and updating at the receiver; parking clears desktop, closing parks; Hide View still blanks audience output |
| Parked lifecycle | Park, resize source, Show/Park repeatedly, reopen from Dock, Stop, restart, unplug display, sleep/wake | No visible output resurfaces unexpectedly; Show restores a reachable title bar; stop/error/display change clears pixels; reopened app shows Controls; confirm backing dimensions on each display scale |
| Mirror DPI | Move mirror between Retina/non-Retina displays with a percentage selected | Percentage is reapplied using destination backing coordinates; no silent downsample claim |
| Hide | Hide with changing sensitive text behind crop, then resume | Solid output while hidden; current frames after resume |
| Stop/error | Stop while source changes; provoke display removal | Output clears immediately and stays clear |
| Presets | Save, quit/relaunch, restore; disconnect saved display | Correct restoration or explicit rejection; no wrong-display fallback |
| Window state | Minimize/occlude mirror; switch Spaces/full-screen apps | Record meeting behavior; keep visible if updates stop |
| Rebuild | Rebuild and launch at same path | Record whether TCC asks again |
| Lifecycle | Repeated start/stop; unplug during starting; quit during starting | No late frame or stream resurrects after stop/change |

If unavailable, record a check as pending with the missing hardware/call prerequisite. Never grant macOS privacy access on the user's behalf without an explicit user instruction.

## Daily-use release gate

After critical checks, run a 30-minute Teams session with code scrolling, app switching, crop updates, hide/resume, and display sleep/wake. Record Mac model, OS version, display logical/physical resolution and scaling, Teams version, output settings, approximate CPU/memory at start/end, and observed latency. Compare at least 1920 and 3840 output caps after settings exist. Check that frame work/memory does not grow unbounded.

## Evidence log

2026-10-22 (Controls access): 32 unit tests and signed release build passed. Native event diagnostic using actual RegionHandleView source passed label click activation with no crop edit, drag without Controls activation, Escape followed by mouse-up suppressing activation, and resize-handle clicks not activating Controls. Diagnostic did not capture screen pixels, move the physical cursor or change preferences. Physical clicks with inactive app, covered/closed/minimized Controls, and Teams picker behavior remain pending. No claim that Controls is excluded from capture or sharing pickers. Apple references: [legacy sharingType.none](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none), [picker window exclusions](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpickerconfiguration-swift.struct/excludedwindowids).

2026-10-22 (remove overlay): user reported the transparent output-over-source experiment does not work; removed its implementation and all controls. Thirty-two tests, signed release build and updated native parking checks passed: initially unordered off-screen start, opaque ordered output, backing dimensions, oversized restoration and stable identity through repeated Show/Park. No screen capture or preference writes. Actual Teams and mixed-DPI checks remain pending.

2026-10-22 (startup correction): user reported parking appears to work but the startup window still appears. Startup now moves the concealed output off-screen before ordering it and before awaiting capture/permission. Thirty-two tests and signed release build passed. Updated native diagnostic passed for a previously unordered window parking directly off-screen and overlay restoration with presentation disabled remaining unordered. Actual capture-start/permission-wait/preset-replacement visual regression remains pending; verify no output appears until explicit Show Mirror, including when replacing a visible mirror and when capture permission fails.

2026-10-22 (off-screen output): 32 unit tests passed, including four placement tests covering a monitor below the primary, negative origins, oversized output, display ordering and invalid geometry. Signed release build passed. Native diagnostic using actual MirrorWindow source and a live WindowServer connection passed: opaque ordered/unminimized parking outside every attached display, unchanged backing dimensions on the current 1x display, 3840x2160 content sizing beyond desktop height, reachable restoration without frame-size reduction, stable window number, exclusive overlay transitions and restore/order-out state. Diagnostic source is in ignored `build/parked-mirror-check.swift`; it performed no capture or preference writes. Actual app capture, Teams picker/receiver, mixed-DPI, focus/Spaces, sleep and display-removal checks remain pending.

2026-10-09 (retired overlay prototype): native geometry/opacity/identity checks passed at the time, but this did not establish capture or Teams interoperability. User rejected the experiment as nonworking and requested complete removal on 2026-10-22. Its code, controls and manual acceptance procedure have been removed.

2026-10-09 (Dock and Controls layout): release build and signature validation passed. A temporary native diagnostic rendered the actual ControlsView with five fixture presets, live diagnostics and a fit notice: natural content height 697 points, within the 760-point cap. Standard accessory→regular→accessory activation-policy switches succeeded. The diagnostic did not start capture or change saved preferences. Manual pending: actual menu toggle during a Teams share, Controls reopening while Dock-hidden, persisted choice after relaunch, resize on save/delete, and long-name/unavailable-display/ten-entry/small-display overflow cases.

2026-10-09 (Controls and sizing): 28 unit tests pass, including six new tests for all-handle ratio limits (16:9/4:3/1:1), opposite anchors, Retina exact sizing, invalid/oversized sizes and zero-delta current-ratio stability. Release/plist/signature checks passed. Manual pending: confirm removed text, saved dimensions/unavailable-display labels, all ten entries reachable by scrolling, standard output pixel dimensions, disabled oversized entries, ratio changes during capture, all handles and Escape with lock, reset to Free on new region/preset/standard size, and uninterrupted Teams sharing. Ratio rounding can change captured proportions slightly because output dimensions must be even.

2026-10-09 (repository checkpoint): reran all 22 unit tests with zero failures, built the complete release app, and passed plist/signature validation before the user-requested full local commit. Generated build products remain ignored. Pending manual gates below are unchanged.

2026-10-09 (app icon — accepted): original ICNS bundled and declared in Info.plist; AppKit decoded all ten representations. The user confirmed the icon appears in Dock after the launch-time assignment fix. `NSApp.applicationIconImage` is assigned once at launch; no timer or repeated refresh. Release build, plist and signature validation passed.

2026-10-09 (menu-bar alignment fix): user screenshots confirmed the source crop could include menu content while the outline remained below it. Native diagnostic showed the default frame constraint shifts top-edge windows by 31 points on this display. Shared usable bounds and overlay constraint override added. Twenty-two unit tests pass, including nonzero display origins, menu/Dock offsets, bottom-edge shrinking to 32 points, all-handle limits and legacy preset fitting. A separate native check using actual RegionOutline source passed at heights 400/100/64/32: border matches intended crop frame, eight handles exist within visible bounds, bottom marker stays on the bottom edge. This check did not capture screen pixels or test Teams. Manual regression: resize bottom edge upward with the top at the usable limit, then verify mirror excludes menu text and matches the outline.

2026-10-08 (live region editing): seventeen unit tests passed, including all eight handle calculations, movement, bounds/minimum size, zero-delta restoration, and latest-request coalescing. Release build, plist validation, and codesign verification passed. Native mouse/keyboard behavior, static frames after updates, full Teams behavior, and click-through checks remain pending. Release includes the permission-recovery source changes; ad-hoc rebuild may require access renewal.

2026-10-08 (permission regression): user reports capture denied after rebuild while System Settings shows access enabled. Inspected release signature is ad-hoc with a cdhash designated requirement. Certificate inventory returned zero valid identities. Permission-specific error guidance and signing configuration added to source; the current release binary was not rebuilt during this fix. User must perform permission renewal; no TCC/Keychain mutation or permission-flow success has been claimed.

2026-10-08 (percentage sizing): ten unit tests passed, including natural Retina sizing, 75%/50% dimensions, screen fitting on a lower-density display, custom-size scale, and small-region sizing. Percentage UI and corrected Teams quality require manual validation after relaunch.

2026-10-08 (Teams user report): a short call with a colleague confirmed transmission, but the colleague reported poor image quality. Mirror resizing occurred. Resolution, source/mirror display scales, received dimensions, and static versus scrolling quality were not recorded. Next: compare direct source-window sharing against the mirror in the same call; test natural-size mirror and record Teams sent/received screen-share dimensions.

2026-10-08 (user feedback): the user confirms the prototype works on their Mac and has remaining questions. Exact scenarios were not specified; this confirms general usability but does not mark individual acceptance checks as passed.

2026-10-08: release build, five unit tests (zero failures), plist validation, and ad-hoc codesign verification passed on arm64/macOS 26.7.1. Sandbox-only launch failed; launching outside the shell sandbox succeeded. Accessibility observation confirmed the app menu, Controls, and mirror window. Controls reported a live 1635×807-point capture after local interaction; this is not pixel/call validation. No permission-flow test, actual captured pixel accuracy, multi-display run, or Teams call has been observed. Future manual results should be short dated entries here with pass/fail/pending and reproduction details.
