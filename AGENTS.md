# Repository instructions

- Communicate in the language used by the user: Ukrainian or English only. If voice transcription produces another language, reply in Ukrainian.
- All source code, code comments, UI copy, documentation, task descriptions, and commit messages must be English.
- Build a local native macOS region-to-window mirror. No backend, analytics, network access, paid SDKs, or runtime AI.
- Start each development session by reading `docs/CONTEXT.md`, then the selected task in `docs/TASKS.md`. Read other documents only when relevant.
- Complete one bounded task at a time. Keep existing architecture unless an actual requirement or reproducible defect requires a change.
- Preserve the user's changes. Do not publish, push, or install outside this repository unless requested.
- Use `bash scripts/check.sh` for automated checks and `bash scripts/build-app.sh` for an ad-hoc signed local app. Manual capture checks are in `docs/TESTING.md`.
- Keep capture coordinates display-local, top-left, in logical points. Convert only at explicit AppKit/capture boundaries.
- Always exclude the entire current process from source capture. Never rely on `NSWindow.sharingType` as the recursion guard.
- Hide or clear output immediately on stop/error/display changes. Do not retain screenshots or video on disk.
- Do not mark manual Teams, permission, or multi-monitor checks as passed unless actually observed.
- After work, update task status and the short `docs/CONTEXT.md` handoff with results, remaining risks, and the next task. Update architecture/decisions only if they changed. Avoid copying chat transcripts.
- Do not spawn subagents unless the user explicitly requests them; economical serial development is the default.
