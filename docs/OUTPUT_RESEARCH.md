# Output architecture investigation

Date: 2026-10-09. Scope: T017 research, not an implementation decision.

Follow-up 2026-10-22: native decompilation and instruction checks now establish the RegionMirror parking implementation, its separate Presenter View and hidden-independent frame assignment. See `REGIONMIRROR_REVERSE_ENGINEERING.md`. The original string-only evidence limits below describe the earlier investigation; runtime and Teams acceptance remain pending.

## Requirements clarified by the user

The Controls panel is useful and is not the current problem. A large output mirror consumes the same desktop area as the source. Reducing output dimensions loses detail before Teams transmits it. Investigate approaches without a mirror before selecting a better mirror workflow. An internal mirror is acceptable if it remains the best practical solution.

Preserve source-to-output pixel dimensions, avoid occupying the working desktop, retain ordinary Teams window sharing where possible, and keep the app local without a backend, external runtime dependencies, or private OS APIs. A smaller optional preview must not determine output resolution. The current 3840-pixel capture cap and screen-fit sizing mean even a requested 100% is not an unconditional promise of source-resolution output.

## What was actually checked

- Read current capture/rendering code and project contracts.
- Read official Zoom, Webex, Apple, Chrome and Microsoft documentation.
- Inspected Sightline source at commit `2da6cd6e4e0a2016d3e4e8facb0687ef8c317032` and DeskPad source at `c3349f0e237e000cb4826fb3ea1cdd1c44949461`. Source-only checkouts are in `/tmp/ozi-research-sightline` and `/tmp/ozi-research-deskpad`; neither app was built, installed or run.
- Read VirtualScreen's documented workflow.
- Inspected installed RegionMirror 1.5.1 (38) framework dependencies and binary strings. No modification or code reuse.
- Attempted native RegionMirror observation: initial UI requests timed out; after the user confirmed an active region, the observation tool failed with ScreenCaptureKit error -3811 (audio/video capture failure). This is an observation-tool failure, not evidence that RegionMirror failed. A narrowly filtered recent unified-log query returned no window-placement messages.
- No live window position, frame cadence, picker discovery, Teams receiver quality, performance, sleep, or multi-monitor test was completed. No screen pixels were saved by research scripts. Application sources were not changed.

## Alternatives without an output mirror

| Approach | Evidence and applicability | Assessment |
| --- | --- | --- |
| Conference app directly crops its capture | Zoom and Webex document movable/resizable portion-of-screen sharing. They own the outgoing call stream; the architecture can pass cropped frames to the encoder without publishing a new OS window. Exact proprietary internals were not inspected. | Good when using that conference app; does not supply a new Teams window. Our existing ScreenCaptureKit crop already solves the capture half. |
| Custom call client sends raw screen-share frames | Microsoft documents custom screen-share MediaStreams in Azure Communication Services, plus Teams interoperability. This API belongs to the Calling SDK, not a local raw-frame input on the installed Teams client. | Technically distinct, but requires a networked calling product/service integration and platform-specific capability checks. Outside current local-app scope. |
| Virtual camera | Apple's Core Media I/O camera extensions expose generated frames as a camera device. | Removes the output window, but changes the selected source/channel from window sharing to camera and requires extension distribution/activation. Text fidelity must be measured, not assumed equivalent. |
| Virtual display | DeskPad actually creates `CGVirtualDisplay` via its `CGVirtualDisplayPrivate.h` declarations. Its app previews a separate desktop. | Can decouple shared display resolution from preview size if the display is shared directly. It changes the workflow from cropping the current desktop and requires private API in this examined implementation. If its preview window is shared instead, the window-resolution issue returns. |
| Browser Region Capture | Chrome documents cropping a captured tab to a DOM element. | Not arbitrary macOS desktop-region capture, and not a new source for the native Teams window picker. |
| Teams meeting-stage app | Microsoft's Share in Meeting opens web app/document content on the meeting stage. | Not a documented route for injecting local cropped desktop frames into ordinary window sharing; would require a different content-delivery design. |

No documented public raw-frame provider for the installed Teams application's normal window picker was found. This is a scoped research result, not proof that no other implementation can ever exist. A frame buffer or IOSurface alone is not a shareable NSWindow.

## Evidence from similar implementations

**RegionMirror:** links ScreenCaptureKit; contains `MirrorWindowController`, `OffScreenCapableWindow`, `constrainFrameRect:toScreen:`, and diagnostics stating the mirror is parked fully off-screen, including a fallback placement. This strongly supports an off-screen-window mechanism. Strings do not establish coordinates, active code paths, timing, recovery logic, or receiver quality. Its vendor describes a normal shareable output window.

**Sightline:** `hideCaptureWindow()` in `CaptureManager.swift` calls `orderOut(nil)`. Keeping its source stream running does not prove another app keeps capturing the hidden output. Its README warns that the window must be visible to appear in a picker. It also documents an AeroSpace workspace rule and warns Teams may switch to that workspace when sharing begins. AeroSpace workspaces must not be treated as evidence for native macOS Spaces behavior.

**VirtualScreen:** documents selected-region capture to a standalone output window; it is a reference for the same basic architecture, not a window-free alternative.

## Mirror variants worth comparing

| Variant | Advantage | Unresolved issue |
| --- | --- | --- |
| Normal full-resolution output, covered by other windows | Simplest capture baseline; no reduced output dimensions | Still occupies desktop space and can reappear/focus |
| Full-resolution output parked outside the union of displays | No visible space occupied; supported by RegionMirror static evidence | Picker discovery, focus bringing it back, display rearrangement, backing scale, render cadence, sleep/recovery |
| Output on another native Space | No need to invent off-screen coordinates | User-managed Space, sharing focus switches, source-display/Space behavior and automation limits; not runtime validated |
| Borderless click-through mirror exactly over the source | No additional desktop footprint; retains a real output window | Experimental hypothesis: user sees delayed pixels over live controls; source applications may throttle when covered; menus/cursor/focus and concealment need careful testing. Entire process exclusion remains mandatory. |
| `orderOut`, minimization, or zero alpha | Apparently invisible | Different states with no interchangeable guarantees. Apple documents paused capture for minimized windows. Do not select as the default without evidence for both discovery and ongoing capture. |

Apple's single-window ScreenCaptureKit session explicitly supports full capture when occluded/off-screen and pauses output on minimization. This is an API capability, not an end-to-end Teams guarantee or assurance that an occluded renderer keeps producing frames.

## Proposed decision gate

Do not redesign Controls or select an output strategy yet. First compare normal covered, off-screen, and native-Space output using the same pixel dimensions and dynamic test content. Test discovery both before sharing and after placement changes, then continuous receiver updates, fine text, resize, hide/stop, focus, sleep, and display changes. Use an optional in-place-overlay experiment only if the first candidates are unacceptable.

Record capture pixels, output backing pixels, window identity, frame cadence and received detail. A source stream that remains active is insufficient evidence. Do not shrink output to fit the desktop as a workaround during these comparisons. Keep a reversible visible output until acceptance. RegionMirror live observation remains blocked by the UI observation tool; user confirmed its region was active.

## Sources

- [Zoom portion sharing](https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0060596)
- [Webex portion sharing](https://help.webex.com/en-us/article/ngexff8)
- [Apple window-capture semantics, WWDC22](https://developer.apple.com/videos/play/wwdc2022/10155/)
- [Apple camera extensions](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)
- [ACS raw media](https://learn.microsoft.com/azure/communication-services/quickstarts/voice-video-calling/get-started-raw-media-access)
- [ACS Teams capabilities](https://learn.microsoft.com/en-us/azure/communication-services/concepts/interop/teams-user/meeting-capabilities)
- [Teams Share in Meeting](https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/build-and-test/share-in-meeting)
- [Chrome Region Capture](https://developer.chrome.com/docs/web-platform/region-capture)
- [RegionMirror workflow](https://regionmirror.com/teams-share-part-of-screen/)
- [Sightline capture controller](https://github.com/mhersson/sightline/blob/2da6cd6e4e0a2016d3e4e8facb0687ef8c317032/Sources/Sightline/CaptureManager.swift)
- [Sightline README](https://github.com/mhersson/sightline/blob/2da6cd6e4e0a2016d3e4e8facb0687ef8c317032/README.md)
- [DeskPad display creation](https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/Frontend/Screen/ScreenViewController.swift)
- [DeskPad private declarations](https://github.com/Stengo/DeskPad/blob/c3349f0e237e000cb4826fb3ea1cdd1c44949461/DeskPad/CGVirtualDisplayPrivate.h)
- [VirtualScreen](https://github.com/alexolivier/virtual-screen)
