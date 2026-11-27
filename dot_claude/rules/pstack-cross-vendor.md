# pstack: non-Claude role values

This overrides the Models row "A `gemini-*` or other non-Claude slug: omit `model`" in pstack's Claude Code adapter (`docs/harness/claude-code.md`). `/pstack:setup-pstack` rewrites `pstack-models.md` whole, so this mapping lives in its own file.

A pstack role value `<model> <effort>` whose model is not a Claude model runs as a T3 `delegate_task` child, not an `Agent` subagent:

- `gpt-*`: `target: {providerInstanceId: "codex", model: "<model>", options: {reasoningEffort: "<effort>"}}`.
- `gemini-*`: `target: {providerInstanceId: "antigravity", model: "<model>", options: {thought_level: "<effort>"}}`.
- A role that writes code or files (arena runners, swarm workers, implementers): `isolation: "worktree"`. A judge or reviewer: `isolation: "shared"`, and the brief says "do not edit files"; check `git status` afterward.
- The brief carries everything the child needs, since it gets no parent history: the task, the shared grounding paths, the output path, and the result shape.
- Start every child of one fan-out in one message, `mode: "async"`, then follow each task's `next` until it finishes. Claude entries in the same list still go through `Agent`.
- Vendor for the cross-judge check: `gpt-*` is OpenAI, `gemini-*` is Google, so either can judge when the parent is Claude.
- Detection: these slugs are valid when `orchestrator_capabilities` lists the model under a provider with `canRunChildTask: true`. `/pstack:setup-pstack` counts them as detected on that basis.
- Quota: both subscriptions are the lower tiers (Codex Plus, Gemini AI Pro). Keep these entries at `high`, never `xhigh` or above. When a child fails on a usage limit or the provider is disabled, drop that entry, go on with N-1, and say which entry dropped and why.
- Outside T3 (no `delegate_task` tool), fall back to the adapter: omit `model` and say so.
