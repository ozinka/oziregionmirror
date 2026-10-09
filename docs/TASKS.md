# Task board

Statuses: `implemented` means code exists and automated validation passed; `accepted` additionally requires relevant manual evidence. `todo` tasks have not been implemented. Estimates are relative size (S/M/L), not hours.

| ID | Task | Status | Size | Suggested model | Depends on |
| --- | --- | --- | --- | --- | --- |
| T001 | Repository, package, local app bundle and docs | implemented | S | Sol | — |
| T002 | Geometry/presets model and tests | implemented | S | Luna | T001 |
| T003 | Drag selection, per-display overlays and outline | implemented | M | Sol | T002 |
| T004 | Cropped ScreenCaptureKit capture and mirror rendering | implemented | L | Sol/Astra | T003 |
| T005 | Hide/stop/menu controls and saved regions | implemented | M | Luna/Sol | T004 |
| T006 | Manual acceptance, lifecycle and permission hardening | partial — permission guidance implemented; manual acceptance next | M | Sol | T005 |
| T016 | Image clarity diagnosis and pixel-aware mirror sizing | sizing implemented; manual quality checks pending | M | Sol | T005 |
| T007 | Seamless source updates and draggable/resizable region | same-display editing implemented; manual checks pending | L | Sol | T006 |
| T017 | Compact presenting controls and unobtrusive mirror experiment | todo | M | Sol | T007 |
| T008 | Fixed-size region presets and quality preferences | todo | S | Luna | T006 |
| T009 | Persistent display identity, preset rename/update/migration | todo | M | Luna/Sol | T006 |
| T010 | Custom global preset and hide shortcuts | todo | M | Sol | T009 |
| T011 | Presenter preview | todo | S | Luna | T006 |
| T012 | Output annotations: arrows/text/pen, undo and clear | todo | L | Sol | T007 |
| T013 | Whiteboard mode and PNG export | todo | M | Luna/Sol | T012 |
| T014 | Zoom loupe and optional visual blur | todo | M | Sol | T012 |
| T015 | Daily-use acceptance and performance tuning | todo | M | Sol | T007–T011 |
| T018 | Original macOS application icon | accepted | S | Luna | T001 |

## T018 — Application icon

Implemented 2026-10-09: original dashed selection and gradient mirror artwork, rendered at all standard macOS icon sizes in `Resources/AppIcon.icns`. The bundle declares and copies the icon before signing. Editable source is `scripts/generate-icon.swift`; regenerate from the repository root with `swift -module-cache-path .build/swift-cache scripts/generate-icon.swift`, then `iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns`. Preview visually checked; release bundle, plist and signature validated. Follow-up: user reported no Dock icon. Launch now explicitly sets `NSApp.applicationIconImage` from the bundled ICNS, and the plist names the full icon filename. AppKit successfully decoded ten representations; release build, plist and signature checks passed. The user confirmed the Dock icon appears after relaunch on 2026-10-09. The icon is assigned exactly once during launch; no timers, delayed callbacks or periodic refresh. Menu-bar template symbol stays unchanged.

## Implemented task criteria

T001: clean local build scripts, no external package dependencies, stable `.app` bundle, English docs and session instructions.

T002: selection-coordinate conversion, screen-edge clipping, finite/bounds validation, Retina output cap, and preset round-trip tests.

T003: select on any screen, minimum size 32×32, Escape cancels, visible click-through outline, no overlay remains after stop.

T004: crop using logical points, process exclusion, 30 fps target, bounded queue, aspect-fit rendering, late-frame invalidation. Basic operation and Teams transmission are user-confirmed; detailed crop, concealment and multi-display acceptance remain pending.

T005: control/menu windows, opaque Hide/Resume, blank Stop/error, ten named regions with local persistence, same mirror-window identity across source starts. Manual acceptance is outstanding.

## T006 — Manual acceptance and hardening (next)

2026-10-08 permission fix: user reported stale enabled Screen Recording access after an ad-hoc rebuild. Verified current designated requirement uses cdhash. Implemented permission-specific recovery guidance and configurable existing-certificate signing via OZI_SIGNING_IDENTITY. No privacy settings, certificate stores, or TCC records were changed. Manual permission renewal and stability across certificate-signed rebuilds remain pending.

Read `TESTING.md`, `ARCHITECTURE.md`, and the app sources. Run the packaged app and record observations. Verify overlay keyboard focus (borderless SelectionWindow already overrides canBecomeKey), permission denied/granted/relaunch, complete frames, display-coordinate orientation, stable Teams window sharing, no recursion, and hide/stop output.

Verify the existing display-change revision guard and harden cancellation/shutdown during async start if needed; controls must not silently ignore safety events while busy. Confirm errors cannot leave old pixels visible. Handle unavailable/revoked permission without an infinite retry. Verify sample presentation timing and first-frame behavior. Fix only reproduced defects or clear lifecycle races; add focused tests where logic can be isolated.

Acceptance: all critical manual checks have recorded results, start/stop/source changes cannot race into stale output, denied permission is recoverable, and a Teams participant confirms correct crop/hide/stop. If a call is unavailable, leave its gate pending rather than declare acceptance. Use Sol; escalate to Astra after two failed investigations of a capture/concurrency bug.

## T007 — Seamless region updates

2026-10-09 bug fix: capture was allowed under the menu bar while AppKit could relocate border/handle windows. Centralized bounds now exclude the menu bar/Dock plus a 7-point margin for handles; selection, movement, resizing, preset fitting and capture validation agree. Border/selector/handle windows no longer accept independent AppKit frame constraints. Twenty-two unit tests and four native geometry checks passed. Real capture/Teams revalidation remains pending.

Implemented on 2026-10-08: dashed click-through outline, eight small edge/corner input windows, a separate drag label, Escape restores drag-start geometry, minimum 32-point dimensions, screen clamping, Controls/menu editing toggle, serialized latest-position updates at approximately 30 Hz, and `SCStream.updateConfiguration` on the existing stream. Preserve the mirror window, selected/custom pixel scale, and Hide state. Stop/error/display changes invalidate pending edits. Save is disabled until pending edits settle. Seventeen unit tests passed; native drag/keyboard/Teams behavior still needs manual acceptance. Cross-display editing/filter transitions remain deferred; choosing another source display still starts a new stream.

Use `updateConfiguration` for same-display crop changes and `updateContentFilter` for display changes. Conceal output during unsafe transitions. Add a separate edit mode to move/resize the crop; ordinary outline remains click-through. Clamp at display bounds and preserve mirror-window identity. Acceptance: adjustments during an active Teams share need no re-share, and no full-display frame is exposed between crops. Sol recommended.

Reference interaction observed in user-provided screenshots (2026-10-08): dashed outline, eight corner/edge handles, a top drag label, and a compact toolbar below the region. Implement original controls for moving and resizing live. Use input windows only around handles/drag affordances, or an explicit edit mode; do not let a transparent full-region window swallow clicks intended for other apps. Serialize/coalesce rapid crop updates so old drag positions cannot win over the final position. Keep own overlays excluded, retain the chosen mirror pixel scale when crop dimensions change, and show the effective scale if the window must fit. Test all eight handles, minimum size, screen edges, cancellation, and a Teams share during changes. Start with same-display editing; cross-display transitions can follow after validation.

## T017 — Compact presentation workflow

The user's screenshots show menu-bar commands for stopping, saving/managing presets, a presenter preview, and hiding the outline/toolbar. The user reports no visible mirror. This demonstrates the visible UX, but does not establish how the reference maintains the shareable output or hides it.

Move routine actions into the menu bar and a small optional toolbar outside the capture area: stop, hide/resume output, edit region, and mirror scale. Keep full Controls available for setup/presets. Add a reversible Show Mirror action. Investigate whether an unminimized mirror behind other windows or off-screen remains selectable and updating in the user's Teams capture mode. Preserve 1:1 backing dimensions and retain the visible-mirror fallback. Do not equate a transparent outline with capture of underlying apps, and do not promise alpha-zero/orderOut/minimized capture without measurement. Avoid OS private APIs or weakening permissions.

Acceptance: normal desktop clicks still work, toolbar/outline never enter source capture, the mirror can be restored, and a colleague confirms output remains live at the intended resolution while the mirror is unobtrusive. No proprietary assets or exact icon designs should be copied. Implement compact controls separately from the hidden-output experiment so the useful UI can ship even if that experiment fails.

## T016 — Clarity diagnosis and mirror sizing

The user confirmed Teams transmission but reported poor colleague-visible quality after resizing the mirror. Do not assume the network or resizing is solely responsible. The original fixed 960×540-point window could downsample a larger source before Teams encodes it. On 2026-10-08, percentage sizing replaced that fixed capture-start size.

Implemented: start at 100%; Controls and menu actions for 100%/75%/50%; backing-coordinate conversion on the mirror display; aspect ratio based on captured pixels; proportional fit notice for oversized requests; capture/mirror pixel dimensions and actual scale; layer backing-scale updates; reapplication on display moves; custom-size diagnostics. Ten unit tests pass, including five sizing tests. No new Teams A/B or mixed-DPI manual validation has been performed. Optional size locking remains deferred.

Inspect source pixels, capture output pixels, mirror content backing dimensions, layer contentsScale, and Teams sent/received dimensions. Add a Natural Size / 1:1 action based on capture pixels and the mirror display's backing coordinate conversion; handle display moves and output caps. Set rendering layers' backing scale correctly. If the natural size does not fit, clearly indicate downscaling rather than silently claiming 1:1. Keep aspect ratio and provide optional size locking. Diagnostics must show metadata only, never save captured pixels automatically.

Acceptance: sharp local static text relative to the source, verified pixel mapping on Retina and non-Retina displays, no unintended intermediate downsample in natural-size mode, and an A/B Teams call against direct source-window sharing. Record remaining Teams compression separately; do not promise lossless transmission. Sol recommended for rendering changes.

## T008 — Sizing and quality settings

Add centered 16:9 size presets (e.g. 1280×720 logical points when they fit), 15/30 fps, and output cap choices 1920/2560/3840 pixels. Persist metadata only. Acceptance: reject oversize presets, retain aspect ratio, output dimensions and FPS update as selected. Test sizing policy. Luna recommended after T006.

## T009 — Preset maintenance and display identity

Store persistent display UUID alongside old ID, migrate v1 JSON without loss, support rename/update/delete and unavailable-display indication. Never apply a missing display's crop to another display. Acceptance: tests cover v1 migration, invalid data, duplicate names policy, missing/reconnected display and resizing. Luna for model/UI, Sol for display mapping.

## T010 — Global shortcuts

Register configurable shortcuts for preset start and Hide/Resume; report conflicts and unregister cleanly. Prefer native registration without Accessibility permission; document limitations of the chosen API. Acceptance: work while Teams/another app has focus, do not swallow unrelated input, and persist bindings. Sol recommended for API choice; Luna can implement a settled settings UI.

## T011 — Presenter preview

Add a compact optional preview without a second capture stream. Preserve self exclusion and avoid accumulating buffers if either window is hidden. Acceptance: identical crop/conceal state in both outputs; closing preview leaves sharing running. Luna after renderer interface is settled.

## T012 — Annotations

Create output-local vector models for arrows/text/pen with undo/redo and clear. Input must occur in a deliberate editing mode, never block normal desktop work. Composite into mirror output (our app windows are excluded from source). Acceptance: markup appears in Teams at correct normalized positions on resize, clears reliably, and does not reveal concealed video. Sol recommended for compositing design.

## T013 — Whiteboard

Use annotation models on a solid board. Switch within the same mirror window; preserve capture and board states; export via user-selected PNG destination only. Acceptance: undo/clear/mode switching work and exported pixels match board. Luna for bounded implementation after T012.

## T014 — Loupe/blur

Magnify a crop of the source within composited output; avoid recursive loupe sampling. Optional blur must not replace the opaque privacy mode. Acceptance: magnification stays in bounds and coordinates remain correct at different output scales; concealment overrides all layers. Sol recommended.

## T015 — Performance and daily-use release

Run the 30-minute test, record CPU/memory/frame responsiveness and monitor configuration, verify reconnect/sleep/Spaces/Teams behavior. Optimize measured bottlenecks only. Acceptance: bounded memory, no stale-pixel failures, stable target cadence for code/slides, completed daily-use checklist. No full-feature claim until presentation tools are accepted.
