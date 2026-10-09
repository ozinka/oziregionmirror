# OziRegionMirror

A local macOS app that mirrors a selected rectangular screen region into an ordinary window for sharing in Microsoft Teams and other meeting apps.

Independent implementation inspired by the public workflow at [RegionMirror](https://regionmirror.com/). No proprietary code or assets are used. The existing MIT license is retained.

## Requirements and build

- macOS 13 or later; currently compiled on Apple silicon with macOS 26.7.1 and Swift 6.3.3.
- Xcode or Command Line Tools with Swift 5.9 or later.
- No third-party dependencies, package downloads, server, or API key.

```sh
bash scripts/check.sh
bash scripts/build-app.sh
open build/OziRegionMirror.app
```

The app is ad-hoc signed for local use by default. Launch the `.app`, rather than `swift run`, so screen capture permissions have a bundle identity. Keep its location stable. An ad-hoc designated requirement identifies a specific code version; changing the executable can invalidate permission even if System Settings still shows the same app as enabled.

## Screen Recording permission after a rebuild

1. Quit OziRegionMirror completely using its Quit menu command.
2. Open System Settings → Privacy & Security → Screen Recording (or Screen & System Audio Recording, depending on macOS).
3. Turn OziRegionMirror off and on, then reopen the packaged app.
4. If permission still fails, quit again, remove the existing OziRegionMirror entry from the list, and add the current `build/OziRegionMirror.app` using the plus button. Enable it and relaunch.

These steps affect only this app. Presets are stored separately in UserDefaults. Do not reset all applications' permissions or modify the TCC database.

To keep code identity stable across rebuilds, use an installed Apple Development or Developer ID certificate consistently:

```sh
OZI_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" bash scripts/build-app.sh
```

Replace the example with your actual signing identity. The script creates no certificates and does not change Keychain or macOS permissions. Switching from ad-hoc signing to certificate signing requires a one-time permission renewal; later builds must keep the same signing identity and bundle ID. Avoid an identifier-only custom requirement that would let unrelated code impersonate the app.

See Apple's [code signing requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements) for code identity and permission matching.

## Use

1. Open the app and click **Select Region**. Drag a rectangle on one display; press Escape to cancel.
2. Allow Screen Recording access if prompted. Relaunch the app after granting access if capture fails. There is a settings link in Controls.
3. Keep **OziRegionMirror — Share this window** visible and unminimized.
4. In Teams, share that window. Arrange your apps inside the green outline.
5. Use **Hide View** to replace the output with a solid screen, **Resume View** to restore it, and **Stop** to clear it.
6. Save a named region in Controls to reuse it. Select another region or preset to change the source while keeping the same mirror window.

The green dashed outline has **eight resize handles** and a **Drag to move** label. Move/resize the region live on its current display without restarting capture or reselecting the window in Teams. Press Escape during a drag to restore its initial position/size. Ordinary clicks inside the region reach your apps. Use **Hide Region Handles / Edit Region** in Controls or **Show / Hide Region Handles** in the menu (Command-E) to hide/show the editing controls. Movement stays inside the current display’s usable desktop area, excluding the menu bar and Dock with a 7-point margin for handles. Dimensions cannot shrink below 32 logical points. Older saved regions are fitted into these bounds when restored.

Capture starts at **100%** mirror size: one captured pixel per mirror backing pixel, accounting for Retina scaling. Use **100% / 75% / 50%** in Controls or the **Mirror Size** menu to restore or reduce the size. Controls shows capture and mirror pixel dimensions and the actual scale after manual resizing. Smaller percentages reduce detail in the window shared with Teams.

If a requested size exceeds the current display's usable area, the window fits proportionally and reports the actual reduced percentage. Select a smaller region to achieve 100%. Capture itself remains capped at 3840 pixels on its longest side; 100% refers to that captured output, not a guarantee of lossless Teams transmission.

The menu bar icon reopens Controls and exposes capture commands. Command-N selects a region, Command-B toggles hiding, and Command-period stops while this app is active. These are app shortcuts, not global shortcuts.

## Current status

The implementation includes selection, capture, self-process exclusion, live region move/resize handles, bounded frame delivery, output concealment, percentage mirror sizing, presets, and local app packaging with an original application icon. The user confirmed the Dock icon appears; it is assigned once at launch without timers or repeated refresh. Twenty-two unit tests pass. The user confirmed basic operation and Teams transmission, but reported poor quality before sizing improvements. New editing behavior, corrected Teams quality, and permission recovery still require the manual acceptance checks in `docs/TESTING.md`.

An area is visible to the audience if it appears inside the selected rectangle, including notifications and other apps. Use Hide View before sensitive activity. This app does not initiate or stop Teams sharing; Teams owns the call and its sharing state.

Dragging the outline updates the active stream. Selecting another region/preset through Controls currently restarts capture briefly while retaining the mirror window. Cross-display dragging, annotations, whiteboard, zoom loupe, global shortcuts, compact toolbar, and full feature parity are planned in the backlog.

## Development docs

- [Session context](docs/CONTEXT.md): short handoff; read first.
- [Product scope](docs/PRODUCT.md): feature assessment and boundaries.
- [Architecture](docs/ARCHITECTURE.md): components and coordinate rules.
- [Tasks](docs/TASKS.md): prioritized work with acceptance criteria.
- [Decisions](docs/DECISIONS.md): why the architecture exists.
- [Testing](docs/TESTING.md): automated and manual validation.
- [AI workflow](docs/AI_WORKFLOW.md): economical model selection and reusable prompts.
