# Decisions

## ADR-001 — Native macOS stack (2026-10-08)

Use Swift, AppKit/SwiftUI, and ScreenCaptureKit instead of a web shell. Capture and window behavior are the core problem; a cross-platform runtime adds dependencies without helping local macOS requirements. Use Swift Package Manager so Xcode-project generation is unnecessary.

## ADR-002 — Mirror an ordinary window

Teams selects our output window. No virtual display or driver. Keep one output NSWindow alive for the session and for crop changes. Actual meeting-app interoperability is a manual release gate.

## ADR-003 — Explicit crop and process exclusion

Capture a display-local region and exclude our process, including output and overlays. This protects against recursive imagery when the mirror enters the source region. Reject unavailable display presets instead of choosing another display silently.

## ADR-004 — Opaque hide first

Implement a solid hidden output before blur. Blur quality is difficult to validate for sensitive text and adds processing cost. Aesthetic blur can be added later as a separate mode; keep opaque concealment available.

## ADR-005 — Scope in stages

Build the capture workflow first. Presentation extras do not prove Teams interoperability. Treat publicly advertised RegionMirror features as a roadmap, not a requirement to clone assets or reproduce proprietary internals.

## ADR-006 — Compact persisted AI context

`CONTEXT.md` is the current handoff; `TASKS.md` is task status; architecture and decisions hold stable facts. Routine sessions read only context and one task. Update documents when facts change rather than rewrite them every turn. No parallel agents by default.

## ADR-007 — Local ad-hoc bundle

Build under `build/` with identifier `local.ozi.regionmirror`. No developer-account requirement or external installation. Developer ID signing/notarization is optional future distribution work; test local TCC rebuild behavior first.

2026-10-08 update: the user observed stale enabled permission after a rebuild. Ad-hoc identity uses a code-version hash; the script now supports an existing signing certificate through OZI_SIGNING_IDENTITY and warns on ad-hoc builds. Consistent certificate signing is preferred for repeated local development when available. Do not use an identifier-only designated requirement as a shortcut: it removes signer verification and can allow impersonation.
