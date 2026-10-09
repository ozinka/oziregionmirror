# Economical AI development

## Model routing

Recommendations checked against [official model guidance](https://learn.chatgpt.com/docs/models) and [pricing](https://learn.chatgpt.com/docs/pricing) on 2026-10-08. Availability depends on account/client rollout; use the models actually shown in the picker. These are developer assistance models, not runtime dependencies.

| Work | Model/effort | Reason |
| --- | --- | --- |
| One clear UI/model/docs/test task | GPT-6 Luna, High, Standard speed | Efficient focused coding with explicit acceptance |
| Capture, display changes, concurrency, API integration, release review | GPT-6.1 Sol, default or Medium, Standard speed | Cross-component reasoning and platform diagnosis |
| Unresolved complex platform bug after two bounded attempts | GPT-6 Astra, Light initially | Escalate with evidence and a minimal reproduction |

Fallbacks when those are unavailable: GPT-5.6 Luna for routine work; available Sol for capture work. Do not switch model blindly mid-debug without saving evidence.

The published Standard credit table lists 2.5 input / 12.5 output credits per million tokens for GPT-6 Luna, 50 / 250 for GPT-6.1 Sol, and 250 / 1250 for GPT-6 Astra. Those uncached unit rates imply 20× lower Luna rates than Sol and 100× lower than Astra. They are **not** guarantees of session savings or ratios for included account usage limits: token counts, retries, caching, effort, and speed vary. API dollar pricing is a separate system.

## When to switch

Keep Sol/Astra for initial architecture and the first capture/Teams acceptance task T006. Switch to Luna for bounded T008, preset CRUD portions of T009, UI refinements, and documentation. Return to Sol for T007/T010/capture races and annotation compositing. Astra is an escalation, not a default for every task.

## Small context workflow

1. Read `AGENTS.md` (normally automatically supplied), `CONTEXT.md`, and one task.
2. Inspect only related source files. Avoid repository-wide rereads and repeating product research.
3. State an implementation plan briefly, implement the task, and run relevant checks once.
4. If blocked, preserve reproduction, errors, attempted fixes and hypothesis in context; escalate after two unsuccessful approaches.
5. Update task/context and changed contracts, then hand back results. Keep context under roughly 800 words.

Documentation is useful project memory, but not magic prompt caching. A new bounded chat avoids dragging a long setup transcript through routine tasks. A model switch in this chat retains its existing history; start a fresh project chat when a cleaner context is helpful. No automatic model switching or agent spawning is configured.

## Reusable task prompt

```text
Read AGENTS.md and docs/CONTEXT.md. Implement only task T008 from docs/TASKS.md.
Read the referenced docs and source files as needed. Keep all code and documentation English.
Use the existing architecture, run the relevant checks, and do not claim manual tests passed.
Update docs/TASKS.md and docs/CONTEXT.md with the outcome and next task.
Escalate with a minimal reproduction after two failed approaches instead of broad rewrites.
Reply in Ukrainian.
```

Replace T008 with the chosen task. For manual validation, provide the user's observations and hardware/call conditions explicitly. Do not ask an inexpensive model to implement the entire backlog in one prompt.
