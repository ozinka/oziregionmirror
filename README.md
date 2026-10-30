# OziRegionMirror

A local macOS app that mirrors a selected rectangular screen region into an ordinary window for sharing in Microsoft Teams and other meeting apps.

Independent implementation inspired by the public workflow at [RegionMirror](https://regionmirror.com/). No proprietary code or assets are used. The existing MIT license is retained.

## Download and launch

Download the Apple silicon ZIP from [GitHub Releases](https://github.com/ozinka/oziregionmirror/releases), unzip it, and move **OziRegionMirror.app** to **Applications**. Releases are previews while manual Teams and multi-monitor checks remain pending. Intel release binaries are not currently provided.

The app is ad-hoc signed and not notarized. If macOS blocks a download you trust, remove the quarantine extended attribute from this app only, then launch it:

```sh
xattr -dr com.apple.quarantine /Applications/OziRegionMirror.app
open /Applications/OziRegionMirror.app
```

Adjust the path if you placed the app elsewhere. This does not grant Screen Recording access; enable that separately in System Settings as described below. No system-wide Gatekeeper change is required.

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
3. The output starts parked outside the desktop at 100% size. Use **Show Mirror** in Controls or the menu bar if Teams does not list **OziRegionMirror — Share this window**.
4. In Teams, share that window, then use **Park Mirror** to clear your desktop. Arrange your apps inside the green outline. Closing the active mirror parks it too. Verify that the receiver keeps seeing updates; use Show Mirror if sharing stops.
5. Use **Hide View** to replace the output with a solid screen, **Resume View** to restore it, and **Stop** to clear it.
6. Save a named region in Controls to reuse it. Select another region or preset to change the source while keeping the same mirror window.

The green dashed outline has **eight resize handles** and a **Drag to move** label. Move/resize the region live on its current display without restarting capture or reselecting the window in Teams. Press Escape during a drag to restore its initial position/size. Ordinary clicks inside the region reach your apps. Use **Hide Region Handles / Edit Region** in Controls or **Show / Hide Region Handles** in the menu (Command-E) to hide/show the editing controls. Movement stays inside the current display’s usable desktop area, excluding the menu bar and Dock with a 7-point margin for handles. Dimensions cannot shrink below 32 logical points. Older saved regions are fitted into these bounds when restored.

Click the green **Click: Controls • Drag: move** label to bring Controls forward, including after closing or minimizing it. Dragging the label still moves the region; Escape still cancels. The dashed border and crop interior remain click-through. When handles are hidden, reopen Controls from the menu bar. To reduce sharing-picker clutter, close Controls before selecting the mirror in Teams and reopen it with the label afterward. There is no supported per-window flag that guarantees removal from Teams' picker; Controls is not advertised as capture-protected.

After selecting a region, use **Standard Size** for 1280×720, 1920×1080, 2560×1440, 3840×2160 or 1024×768 capture pixels. Sizes account for the source display's Retina scale and apply around the current region; entries that do not fit are disabled. Save the resulting region under any name. Saved entries show logical points and capture pixels for the currently connected source display; an unavailable display is marked explicitly.

Use **Aspect ratio** to resize freely, lock the current proportions, or choose 16:9, 4:3 or 1:1. The lock applies to the green capture area and keeps all resize handles within usable screen bounds. Choosing another region/preset or a standard size resets it to Free. Ratio selection is session-only. Saved-region names and right-aligned dimensions/position share a row; position uses display-local top-left points. Controls grows to fit about five saved regions, with a maximum content height of 760 points (limited by the display). Scrolling is a fallback for longer lists or smaller screens.

Capture starts at **100%** mirror size: one captured pixel per mirror backing pixel, accounting for Retina scaling. Use **100% / 75% / 50%** in Controls or the **Mirror Size** menu to restore or reduce the size. Controls shows capture and mirror pixel dimensions and the actual scale after manual resizing. Smaller percentages reduce detail in the window shared with Teams.

Output is no longer reduced automatically to fit the desktop. Oversized visible mirrors keep their title bar accessible; Park Mirror moves the same opaque, unminimized window outside all connected displays. Show Mirror restores it without intentionally reducing the selected pixel scale. Parking does not hide content from the audience: use Hide View for that. Capture itself remains capped at 3840 pixels on its longest side; 100% refers to that captured output, not a guarantee of lossless Teams transmission. Off-screen picker discovery, continued Teams updates and mixed-DPI behavior still require manual acceptance.

The menu bar icon reopens Controls and exposes capture commands. Use **Hide Dock Icon / Show Dock Icon** there to toggle Dock visibility; the choice is remembered after relaunch. Controls and the menu bar remain available while the Dock icon is hidden. Command-N selects a region, Command-B toggles hiding, and Command-period stops while this app is active. These are app shortcuts, not global shortcuts.

## Drawing, frozen frames and images

After selecting a source region, a compact icon toolbar appears below the green frame. Tall regions use a vertical toolbar beside the frame; placement adapts to available desktop space. If no outside space remains, the toolbar stays inside the visible desktop. Hover over an icon for its name. Drawing tools are separate from Controls, which remains for setup and saved regions.

- Click **Pen**, **Arrow**, **Rectangle**, **Ellipse**, **Text** or **Move Image** to start drawing directly. The palette icon opens color and line width options. Text opens a small entry dialog when you click. The cursor icon (**Finish Drawing / Use Desktop**) restores ordinary desktop input. Escape cancels a gesture; Escape with no gesture exits drawing. Crop handles are disabled while drawing or presenting a frozen frame/board.
- **Freeze Frame** holds the latest complete source frame in memory for markup. **Resume Live** returns to current capture with its annotations. **Whiteboard** switches the same shared output to a solid white board; **Return to Source** restores the previous live/frozen mode. Source and board annotations have separate histories.
- **Undo**, **Redo** and **Clear Canvas** (in the ellipsis menu) operate on the current canvas. Command-Z / Command-Shift-Z also work while the drawing surface has focus. Clear can be undone.
- The image icon opens **Open Image…**, **Paste Image**, **Delete Selected Image** and **Save Board PNG…**. Opening or pasting inserts a static image and selects **Move Image**. Drag its body to move it, or its blue bottom-right corner to resize with preserved proportions. Click an image to select it; **Delete Selected Image** or Delete removes the selected image. Command-V pastes a bitmap when the drawing surface has focus.
- **Save Board PNG…** exports only the whiteboard to a destination you choose, at capture pixel dimensions. Live/frozen captured frames are never exported or automatically saved. Imports accept up to 32 MB, decode to at most 2048 pixels on the longest side and have a 64 MB combined decoded-image budget. History is limited to 50 changes and 256 items per canvas.

The ellipsis menu also provides **Hide View / Resume View**, **Controls…** and **Stop Sharing**. Hide View covers all outgoing layers, including annotations, frozen frames and the board, and exits drawing. Stop, errors, display changes and new captures discard the presentation session, frozen frame and imported images from memory. The editor is an input/markup surface, not a second mirror: it does not restore the rejected transparent output-overlay experiment. The entire process remains excluded from source capture. Actual drawing/capture/Teams acceptance and mixed-DPI checks remain pending.

## Current status

The implementation includes selection, capture, self-process exclusion, live region move/resize handles, bounded frame delivery, output concealment, percentage mirror sizing, off-screen parking, presets, and local app packaging with an original application icon. The user confirmed the Dock icon appears; it is assigned once at launch without timers or repeated refresh. Forty-three unit tests pass. The user confirmed basic operation and Teams transmission before off-screen parking was added, but reported poor quality before sizing improvements. Parking, new editing behavior, corrected Teams quality, and permission recovery still require the manual acceptance checks in `docs/TESTING.md`.

An area is visible to the audience if it appears inside the selected rectangle, including notifications and other apps. Use Hide View before sensitive activity. This app does not initiate or stop Teams sharing; Teams owns the call and its sharing state.

Dragging the outline updates the active stream. Selecting another region/preset through Controls currently restarts capture briefly while retaining the mirror window. Cross-display dragging, zoom loupe, global shortcuts and full feature parity are planned in the backlog. Drawing, freeze, whiteboard and image tools are implemented and awaiting manual acceptance.

## Development docs

- [Session context](docs/CONTEXT.md): short handoff; read first.
- [Product scope](docs/PRODUCT.md): feature assessment and boundaries.
- [Architecture](docs/ARCHITECTURE.md): components and coordinate rules.
- [Tasks](docs/TASKS.md): prioritized work with acceptance criteria.
- [Decisions](docs/DECISIONS.md): why the architecture exists.
- [Testing](docs/TESTING.md): automated and manual validation.
- [AI workflow](docs/AI_WORKFLOW.md): economical model selection and reusable prompts.

## Automated builds and releases

[GitHub Actions](https://github.com/ozinka/oziregionmirror/actions/workflows/build.yml) runs unit tests, builds and verifies an ad-hoc signed Apple silicon app, and uploads a ZIP with SHA-256 checksums on main pushes, pull requests and manual runs. Native desktop and Teams checks remain manual.

To publish a preview, update the bundle version and `docs/RELEASE_NOTES.md`, commit, and push a matching `v<version>` tag. The workflow checks the version and publishes a GitHub prerelease with the ZIP and checksums. Builds use the standard `macos-15` Apple silicon runner documented in [GitHub runner images](https://github.com/actions/runner-images).
