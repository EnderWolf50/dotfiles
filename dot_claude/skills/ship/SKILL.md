---
name: ship
description: Take finished work on a GitLab repo to merged - commit, push, open the MR, arm auto-merge, watch the pipeline. Use when the user says ship, "push & MR", or asks for auto-merge or pipeline monitoring.
---

Each step ends on its own done-condition; stop and report when one cannot be met.

1. **Where.** `git rev-parse --show-toplevel` must be a linked worktree (the repo's sibling `.wt/` directory, per its `AGENTS.md`) on a feature branch, never the main checkout or `master`. Done: branch name printed and it is not `master`.
2. **Commit** with explicit paths (never `-a`), message per the repo's `AGENTS.md` git workflow. Done: `git status --short` lists nothing you meant to ship.
3. **Push**: `git push -u origin HEAD`. Done: the remote branch exists.
4. **MR**: open it per the repo's `docs/agents/merge-request.md` (template, labels, evidence). Done: the MR iid is known.
5. **Auto-merge**, only when the user asked for it. `glab mr merge --auto-merge` merges *immediately* while the pipeline is still `pending`; arm it through the API, which accepts a pending pipeline:
   ```sh
   glab api --method PUT "projects/:id/merge_requests/<iid>/merge" \
     -f merge_when_pipeline_succeeds=true -f should_remove_source_branch=true
   ```
   A pipeline `skipped` by path rules (a `scripts/`- or docs-only MR) leaves nothing to wait on, and the API answers `405 Method Not Allowed` — read `head_pipeline.status` from `glab api "projects/:id/merge_requests/<iid>"` before arming. On `skipped`, auto-merge means an immediate merge: ask the user, then merge with the same call minus `merge_when_pipeline_succeeds`.
   A later push or rebase clears it; re-arm after every push. Done: the response shows `merge_when_pipeline_succeeds: true`, or `state: merged` after the user chose to merge a skipped pipeline.
6. **Watch**: run `bash ~/.claude/skills/ship/watch-mr.sh <iid>` from the repo under Monitor. It prints one line per state change and exits on `merged`, `closed`, or a failed/canceled pipeline. On a failure, read the red job (`glab ci view`, `glab ci trace <job-id>`) and report its cause. Done: merged, or the failing job's cause reported.
7. **Clean up**, only when the user asked: `git worktree remove <path>` and delete the local branch. A directory locked by a running process (tgrep serve, a dev server) is reported, not force-deleted.
