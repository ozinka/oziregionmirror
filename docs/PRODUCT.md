# Product scope

## Goal

Let a presenter on a large or ultrawide Mac display share a readable region containing several apps, using Teams' existing window sharing. The remaining desktop stays outside the source crop. Everything runs locally.

## Reference assessment

Observed from [RegionMirror's public product page](https://regionmirror.com/) on 2026-10-08; this is a description of published capabilities, not a test of its binary.

The reference provides a region selection and mirror window, a presenter preview, annotations (arrows/text), zoom loupe, privacy blur, a whiteboard with PNG export, and named display-specific presets with customizable global shortcuts. It advertises support for several meeting apps. We reuse the general interaction concept with original implementation and identity.

## Implementation stages

| Stage | Features | Difficulty | Exit condition |
| --- | --- | --- | --- |
| Foundation | Package, local app bundle, docs, geometry tests | Low | Reproducible build and compact handoff |
| Core prototype | Drag selection, display crop, ordinary output window, cursor, self exclusion, outline, concealment, saved regions | High | Code builds; manual acceptance still required |
| Daily-use release | Permission recovery, live move/resize, seamless source changes, robust display identity, global shortcuts, fixed-size presets, persistent settings | Medium–high | Teams/Retina/display checks pass; 30-minute session stable |
| Presentation tools | Arrows, text, pen, undo/clear, zoom loupe, whiteboard, PNG export, presenter preview | Medium–high | Tools compose only into output; state is preserved across mode changes |

Planning estimate, not a delivery promise: foundation/core hardening 2–4 focused developer days; daily-use features another 2–4; presentation tools another 4–8. OS capture and actual Teams behavior dominate uncertainty. AI model speed does not eliminate manual validation.

## Core acceptance

- Select a rectangle of at least 32×32 logical points on any attached display.
- Show only that crop, with correct orientation, readable text, and pointer.
- The app's own output, controls, selection overlay, and outline never recurse into capture.
- Sharing uses an ordinary titled window with a stable identity.
- Keep output aspect ratio; black margins may appear when the window is resized.
- Hide View immediately removes the captured image from local output; Stop/error/display changes clear it.
- Persist up to ten named regions without saving captured pixels.
- Reject presets whose display or geometry is no longer available.
- Target 30 fps; limit output's longest side to 3840 physical pixels and bounded frame queues.

## Explicit boundaries

- One source region on one display per session; no rectangle spanning multiple displays.
- Video only. Teams manages microphone/system audio independently.
- No virtual monitor, camera driver, automatic Teams UI control, recording, or remote service.
- No App Store distribution, notarization, account system, or monetization in the local project.
- Mirror-window sharing when minimized/occluded and meeting-app borders must be measured rather than assumed.
- Capture permissions are controlled by macOS. The app cannot bypass them.

## Open questions to resolve through testing

1. Does this Teams version continue updating an occluded window? Until verified, keep it visible.
2. Is 3840-pixel output useful for the user's monitor, or would 1920/2560 improve performance without losing call readability?
3. Should routine changes preserve output dimensions or adapt to crop aspect ratio? Keep the current stable window and assess during a call.
4. Do display IDs remain stable across this user's dock/reconnection? Start conservative and reject mismatches; later migrate presets to persistent display UUIDs.

## Reference UI observations (2026-10-08)

User-provided screenshots show a dashed capture outline with eight resize handles and a drag affordance, a compact floating tool strip, and menu-bar access to presets, Stop, presenter view, and outline/toolbar visibility. The user reports no separate visible mirror. Use these observations to guide live editing and an unobtrusive presenting workflow, not as evidence of how the reference captures or hides output. Preserve a shareable output window and validate any background/off-screen strategy with Teams before adopting it. Reuse general interaction patterns with original visuals and code.
