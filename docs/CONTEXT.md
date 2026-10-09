# Current handoff

Updated: 2026-10-09. Read this first, then one task in `TASKS.md`.

## Goal and constraints

Local native macOS screen-region mirror for Teams on a large display. English code/UI/docs; chat in the user’s Ukrainian or English. No runtime AI, backend, analytics, external dependencies, or paid distribution. Original implementation inspired by public RegionMirror workflows/screenshots. Economical serial development; no subagents by default. Existing MIT license retained. Local commits only when requested by the user; no push without explicit authorization.

## Current implementation

T001–T005: Swift package, testable RegionCore, per-display selection, ScreenCaptureKit cropped stream, AVSampleBufferDisplayLayer mirror, menu bar/Controls, opaque Hide/Stop, ten saved regions. Own process is excluded, including dynamically created handles/overlays. One stable mirror window persists.

T016: start at 100%; Controls/menu 100%/75%/50%; Retina-aware backing-coordinate sizing; actual pixel/scale diagnostics; oversized-fit notice. Root/video layers follow display backing scale. Custom resizing stays available.

T007: dashed click-through border, eight resize handles, separate drag label, Escape restores drag-start geometry; clamp to the current display/minimum 32 points. Handles can be hidden in Controls/menu (Command-E). Model coalesces latest edits, serially applies `SCStream.updateConfiguration` with a 33 ms interval, preserves Hide state and chosen/custom mirror scale. Save waits for edits to settle. Stop/error/new session/display changes invalidate pending edits. Crop updates retain the last cropped frame until new complete frames arrive; no full-display transition. Cross-display dragging is deferred. Selecting a new region/preset still briefly restarts capture.

Build: `bash scripts/build-app.sh`; test: `bash scripts/check.sh`; launch: `open build/OziRegionMirror.app`. Bundle ID `local.ozi.regionmirror`; UserDefaults key `regionPresets.v1`. Launch packaged app rather than `swift run`. Running old instances require Quit/relaunch.

T018: original app icon bundled as `Resources/AppIcon.icns`; editable AppKit vector source in `scripts/generate-icon.swift` (regeneration instructions in `TASKS.md`). Release bundle, plist and signature validated; artwork preview checked. Dock icon is now explicitly loaded from the bundled ICNS at launch after the user reported it missing. AppKit decoded all ten icon representations; release/plist/signature checks passed. The user confirmed the Dock icon appears after relaunch. It is set once during application launch through `NSApp.applicationIconImage`; no timer, delay or repeated refresh. T018 accepted. Menu-bar symbol unchanged.

## Boundary regression fixed (2026-10-09)

The user reproduced capture entering the menu bar while the outline/handles shifted below it. All geometry now shares `visibleFrame` minus a 7-point handle margin: initial selection, live editing, legacy preset fitting and capture validation. Menu bar and Dock are excluded. Overlay/selector windows override `constrainFrameRect` to avoid independent AppKit relocation. Twenty-two unit tests and native window-frame checks at heights 400/100/64/32 passed. New actual capture/Teams verification remains pending.

## Permission issue

User reported denied capture after rebuild even though Settings showed permission enabled. Ad-hoc designated requirement is tied to the executable cdhash. No valid certificate identities were returned by a read-only inventory. Source now gives permission-specific renewal guidance; build accepts `OZI_SIGNING_IDENTITY` for an existing Apple Development/Developer ID certificate. Ad-hoc remains default. Renew this app’s permission manually after rebuild as needed; never silently reset TCC, modify Keychain, or weaken requirements to identifier-only. The current release now includes the recovery changes. Actual successful renewal remains unconfirmed.

## Validation and next work

Twenty-two unit tests, release build, plist and codesign checks pass on Apple silicon/macOS 26.7.1. User confirmed basic operation and a real Teams call, but colleague reported poor quality after mirror resizing. Corrected 1:1 sizing has not been revalidated in Teams. New native live-drag, Escape, click-through, static-frame update, stop/update race, mixed-DPI, and display-removal behavior remain manual checks in `TESTING.md`; do not claim acceptance yet.

Next: T007 manual editing checks and T016 Teams A/B quality validation; renew permission if required after rebuilding; T006 lifecycle hardening remains open. User screenshots show an editable outline/compact toolbar/menu workflow and no visible mirror; they do not establish the reference’s hidden-output mechanism. T017 covers compact controls and a separately validated unobtrusive-mirror experiment. No hidden output is implemented yet.

## Key contracts and model routing

CaptureRegion stores display-local top-left logical points; flip AppKit’s local bottom-left coordinates once. Output is even physical pixels, capped at 3840 longest side, 30 fps target. One pending render callback; generations invalidate old work. Other apps/notifications inside crop are visible; Teams owns its share state and may buffer frames. Presets use transient display IDs and reject missing/stale geometry.

Use Sol for capture/T006/T007; Luna High for bounded UI/settings/preset/docs tasks. Astra only for unresolved deep defects after two attempts. See `AI_WORKFLOW.md`. Deferred: compact toolbar/unobtrusive mirror, persistent display UUIDs, global shortcuts, annotations, whiteboard/export, loupe/optional blur.
