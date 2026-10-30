Native macOS region sharing with a stable mirror window, live crop editing, saved regions, pixel-aware sizing and off-screen parking.

Includes a compact presentation toolbar, drawing and annotations, frozen frames, whiteboard, local image import and explicit whiteboard PNG export. Captured frames remain in memory; the app has no backend, analytics or runtime network access.

## Install

Download `OziRegionMirror-macos-arm64.zip`, unzip it and move the app to Applications. This build is for Apple silicon and requires macOS 13 or later. It is ad-hoc signed and is not notarized.

If macOS blocks the trusted download, remove only this app's quarantine attribute:

```sh
xattr -dr com.apple.quarantine /Applications/OziRegionMirror.app
open /Applications/OziRegionMirror.app
```

Grant Screen Recording permission in System Settings. Permission may need renewal after replacing an ad-hoc signed build. See README for recovery instructions.

## Preview limitations

Teams sharing worked in earlier builds. Current parking, toolbar, drawing, permission recovery and mixed-DPI behavior still require manual acceptance. Automated checks do not establish Teams receiver quality or real mouse routing. Use Show Mirror if the meeting app cannot discover or continue sharing the parked window. Hide View conceals outgoing content; parking alone does not.
